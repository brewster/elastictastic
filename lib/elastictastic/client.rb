require 'faraday'

module Elastictastic
  class Client
    attr_reader :connection

    def initialize(config)
      uri = URI::HTTP.build(:host => config.host, :port => config.port)
      @connection = Faraday.new(:url => uri.to_s) do |builder|
        builder.use Middleware::RaiseServerErrors
        builder.use Middleware::JsonEncodeBody
        builder.use Middleware::JsonDecodeResponse
        builder.adapter config.transport.to_sym
      end
    end

    def create(index, type, id, doc, params = {})
      if id
        @connection.put(
          path_with_query("/#{index}/#{type}/#{id}/_create", params), doc)
      else
        @connection.post(path_with_query("/#{index}/#{type}", params), doc)
      end.body
    end

    def update(index, type, id, doc, params = {})
      @connection.put(path_with_query("/#{index}/#{type}/#{id}", params), doc)
    end

    def bulk(commands, params = {})
      @connection.post(path_with_query('/_bulk', params), commands).body
    end

    def get(index, type, id, params = {})
      @connection.get(path_with_query("/#{index}/#{type}/#{id}", params)).body
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

    def scroll(id, options = {})
      @connection.post(
        "/_search/scroll?#{options.to_query}",
        id
      ).body
    end

    def put_mapping(index, type, mapping)
      @connection.put("/#{index}/#{type}/_mapping", mapping).body
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
