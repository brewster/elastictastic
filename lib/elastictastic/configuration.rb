module Elastictastic
  class Configuration

    attr_writer :hosts, :default_index, :auto_refresh, :default_batch_size, :adapter
    attr_accessor :logger, :connect_timeout, :request_timeout, :backoff_threshold, :backoff_start, :backoff_max
    attr_reader :extra_middlewares

    def initialize
      @extra_middlewares = []
    end

    def host=(host)
      @hosts = [host]
    end

    def hosts
      @hosts ||= [default_host]
    end

    def adapter
      @adapter ||= :net_http
    end

    def default_index
      return @default_index if defined? @default_index
      if url_from_env && url_from_env.path =~ /^\/([^\/]+)/
        @default_index = $1
      else
        @default_index = 'default'
      end
    end

    def auto_refresh
      !!@auto_refresh
    end

    def default_batch_size
      @default_batch_size ||= 100
    end

    def json_engine=(json_engine)
      original_engine = MultiJson.engine
      MultiJson.engine = json_engine
      @json_engine = MultiJson.engine
    ensure
      MultiJson.engine = original_engine
    end

    def json_engine
      @json_engine || MultiJson.engine
    end

    def use_middleware(*args)
      @extra_middlewares << args
    end

    def presets
      @presets ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    def presets=(new_presets)
      presets.merge!(new_presets)
    end

    private

    def default_host
      if url_from_env
        url_from_env.class.build(
          :host => url_from_env.host,
          :port => url_from_env.port,
          :path => url_from_env.path
        ).to_s
      else
        'http://localhost:9200'
      end
    end

    def url_from_env
      return @url_from_env if defined? @url_from_env
      @url_from_env = 
        if ENV['ELASTICSEARCH_URL']
          URI.parse(ENV['ELASTICSEARCH_URL'])
        end
    end

    ActiveModel::Observing::ClassMethods.public_instance_methods(false).each do |method|
      delegate method, :to => :"::Elastictastic::Observing"
    end
  end
end
