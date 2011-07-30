module Elastictastic
  class PatronTransport
    def initialize(options = {})
      @http = Patron::Session.new
      @http.base_url = URI::HTTP.build(options.symbolize_keys.slice(:host, :port)).to_s
      @http.timeout = 60
    end

    def get(path, params = nil, headers = {})
      path_with_query = path
      path_with_query << '?' << params.to_query if params
      @http.get(path_with_query, headers).body
    end

    def post(path, data, headers = {})
      @http.post(path, data, headers).body
    end

    def put(path, data, headers = {})
      @http.put(path, data, headers).body
    end

    def delete(path, data = nil, headers = {})
      @http.request(:delete, path, headers, :data => data).body
    end
  end
end
