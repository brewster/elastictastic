module Elastictastic
  class TypeInIndex
    include Requests
    attr_reader :clazz, :index

    def initialize(clazz, index)
      @clazz, @index = clazz, index
    end

    def new(*args)
      @clazz.new(*args).tap do |document|
        index = @index
        document.instance_eval { @index = index }
      end
    end

    def destroy_all
      request :delete, "/#{index}/#{type}"
    end

    def sync_mapping
      request :put, "/#{index}/#{type}/_mapping", @clazz.mapping.to_json
    end

    def type
      @clazz.type
    end

    def find(id)
      data = request :get, "/#{index}/#{type}/#{id}"
      return nil if data['exists'] == false
      case data['status']
      when nil
        @clazz.new_from_elasticsearch_hit(data)
      when 404
        nil
      else
        raise data['error'] || "Unexpected response from ElasticSearch: #{data.inspect}"
      end
    end

    def search(scope, options = {})
      path = "/#{index}/#{type}/_search"
      request(
        :post,
        "#{path}?#{options.to_query}",
        scope.params.to_json
      )
    end

    # XXX This doesn't really belong here.
    def scroll(id, options = {})
      request(
        :post,
        "/_search/scroll?#{options.to_query}",
        id
      )
    end
  end
end
