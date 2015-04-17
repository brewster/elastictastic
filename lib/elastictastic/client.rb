module Elastictastic
  class Client
    attr_reader :connection

    def initialize(config)
      adapter_options = {
        :request_timeout => config.request_timeout,
        :write_timeout => config.write_timeout,
        :connect_timeout => config.connect_timeout
      }
      if config.hosts.length == 1
        connection = Adapter[config.adapter].
          new(config.hosts.first, adapter_options)
      else
        connection = Rotor.new(
          config.hosts,
          adapter_options.merge(
            :adapter => config.adapter,
            :backoff_threshold => config.backoff_threshold,
            :backoff_start => config.backoff_start,
            :backoff_max => config.backoff_max
          )
        )
      end
      if config.logger
        connection = Middleware::LogRequests.new(connection, config.logger)
      end
      connection = Middleware::JsonDecodeResponse.new(connection)
      connection = Middleware::JsonEncodeBody.new(connection)
      connection = Middleware::RaiseServerErrors.new(connection)
      config.extra_middlewares.each do |middleware_class, *args|
        connection = middleware_class.new(connection, *args)
      end
      @connection = connection
    end

    def create(index, type, id, doc, params = {})
      if id
        @connection.put(
          path_with_query("/#{index}/#{type}/#{id}/_create", params),
          doc
        )
      else
        @connection.post(
          path_with_query("/#{index}/#{type}", params),
          doc
        )
      end.body
    end

    def update(index, type, id, doc, params = {})
      @connection.put(
        path_with_query("/#{index}/#{type}/#{id}", params),
        doc
      ).body
    end

    def bulk(commands, params = {})
      @connection.post(path_with_query('/_bulk', params), commands).body
    end

    def exists?(index, type, id, params = {})
      @connection.head(
        path_with_query("/#{index}/#{type}/#{id}", params)
      ).status == 200
    end

    def get(index, type, id, params = {})
      @connection.get(
        path_with_query("/#{index}/#{type}/#{id}", params)
      ).body
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
      @connection.post(path, 'docs' => docspec).body
    end

    def search(index, type, search, options = {})
      path = "/#{index}/#{type}/_search"
      @connection.post(
        "#{path}?#{options.to_query}",
        search
      ).body
    end

    def msearch(search_bodies)
      @connection.post('/_msearch', search_bodies).body
    end

    def scroll(id, options = {})
      @connection.post("/_search/scroll?#{options.to_query}", id).body
    end

    def put_mapping(index, type, mapping)
      @connection.put("/#{index}/_mapping/#{type}", mapping).body
    end

    def delete(index = nil, type = nil, id = nil, params = {})
      path =
        if id then "/#{index}/#{type}/#{id}"
        elsif type then "/#{index}/#{type}"
        elsif index then "/#{index}"
        else "/"
        end
      @connection.delete(path_with_query(path, params)).body
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
