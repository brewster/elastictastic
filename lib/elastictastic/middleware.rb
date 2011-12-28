require 'faraday'

module Elastictastic
  module Middleware
    class AddGlobalTimeout < Faraday::Middleware
      def call(env)
        timeout = Elastictastic.config.request_timeout
        if timeout
          env[:request] ||= {}
          env[:request][:timeout] = timeout
        end
        @app.call(env)
      end
    end

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
          message << ' ' << body if body
          @logger.debug(message)
        end
      end
    end

    class Rotor < Faraday::Middleware
      def initialize(app, *hosts)
        first = nil
        hosts.each do |host|
          node = Node.new(app, host)
          first ||= node
          @head.next = node if @head
          @head = node
        end
        @head.next = first
      end

      def call(env)
        last = @head
        begin
          @head = @head.next
          @head.call(env)
        rescue Faraday::Error::ConnectionFailed => e
          raise NoServerAvailable if @head == last
          retry
        end
      end

      class Node < Faraday::Middleware
        attr_accessor :next

        def initialize(app, url)
          super(app)
          # Create a connection instance so we can use its #build_url method.
          # Kinda lame -- seems like it would make more sense for Faraday to
          # just implement a middleware for injecting a host/path prefix.
          @connection = Faraday::Connection.new(:url => url)
        end

        def call(env)
          original_url = env[:url]
          begin
            env[:url] = @connection.build_url(original_url)
            @app.call(env)
          ensure
            env[:url] = original_url
          end
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
