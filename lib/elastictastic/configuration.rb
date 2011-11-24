module Elastictastic
  class Configuration

    attr_writer :hosts, :default_index, :auto_refresh, :default_batch_size
    attr_accessor :logger

    def host=(host)
      @hosts = [host]
    end

    def hosts
      @hosts ||= ['http://localhost:9200']
    end

    def adapter=(adapter)
      @adapter =
        case adapter
        when 'Thrift', 'thrift' then Elastictastic::ThriftAdapter
        when Class, /^[A-Z][A-Za-z0-9]+$/ then adapter
        when /^[a-z_]+/ then adapter.camelize
        else raise ArgumentError, "Unrecognized adapter name #{adapter}"
        end
    end

    def adapter
      @adapter ||= :net_http
    end

    def default_index
      @default_index ||= 'default'
    end

    def auto_refresh
      !!@auto_refresh
    end

    def default_batch_size
      @default_batch_size ||= 100
    end

    ActiveModel::Observing::ClassMethods.public_instance_methods(false).each do |method|
      delegate method, :to => :"::Elastictastic::Observing"
    end
  end
end
