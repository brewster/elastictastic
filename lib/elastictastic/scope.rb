require 'hashie'

module Elastictastic
  class Scope < BasicObject
    attr_reader :clazz, :index

    def initialize(index, clazz, search = Search.new)
      ::Kernel.raise ::ArgumentError, "Wrong type for #{search.inspect}" unless search.is_a? Search
      @index, @clazz, @search = index, clazz, search
    end

    def params
      @search.params
    end

    def find_each(batch_options = {}, &block)
      if block then enumerate_each(batch_options, &block)
      else ::Enumerator.new(self, :enumerate_each, batch_options)
      end
    end
    alias_method :each, :find_each

    def find_in_batches(batch_options = {}, &block)
      if params.key?('size') || params.key('from')
        if block then yield search_all
        else ::Enumerator.new([search_all], :each)
        end
      elsif params.key?('sort') || params.key('facets')
        if block then search_in_batches(&block)
        else ::Enumerator.new(self, :search_in_batches)
        end
      else
        if block then scan_in_batches(batch_options, &block)
        else ::Enumerator.new(self, :scan_in_batches, batch_options)
        end
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

    def any?
      !empty?
    end

    def first
      Scope.new(@index, @clazz, 
        #XXX when Search has smarter merging, this needn't be so roundabout
        Search.new(@search.params.merge('from' => 0, 'size' => 1))).to_a.first
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
      ::Elastictastic::Scope.new(@index, @clazz, @search.merge(params))
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
      #XXX support combining this with other filters/query
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
        find_each.__send__(method, *args, &block)
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
      @clazz.new_from_elasticsearch_hits(response['hits']['hits'])
    end

    def search_in_batches(&block)
      from, size = 0, 100
      scope_with_size = self.size(size)
      begin
        scope = scope_with_size.from(from)
        response = scope.search(:search_type => 'query_then_fetch')
        populate_counts(response)
        yield(@clazz.new_from_elasticsearch_hits(
          response['hits']['hits']))
        from += size
        @count ||= scope.count
      end while from < @count
    end

    def scan_in_batches(batch_options, &block)
      batch_options = batch_options.symbolize_keys
      scroll_options = {
        :scroll => "#{batch_options[:ttl] || 60}s",
        :size => batch_options[:batch_size] || 100
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
        docs = response['hits']['hits'].map do |hit|
          @clazz.new_from_elasticsearch_hit(hit)
        end
        yield(docs)
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
      params = {}
      if @search['fields']
        params[:fields] = ::Kernel.Array(@search['fields']).join(',')
      end
      data = ::Elastictastic.client.get(index, type, id, params)
      return nil if data['exists'] == false
      case data['status']
      when nil
        @clazz.new_from_elasticsearch_hit(data)
      when 404
        nil
      end
    end

    def find_many(ids)
      docspec = ids.map do |id|
        { '_id' => id }.tap do |identifier|
          identifier['fields'] = ::Kernel.Array(@search['fields']) if @search['fields']
        end
      end
      @clazz.new_from_elasticsearch_hits(
        ::Elastictastic.client.mget(docspec, index, type)['docs']
      )
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
      new_from_elasticsearch_hits(
        ::Elastictastic.client.mget(docs)['docs']
      )
    end

    def enumerate_each(batch_options = {}, &block)
      find_in_batches(batch_options) do |batch|
        batch.each(&block)
      end
    end
  end
end
