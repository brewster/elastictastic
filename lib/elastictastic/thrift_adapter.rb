begin
  require 'thrift'
rescue LoadError
  raise LoadError, 'Using the ThriftAdapter requires the "thrift" gem. Please install it.'
end
require 'cgi'
require 'faraday'
require 'elastictastic/thrift/rest'

module Elastictastic
  class ThriftAdapter < Faraday::Adapter
    def initialize(options = {})
      @options = {}
    end

    def call(env)
      super
      url = env[:url]
      req = env[:request]

      request = Elastictastic::Thrift::RestRequest.new
      request.method =
        Elastictastic::Thrift::Method.const_get(env[:method].to_s.upcase)
      request.body = env[:body] if env[:body]
      request.uri = url.path
      parameters = {}
      request.parameters = url.query_values

      response = thrift_request(url.host, url.inferred_port, request)

      save_response(env, response.status, response.body) do |response_headers|
        if response.headers
          headers.each_pair do |key, value|
            response_headers[key] = value
          end
        end
      end

      @app.call(env)
    end

    private

    def thrift_request(host, port, request)
      @thrift_clients ||= {}
      client = @thrift_clients[[host, port]] ||=
        begin
          transport = ::Thrift::BufferedTransport.new(::Thrift::Socket.new(host, port, @options[:timeout]))
          protocol = ::Thrift::BinaryProtocol.new(transport)
          Elastictastic::Thrift::Rest::Client.new(protocol).tap do
            transport.open
          end
        end
      client.execute(request)
    rescue ::Thrift::TransportException, IOError => e
      @thrift_clients.delete([host, port])
      raise Faraday::Error::ConnectionFailed, e.message
    end
  end
end
