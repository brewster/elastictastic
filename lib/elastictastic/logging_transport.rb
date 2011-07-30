module Elastictastic
  class LoggingTransport
    def initialize(transport, logger, level = :debug)
      @transport, @logger, @level = transport, logger, level
    end

    def get(path, params = nil, headers = {})
      path_with_query = path
      path_with_query << '?' << params.to_query if params
      log("GET #{path_with_query}")
      @transport.get(path_with_query, headers)
    end

    def post(path, data, headers = {})
      log("POST #{path} #{data}")
      @transport.post(path, data, headers)
    end

    def put(path, data, headers = {})
      log("PUT #{path} #{data}")
      @transport.put(path, data, headers)
    end

    def delete(path, data = nil, headers = {})
      log("DELETE #{path} #{data}")
      @transport.delete(path, data, headers)
    end

    private

    def log(message)
      @logger.__send__(@level, "  ElasticSearch #{message}")
    end
  end
end
