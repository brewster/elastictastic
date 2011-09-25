require 'faraday'

module Elastictastic
  module Middleware
    class JsonEncodeBody < Faraday::Middleware
      def call(env)
        case env[:body]
        when String, nil
          # nothing
        else env[:body] = env[:body].to_json
        end
        @app.call(env)
      end
    end

    class JsonDecodeResponse < Faraday::Middleware
      def call(env)
        @app.call(env).on_complete do
          env[:body] &&= JSON.parse(env[:body])
        end
      end
    end

    class RaiseServerErrors < Faraday::Middleware
      ERROR_PATTERN = /^([A-Z][A-Za-z]*)(?::\s*)?(.*)$/

      def call(env)
        @app.call(env).on_complete do
          body = env[:body]
          if body['error']
            raise_error(body['error'], body['status'])
          elsif body['_shards'] && body['_shards']['failures']
            raise_error(
              body['_shards']['failures'].first['reason'], body['status'])
          end
        end
      end

      private

      def raise_error(server_message, status)
        match = ERROR_PATTERN.match(server_message)
        if match
          clazz = Elastictastic::ServerError.const_get(match[1])
          error = clazz.new(match[2])
          error.status = status
          Kernel.raise error
        else
          Kernel.raise Elastictastic::ServerError::ServerError, server_message
        end
      end
    end

    class LogRequests < Faraday::Middleware
      def initialize(app, logger)
        super(app)
        @logger = logger
      end

      def call(env)
        now = Time.now
        body = env[:body]
        @app.call(env).on_complete do
          method = env[:method].to_s.upcase
          time = ((Time.now - now) * 1000).to_i
          message = "ElasticSearch #{method} (#{time}ms) #{env[:url]}"
          message << ' ' << body if body
          @logger.debug(message)
        end
      end
    end
  end
end
