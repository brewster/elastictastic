require 'elastictastic/transport_methods'

module Elastictastic

  class Adapter

    include TransportMethods

    Response = Struct.new(:status, :headers, :body)

    def self.[](str)
      case str
      when nil then NetHttpAdapter
      when /^[a-z_]+$/ then Elastictastic.const_get("#{str.to_s.classify}Adapter")
      else str.constantize
      end
    end

    def initialize(host, options = {})
      @host = host
      @request_timeout = options[:request_timeout]
      @connect_timeout = options[:connect_timeout]
    end

  end

  class NetHttpAdapter < Adapter

    def initialize(host, options = {})
      super
      uri = URI.parse(host)
      @connection = Net::HTTP.new(uri.host, uri.port)
      @connection.read_timeout = @request_timeout
    end

    def request(method, path, body = nil)
      response =
        case method
        when :head then @connection.head(path)
        when :get then @connection.get(path)
        when :post then @connection.post(path, body.to_s)
        when :put then @connection.put(path, body.to_s)
        when :delete then @connection.delete(path)
        else raise ArgumentError, "Unsupported method #{method.inspect}"
        end
      Response.new(response.code.to_i, response.to_hash, response.body)
    rescue Errno::ECONNREFUSED, Timeout::Error, SocketError => e
      raise ConnectionFailed, e
    end

  end

  class ExconAdapter < Adapter

    def request(method, path, body = nil)
      retried = false
      begin
        response = connection.request(
          :body => body, :method => method, :path => path
        )
        Response.new(response.status, response.headers, response.body)
      rescue Excon::Errors::SocketError => e
        case e.socket_error
        when Errno::EPIPE, Errno::ECONNRESET
          if !retried
            connection.reset
            retried = true
            retry
          end
        end
        raise
      end
    rescue Excon::Errors::Error => e
      connection.reset
      raise ConnectionFailed, e
    end

    private

    def connection
      @connection ||= Excon.new(@host, connection_params)
    end

    def connection_params
      @connection_params ||= {}.tap do |params|
        if @request_timeout
          params[:read_timeout] = params[:write_timeout] = @request_timeout
        end
        if @connect_timeout
          params[:connect_timeout] = @connect_timeout
        end
      end
    end

  end

end
