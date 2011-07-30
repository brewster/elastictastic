module Elastictastic
  class MockTransport
    attr_reader :requests

    def initialize(options = {})
      @requests = []
    end

    def clear
      @requests.clear
      @next_response = nil
    end

    def get(path, params = {}, headers = {})
      @requests << [:get, path, params, headers]
      @next_response
    end

    def post(path, data, headers = {})
      @requests << [:post, path, data, headers]
      @next_response
    end

    def put(path, data, headers = {})
      @requests << [:put, path, data, headers]
      @next_response
    end
    
    def delete(path, data = nil, headers = {})
      @requests << [:delete, path, data, headers]
      @next_response
    end

    def last_request
      @requests.last
    end

    def next_response=(data)
      @next_response = data.to_json
    end
  end
end
