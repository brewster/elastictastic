require 'hashie'

module Elastictastic
  class Scope < BasicObject
    attr_reader :clazz, :index

    def initialize(index, clazz, search = Search.new, parent_collection = nil)
      @index, @clazz, @search, @parent_collection =
        index, clazz, search, parent_collection
    end

    def initialize_instance(instance)
      index = @index
      instance.instance_eval { @index = index }
    end

    def params
      @search.params
    end

    def each
      if ::Kernel.block_given?
        find_each { |result, hit| yield result }
      else
        ::Enumerator.new(self, :each)
      end
    end

    def find_each(batch_options = {}, &block)
      if block
        find_in_batches(batch_options) { |batch| batch.each(&block) }
      else
        ::Enumerator.new(self, :find_each, batch_options)
      end
    end

    def find_in_batches(batch_options = {}, &block)
      return ::Enumerator.new(self, :find_in_batches, batch_options) unless block
      if params.key?('size') || params.key?('from')
        yield search_all
      elsif params.key?('sort') || params.key('facets')
        search_in_batches(&block)
      else
        scan_in_batches(batch_options, &block)
      end
    end

    def count
      return @count if defined? @count
      populate_counts
      @count
    end

    def empty?
      count == 0
    end

    def any?(&block)
      block ? each.any?(&block) : !empty?
    end

    def first
      params = from(0).size(1).params
      hit = ::Elastictastic.client.search(
        @index,
        @clazz.type,
        params
      )['hits']['hits'].first
      materialize_hit(hit) if hit
    end

    def all
      scoped({})
    end

    def all_facets
      return @all_facets if defined? @all_facets
      populate_counts
      @all_facets ||= nil
    end

    def scoped(params, index = @index)
      ::Elastictastic::Scope.new(
        @index,
        @clazz,
        @search.merge(Search.new(params)),
        @parent_collection
      )
    end

    def destroy_all
      #FIXME support delete-by-query
      ::Elastictastic.client.delete(@index, @clazz.type)
    end

    def sync_mapping
      #XXX is this a weird place to have this?
      ::Elastictastic.client.put_mapping(index, type, @clazz.mapping)
    end

    def find(*ids)
      #TODO support combining this with other filters/query
      force_array = ::Array === ids.first
      ids = ids.flatten
      if ::Hash === ids.first
        find_many_in_many_indices(*ids)
      elsif ids.length == 1
        instance = find_one(ids.first)
        force_array ? [instance] : instance
      else
        find_many(ids)
      end
    end

    Search::KEYS.each do |search_key|
      module_eval <<-RUBY
        def #{search_key}(*values, &block)
          values << ScopeBuilder.build(&block) if block

          case values.length
          when 0 then ::Kernel.raise ::ArgumentError, "wrong number of arguments (0 for 1)"
          when 1 then value = values.first
          else value = values
          end

          scoped(#{search_key.inspect} => value)
        end
      RUBY
    end

    def method_missing(method, *args, &block)
      if ::Enumerable.method_defined?(method)
        each.__send__(method, *args, &block)
      elsif @clazz.respond_to?(method)
        @clazz.with_scope(self) do
          @clazz.__send__(method, *args, &block)
        end
      else
        super
      end
    end

    def inspect
      inspected = "#{@clazz.name}:#{@index.name}"
      inspected << @search.params.to_json unless @search.params.empty?
      inspected
    end

    protected

    def search(search_params = {})
      ::Elastictastic.client.search(
        @index,
        @clazz.type,
        params,
        search_params
      )
    end

    private

    def search_all
      response = search(:search_type => 'query_then_fetch')
      populate_counts(response)
      materialize_hits(response['hits']['hits'])
    end

    def search_in_batches(&block)
      from, size = 0, ::Elastictastic.config.default_batch_size
      scope_with_size = self.size(size)
      begin
        scope = scope_with_size.from(from)
        response = scope.search(:search_type => 'query_then_fetch')
        populate_counts(response)
        yield materialize_hits(response['hits']['hits'])
        from += size
        @count ||= scope.count
      end while from < @count
    end

    def scan_in_batches(batch_options, &block)
      batch_options = batch_options.symbolize_keys
      scroll_options = {
        :scroll => "#{batch_options[:ttl] || 60}s",
        :size => batch_options[:batch_size] || ::Elastictastic.config.default_batch_size
      }
      scan_response = ::Elastictastic.client.search(
        @index,
        @clazz.type,
        params,
        scroll_options.merge(:search_type => 'scan')
      )

      @count = scan_response['hits']['total']
      scroll_id = scan_response['_scroll_id']

      begin
        response = ::Elastictastic.client.scroll(scroll_id, scroll_options.slice(:scroll))
        scroll_id = response['_scroll_id']
        yield materialize_hits(response['hits']['hits'])
      end until response['hits']['hits'].empty?
    end

    def populate_counts(response = nil)
      response ||= search(:search_type => 'count')
      @count ||= response['hits']['total']
      if response['facets']
        @all_facets ||= ::Hashie::Mash.new(response['facets'])
      end
    end

    def find_one(id)
      data = ::Elastictastic.client.get(index, type, id, params_for_find_one)
      return nil if data['exists'] == false
      case data['status']
      when nil
        materialize_hit(data)
      when 404
        nil
      end
    end

    def find_many(ids)
      docspec = ids.map do |id|
        { '_id' => id }.merge!(params_for_find_many)
      end
      materialize_hits(
        ::Elastictastic.client.mget(docspec, index, type)['docs']
      ).map { |result, hit| result }
    end

    def find_many_in_many_indices(ids_by_index)
      docs = []
      ids_by_index.each_pair do |index, ids|
        ::Kernel.Array(ids).each do |id|
          docs << doc = {
            '_id' => id.to_s,
            '_type' => type,
            '_index' => index
          }
          doc['fields'] = ::Kernel.Array(@search['fields']) if @search['fields']
        end
      end
      materialize_hits(
        ::Elastictastic.client.mget(docs)['docs']
      ).map { |result, hit| result }
    end

    def params_for_find_one
      params_for_find.tap do |params|
        params['fields'] &&= params['fields'].join(',')
      end
    end

    def params_for_find_many
      params_for_find
    end

    def params_for_find
      {}.tap do |params|
        params['fields'] = ::Kernel.Array(@search['fields']) if @search['fields']
      end
    end

    def materialize_hits(hits)
      unless ::Kernel.block_given?
        return ::Enumerator.new(self, :materialize_hits, hits)
      end
      hits.each do |hit|
        unless hit['exists'] == false
          yield materialize_hit(hit), ::Hashie::Mash.new(hit)
        end
      end
    end

    def materialize_hit(hit)
      @clazz.new_from_elasticsearch_hit(hit).tap do |result|
        if @parent_collection
          parent_collection = @parent_collection
          result.instance_eval { @_parent_collection = parent_collection }
        end
      end
    end
  end
end
