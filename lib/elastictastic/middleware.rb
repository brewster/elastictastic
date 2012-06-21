module Elastictastic
  module Middleware
    class Base
      def initialize(connection)
        @connection = connection
      end

      def request(method, path, body = nil)
        @connection.request(method, path, body)
      end
    end

    class JsonEncodeBody < Base
      def request(method, path, body = nil)
        case body
        when String, nil
          super
        else
          @connection.request(
            method, path,
            Elastictastic.json_encode(body)
          )
        end
      end
    end

    class JsonDecodeResponse < Base
      def request(method, path, body = nil)
        response_body = super
        Elastictastic.json_decode(response_body) if response_body
      end
    end

    class RaiseServerErrors < Base
      def request(method, path, body = nil)
        super.tap do |response_body|
          if response_body.nil?
            raise Elastictastic::ServerError::ServerError,
              "No body in ElasticSearch response with status #{env[:status]}"
          elsif response_body['error']
            raise_error(response_body['error'], response_body['status'])
          elsif response_body['_shards'] && response_body['_shards']['failures']
            raise_error(
              response_body['_shards']['failures'].first['reason'], response_body['status'])
          end
        end
      end

      private

      def raise_error(server_message, status)
        ::Kernel.raise(Elastictastic::ServerError[server_message, status])
      end
    end

    class LogRequests < Base
      def initialize(connection, logger)
        super(connection)
        @logger = logger
      end

      def request(method, path, body = nil)
        now = Time.now
        super.tap do
          time = ((Time.now - now) * 1000).to_i
          message = "ElasticSearch #{method.to_s.upcase} (#{time}ms) #{path}"
          message << ' ' << body if body
          @logger.debug(message)
        end
      end
    end
  end
end
