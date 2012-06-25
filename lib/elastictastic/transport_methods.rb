module Elastictastic

  module TransportMethods

    def head(path)
      request(:head, path)
    end

    def get(path)
      request(:get, path)
    end

    def post(path, body)
      request(:post, path, body)
    end

    def put(path, body)
      request(:put, path, body)
    end

    def delete(path)
      request(:delete, path)
    end

  end

end
