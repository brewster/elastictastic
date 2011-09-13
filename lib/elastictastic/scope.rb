module Elastictastic
  class Scope < BasicObject
    include Search

    attr_reader :params

    def initialize(type_in_index, params)
      @type_in_index, @params = type_in_index, Util.deep_stringify(params)
    end

    def each(batch_options = {}, &block)
      find_in_batches(batch_options) do |batch|
        batch.each(&block)
      end
    end
    alias_method :find_each, :each

    def find_in_batches(batch_options = {}, &block)
      batch_options = batch_options.symbolize_keys
      scroll_options = {
        :scroll => "#{batch_options[:ttl] || 60}s",
        :size => batch_options[:batch_size] || 100
      }
      scan_response = scan_search(scroll_options)
      scroll_id = scan_response['_scroll_id']

      begin
        response = scroll(scroll_id, scroll_options.slice(:scroll))
        scroll_id = response['_scroll_id']
        docs = response['hits']['hits'].map do |hit|
          @type_in_index.clazz.new_from_elasticsearch_hit(hit)
        end
        yield(docs)
      end until response['hits']['hits'].empty?
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
      response['hits']['total']
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

    private

    #FIXME get this out of here!
    def scan_search(options = {})
      path = "/#{@type_in_index.index}/#{@type_in_index.type}/_search"
      ::JSON.parse(::Elastictastic.transport.post(
        "#{path}?#{options.merge(:search_type => :scan).to_query}",
        params.to_json
      ))
    end

    #FIXME this too!
    def scroll(id, options = {})
      ::JSON.parse(::Elastictastic.transport.post(
        "/_search/scroll?#{options.to_query}",
        id
      ))
    end
  end
end
