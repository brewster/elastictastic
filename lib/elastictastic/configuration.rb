module Elastictastic
  class Configuration
    attr_writer :host, :port, :transport, :default_index, :auto_refresh

    def host
      @host ||= 'localhost'
    end

    def port
      @port ||= 9200
    end

    def transport
      @transport ||= 'net_http'
    end

    def default_index
      @default_index ||= 'default'
    end

    def auto_refresh
      !!@auto_refresh
    end
  end
end
