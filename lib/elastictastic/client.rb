module Elastictastic
  class Client
    attr_reader :connection

    def initialize(config)
      if config.hosts.length == 1
        connection = Adapter[config.adapter].new(config.hosts.first)
      else
        connection = Rotor.new(
          config.hosts,
          :adapter => config.adapter,
          :backoff_threshold => config.backoff_threshold,
          :backoff_start => config.backoff_start,
          :backoff_max => config.backoff_max
        )
      end
      if config.logger
        connection = Middleware::LogRequests.new(connection, config.logger)
      end
      connection = Middleware::JsonDecodeResponse.new(connection)
      connection = Middleware::JsonEncodeBody.new(connection)
      connection = Middleware::RaiseServerErrors.new(connection)
      @connection = connection
    end

    def create(index, type, id, doc, params = {})
      if id
        @connection.request(
          :put,
          path_with_query("/#{index}/#{type}/#{id}/_create", params),
          doc
        )
      else
        @connection.request(
          :post,
          path_with_query("/#{index}/#{type}", params),
          doc
        )
      end
    end

    def update(index, type, id, doc, params = {})
      @connection.request(
        :put,
        path_with_query("/#{index}/#{type}/#{id}", params),
        doc
      )
    end

    def bulk(commands, params = {})
      @connection.request(:post, path_with_query('/_bulk', params), commands)
    end

    def get(index, type, id, params = {})
      @connection.request(
        :get,
        path_with_query("/#{index}/#{type}/#{id}", params)
      )
    end

    def mget(docspec, index = nil, type = nil)
      path =
        if index.present?
          if type.present?
            "/#{index}/#{type}/_mget"
          else index.present?
            "#{index}/_mget"
          end
        else
          "/_mget"
        end
      @connection.request(:post, path, 'docs' => docspec)
    end

    def search(index, type, search, options = {})
      path = "/#{index}/#{type}/_search"
      @connection.request(
        :post,
        "#{path}?#{options.to_query}",
        search
      )
    end

    def msearch(search_bodies)
      @connection.request(:post, '/_msearch', search_bodies)
    end

    def scroll(id, options = {})
      @connection.request(:post, "/_search/scroll?#{options.to_query}", id)
    end

    def put_mapping(index, type, mapping)
      @connection.request(:put, "/#{index}/#{type}/_mapping", mapping)
    end

    def delete(index = nil, type = nil, id = nil, params = {})
      path =
        if id then "/#{index}/#{type}/#{id}"
        elsif type then "/#{index}/#{type}"
        elsif index then "/#{index}"
        else "/"
        end
      @connection.request(:delete, path_with_query(path, params))
    end

    private

    def path_with_query(path, query)
      if query.present?
        "#{path}?#{query.to_query}"
      else
        path
      end
    end
  end
end
