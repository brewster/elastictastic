require 'faraday'

module Elastictastic
  module Middleware
    class AddGlobalTimeout < Faraday::Middleware
      def call(env)
        connect_timeout = Elastictastic.config.connect_timeout
        timeout = Elastictastic.config.request_timeout
        if connect_timeout || timeout
          env[:request] ||= {}
          env[:request][:open_timeout] = connect_timeout if connect_timeout
          env[:request][:timeout] = timeout if timeout
        end
        @app.call(env)
      end
    end

    class JsonEncodeBody < Faraday::Middleware
      def call(env)
        case env[:body]
        when String, nil
          # nothing
        else env[:body] = Elastictastic.json_encode(env[:body])
        end
        @app.call(env)
      end
    end

    class JsonDecodeResponse < Faraday::Middleware
      def call(env)
        @app.call(env).on_complete do
          env[:body] &&= Elastictastic.json_decode(env[:body])
        end
      end
    end

    class RaiseServerErrors < Faraday::Middleware
      def call(env)
        @app.call(env).on_complete do
          body = env[:body]
          if body.nil?
            raise Elastictastic::ServerError::ServerError,
              "No body in ElasticSearch response with status #{env[:status]}"
          elsif body['error']
            raise_error(body['error'], body['status'])
          elsif body['_shards'] && body['_shards']['failures']
            raise_error(
              body['_shards']['failures'].first['reason'], body['status'])
          end
        end
      end

      private

      def raise_error(server_message, status)
        ::Kernel.raise(Elastictastic::ServerError[server_message, status])
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
          message = "ElasticSearch #{method} (#{time}ms) #{env[:url].path}"
          message << '?' << env[:url].query if env[:url].query.present?
          message << ' ' << body if body
          @logger.debug(message)
        end
      end
    end

    class RaiseOnStatusZero < Faraday::Middleware
      def call(env)

        @app.call(env).on_complete do
          if env[:status] == 0
            raise Faraday::Error::ConnectionFailed, "Got status 0 from response"
          end
        end
      end
    end
  end
end
