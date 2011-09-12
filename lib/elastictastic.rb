require 'active_support/core_ext'
require 'elastictastic/errors'

module Elastictastic

  autoload :BulkPersistenceStrategy, 'elastictastic/bulk_persistence_strategy'
  autoload :Configuration, 'elastictastic/configuration'
  autoload :DiscretePersistenceStrategy, 'elastictastic/discrete_persistence_strategy'
  autoload :Document, 'elastictastic/document'
  autoload :Field, 'elastictastic/field'
  autoload :Index, 'elastictastic/index'
  autoload :NetHttpTransport, 'elastictastic/net_http_transport'
  autoload :Persistence, 'elastictastic/persistence'
  autoload :Requests, 'elastictastic/requests'
  autoload :Resource, 'elastictastic/resource'
  autoload :Scope, 'elastictastic/scope'
  autoload :ScopeBuilder, 'elastictastic/scope_builder'
  autoload :Scoped, 'elastictastic/scoped'
  autoload :Search, 'elastictastic/search'
  autoload :ServerError, 'elastictastic/server_error'
  autoload :TestHelpers, 'elastictastic/test_helpers'
  autoload :TypeInIndex, 'elastictastic/type_in_index'
  autoload :Util, 'elastictastic/util'

  class <<self
    attr_writer :config

    def config
      @config ||= Elastictastic::Configuration.new
    end

    def transport=(transport)
      Thread.current['Elastictastic::transport'] = transport
    end

    def transport
      Thread.current['Elastictastic::transport'] ||= new_transport
    end

    def persister=(persister)
      Thread.current['Elastictastic::persister'] = persister
    end

    def persister
      Thread.current['Elastictastic::persister'] ||=
        Elastictastic::DiscretePersistenceStrategy.instance
    end

    def bulk
      original_persister = self.persister
      begin
        self.persister = Elastictastic::BulkPersistenceStrategy.new
        yield
        self.persister.flush
      rescue Elastictastic::CancelBulkOperation
        # Nothing to see here...
      ensure
        self.persister = original_persister
      end
    end

    def Index(name_or_index)
      Index === name_or_index ?  name_or_index : Index.new(name_or_index)
    end

    private

    def new_transport
      transport_class = const_get("#{config.transport.camelize}Transport")
      transport_class.new(config)
    end
  end
end
