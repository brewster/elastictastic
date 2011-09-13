module Elastictastic
  class Scope < BasicObject
    include ::Enumerable
    include Search

    attr_reader :params

    def initialize(type_in_index, params)
      @type_in_index, @params = type_in_index, Util.deep_stringify(params)
    end

    def each(&block)
      find_each(&block)
    end

    def find_each(batch_options = {}, &block)
      find_in_batches(batch_options) do |batch|
        batch.each(&block)
      end
    end

    def find_in_batches(batch_options = {}, &block)
      if params.key?('size') || params.key('from')
        yield search_all
      elsif params.key?('sort') || params.key('facets')
        search_in_batches(&block)
      else
        scan_in_batches(batch_options, &block)
      end
    end

    def response
      index = @index || '_all'
      @response ||= ::JSON.parse(::Elastictastic.transport.post(
        "/#{index}/#{@type}/_search",
        params.to_json
      ))
      raise @response['error'] if @response['error']
      @response
    end

    def count
      @count
    end

    def scoped(params, index = @index)
      dup_params = ::Marshal.load(::Marshal.dump(@params))
      copy = ::Elastictastic::Scope.new(@type_in_index, dup_params)
      copy.merge!(params)
      copy
    end

    def method_missing(method, *args, &block)
      @type_in_index.clazz.with_scope(self) do
        @type_in_index.clazz.__send__(method, *args, &block)
      end
    end

    def _index
      @index
    end

    def inspect
      @params.inspect
    end

    protected

    def merge!(params)
      @params = Util.deep_merge(@params, Util.deep_stringify(params))
    end

    def search_all(options = {})
      response = @type_in_index.search(
        self, options.reverse_merge(:search_type => 'query_then_fetch'))

      @count = response['hits']['total']
      response['hits']['hits'].map do |hit|
        @type_in_index.clazz.new_from_elasticsearch_hit(hit)
      end
    end

    private

    def search_in_batches(&block)
      from, size, result_count = 0, 100, 0
      scope_with_size = self.size(size)
      begin
        scope = scope_with_size.from(from)
        results = scope.search_all(:search_type => 'query_and_fetch')
        yield(results)
        from += size
        result_count += results.length
        @count ||= scope.count
      end while result_count < @count
    end

    def scan_in_batches(batch_options, &block)
      batch_options = batch_options.symbolize_keys
      scroll_options = {
        :scroll => "#{batch_options[:ttl] || 60}s",
        :size => batch_options[:batch_size] || 100
      }
      scan_response = @type_in_index.search(
        self, scroll_options.merge(:search_type => 'scan'))
      scroll_id = scan_response['_scroll_id']

      begin
        response = @type_in_index.scroll(scroll_id, scroll_options.slice(:scroll))
        scroll_id = response['_scroll_id']
        docs = response['hits']['hits'].map do |hit|
          @type_in_index.clazz.new_from_elasticsearch_hit(hit)
        end
        yield(docs)
      end until response['hits']['hits'].empty?
    end
  end
end
