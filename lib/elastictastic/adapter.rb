module Elastictastic

  class Adapter

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
      case method
      when :get then @connection.get(path).body
      when :post then @connection.post(path, body.to_s).body
      when :put then @connection.put(path, body.to_s).body
      when :delete then @connection.delete(path).body
      else raise ArgumentError, "Unsupported method #{method.inspect}"
      end
    rescue Errno::ECONNREFUSED, Timeout::Error, SocketError => e
      raise ConnectionFailed, e
    end
  end

  class ExconAdapter < Adapter

    def initialize(host, options = {})
      super(options)
      @connection = Excon.new(host)
    end

    def request(method, path, body = nil)
      @connection.request(
        default_options.merge(:body => body, :method => method, :path => path)
      ).body
    rescue Excon::Errors::Error => e
      raise ConnectionFailed, e
    end

    def default_options
      @default_options ||= {
        :read_timeout => @request_timeout,
        :write_timeout => @request_timeout,
        :connect_timeout => @connect_timeout
      }
    end

  end

end
