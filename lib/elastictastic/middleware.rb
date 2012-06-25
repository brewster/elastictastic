require 'elastictastic/transport_methods'

module Elastictastic

  module Middleware

    class Base

      include TransportMethods

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
        response = super
        if response.body
          Adapter::Response.new(
            response.status,
            response.headers,
            Elastictastic.json_decode(response.body)
          )
        else
          response
        end
      end

    end

    class RaiseServerErrors < Base

      def request(method, path, body = nil)
        super.tap do |response|
          if method != :head
            if response.body.nil?
              raise Elastictastic::ServerError::ServerError,
                "No body in ElasticSearch response with status #{env[:status]}"
            elsif response.body['error']
              raise_error(response.body['error'], response.body['status'])
            elsif response.body['_shards'] && response.body['_shards']['failures']
              raise_error(
                response.body['_shards']['failures'].first['reason'], response.body['status'])
            end
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
