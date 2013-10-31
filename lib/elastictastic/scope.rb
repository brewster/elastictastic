require 'hashie'
require 'elastictastic/search'

module Elastictastic
  class Scope < BasicObject
    attr_reader :clazz, :index

    def initialize(index, clazz, search = Search.new, parent = nil, routing = nil)
      @index, @clazz, @search, @parent, @routing = index, clazz, search, parent, routing
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
        ::Enumerator.new do |yielder|
          self.each do |*vals|
            yielder.yield(*vals)
          end
        end
      end
    end

    #
    # Iterate over all documents matching this scope. The underlying mechanism
    # used differs depending on the construction of this scope:
    #
    # * If the scope has a size, documents will be retrieved in a single request
    # * If the scope has a sort but no size, documents will be retrieved in
    #   batches using a `query_then_fetch` search. *In this case, it is
    #   impossible to guarantee a consistent result set if concurrent
    #   modification is occurring.*
    # * If the scope has neither a sort nor a size, documents will be retrieved
    #   in batches using a cursor (search type `scan`). In this case, the result
    #   set is guaranteed to be consistent even if concurrent modification
    #   occurs.
    #
    # @param (see #find_in_batches)
    # @option (see #find_in_batches)
    # @yield [document, hit] Each result is yielded to the block
    # @yieldparam [Document] document A materialized Document instance
    # @yieldparam [Hashie::Mash] hit The raw hit from ElasticSearch, wrapped in
    #   a Hashie::Mash. Useful for extracting metadata, e.g. highlighting
    # @return [Enumerator] An enumerator, if no block is passed
    # @see http://www.elasticsearch.org/guide/reference/api/search/search-type.html
    #
    def find_each(batch_options = {}, &block)
      if block
        find_in_batches(batch_options) { |batch| batch.each(&block) }
      else
        ::Enumerator.new do |yielder|
          self.find_each(batch_options) do |*vals|
            yielder.yield(*vals)
          end
        end
      end
    end

    #
    # Yield batches of documents matching this scope. See #find_each for a
    # discussion of different strategies for retrieving documents from
    # ElasticSearch depending on the construction of this scope.
    #
    # @option batch_options [Fixnum] :batch_size (Elastictastic.config.default_batch_size)
    #   How many documents to retrieve from the server in each batch.
    # @option batch_options [Fixnum] :ttl (60) How long to keep the cursor
    #   alive, in the case where search is performed with a cursor.
    # @yield [batch] Once for each batch of hits
    # @yieldparam [Enumerator] batch An enumerator for this batch of hits.
    #   The enumerator will yield a materialized Document and a Hashie::Mash wrapping each raw hit.
    # @return [Enumerator] An enumerator that yields batches, if no block is passed.
    #
    def find_in_batches(batch_options = {}, &block)
      return ::Enumerator.new do |yielder|
        self.find_in_batches(batch_options) do |*vals|
          yielder.yield(*vals)
        end
      end unless block

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

    def [](index_or_range)
      case index_or_range
      when ::Integer
        from(index_or_range).size(1).to_a.first
      when ::Range
        range_size = index_or_range.last - index_or_range.first
        range_size += 1 unless index_or_range.exclude_end?
        from(index_or_range.first).
          size(range_size)
      else
        raise ::ArgumentError, "Expected Integer or Range"
      end
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
        @parent,
        @routing
      )
    end

    #
    # Destroy one or more documents by ID, without reading them first
    #
    def destroy(*ids)
      ids.each do |id|
        ::Elastictastic.persister.destroy!(
          @index,
          @clazz.type,
          id,
          @routing,
          (@parent.id if @parent)
        )
      end
    end

    #
    # Destroy all documents in this index.
    #
    # @note This will *not* take into account filters or queries in this scope.
    #
    def destroy_all
      #FIXME support delete-by-query
      ::Elastictastic.client.delete(@index, @clazz.type)
    end

    def sync_mapping
      #XXX is this a weird place to have this?
      ::Elastictastic.client.put_mapping(index, type, @clazz.mapping)
    end

    def exists?(id)
      ::Elastictastic.client.
        exists?(index, type, id, params_for_find.slice('routing'))
    end

    #
    # Look up one or more documents by ID.
    #
    # Retrieve one or more Elastictastic documents by ID
    #
    # @overload find(*ids)
    #   Retrieve a single document or a collection of documents
    #
    #   @param [String] ids Document IDs
    #   @return [Elastictastic::BasicDocument,Array] Collection of documents with the given IDs
    #
    # @overload find(id)
    #   Retrieve a single Elastictastic document
    #   
    #   @param [String] id ID of the document
    #   @return [Elastictastic::BasicDocument] The document with that ID, or nil if not found
    #
    # @overload find(ids)
    #   Retrieve a collection of Elastictastic documents by ID. This will
    #   return an Array even if the ids argument is a one-element Array.
    #
    #   @param [Array] ids Document IDs
    #   @return [Array] Collection of documents with the given IDs
    #
    def find(*ids)
      #TODO support combining this with other filters/query
      force_array = ::Array === ids.first
      ids = ids.flatten
      if ids.length == 1
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

    def routing(routing)
      scope = scoped({})
      scope.routing = routing
      scope
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
      self.entries.inspect
    end

    #
    # @private
    #
    def response=(response)
      self.counts = response
      @materialized_hits = materialize_hits(response['hits']['hits'])
    end

    #
    # @private
    #
    def counts=(response)
      @count ||= response['hits']['total']
      if response['facets']
        @all_facets ||= ::Hashie::Mash.new(response['facets'])
      end
    end

    #
    # @private
    #
    def find_one(id, params = {})
      data = ::Elastictastic.client.
        get(index, type, id, params_for_find_one.merge(params.stringify_keys))
      return nil if data['exists'] == false
      case data['status']
      when nil
        materialize_hit(data)
      when 404
        nil
      end
    end

    #
    # @private
    #
    def find_many(ids, params = {})
      docspec = ids.map do |id|
        { '_id' => id }.merge!(params_for_find_many).
          merge!(params.stringify_keys)
      end
      materialize_hits(
        ::Elastictastic.client.mget(docspec, index, type)['docs']
      ).map { |result, hit| result }
    end

    def multi_get_params
      {
        '_type' => type,
        '_index' => @index.name
      }.tap do |params|
        params['fields'] = ::Kernel.Array(@search['fields']) if @search['fields']
        if @routing
          params['routing'] = @routing
        elsif @clazz.routing_required?
          ::Kernel.raise ::Elastictastic::MissingParameter,
            "Must specify routing parameter to look up #{@clazz.name} by ID"
        end
      end
    end

    def multi_search_headers
      {'type' => type, 'index' => @index.name}.tap do |params|
        params['routing'] = @routing if @routing
      end
    end

    #
    # @private
    #
    def materialize_hit(hit)
      @clazz.new.tap do |result|
        result.parent = @parent if @parent
        result.elasticsearch_hit = hit
      end
    end

    protected
    attr_writer :routing

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
      return @materialized_hits if defined? @materialized_hits
      search_params = {:search_type => 'query_then_fetch'}
      search_params[:routing] = @routing if @routing
      self.response = search(search_params)
      @materialized_hits
    end

    def search_in_batches(&block)
      from, size = 0, ::Elastictastic.config.default_batch_size
      scope_with_size = self.size(size)
      begin
        scope = scope_with_size.from(from)
        params = {:search_type => 'query_then_fetch'}
        params[:routing] = @routing if @routing
        response = scope.search(params)
        self.counts = response
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
      scroll_options[:routing] = @routing if @routing
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

    def populate_counts
      params = {:search_type => 'count'}
      params[:routing] = @routing if @routing
      self.counts = search(params)
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
        if @routing
          params['routing'] = @routing
        elsif @clazz.routing_required?
          ::Kernel.raise ::Elastictastic::MissingParameter,
            "Must specify routing parameter to look up #{@clazz.name} by ID"
        end
      end
    end

    def materialize_hits(hits)
      unless ::Kernel.block_given?
        return ::Enumerator.new do |yielder|
          self.__send__(:materialize_hits, hits) do |*vals|
            yielder.yield(*vals)
          end
        end
      end
      hits.each do |hit|
        unless hit['exists'] == false
          yield materialize_hit(hit), ::Hashie::Mash.new(hit)
        end
      end
    end
  end
end
