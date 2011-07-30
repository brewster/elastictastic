module Elastictastic
  class Scope < BasicObject
    include Search

    attr_reader :params

    def initialize(clazz, params, index = nil)
      @clazz, @params = clazz, Util.deep_stringify(params)
      @index = index
      @type = clazz.type
    end

    def hits
      @hits ||= response['hits']['hits'].map do |hit|
        @clazz.new_from_elasticsearch_response(hit)
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
      response['hits']['total']
    end

    def scoped(params, index = @index)
      dup_params = ::Marshal.load(::Marshal.dump(@params))
      copy = ::Elastictastic::Scope.new(@clazz, dup_params, index)
      copy.merge!(params)
      copy
    end

    def method_missing(method, *args, &block)
      @clazz.with_scope(self) do
        @clazz.__send__(method, *args, &block)
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
  end
end
