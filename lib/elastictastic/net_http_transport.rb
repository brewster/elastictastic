require 'net/http'

module Elastictastic
  class NetHttpTransport
    def initialize(config)
      @http = Net::HTTP.new(config.host, config.port)
    end

    def get(path, query = nil, headers = {})
      path_with_query = path
      path_with_query << '?' << query.to_query if query
      @http.get(path_with_query, headers).body
    end

    def post(path, data, headers = {})
      @http.post(path, data, headers).body
    end

    def put(path, data, headers = {})
      @http.put(path, data, headers).body
    end

    def delete(path, data = nil, headers = {})
      unless data.nil?
        raise ArgumentError, 'Cannot make this request with the Net::HTTP adapter, as Net::HTTP does not support DELETE requests with bodies.'
      end
      @http.delete(path, headers)
    end
  end
end
