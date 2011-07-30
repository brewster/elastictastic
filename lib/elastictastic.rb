require 'active_support/core_ext'

module Elastictastic
  CancelBulkOperation = Class.new(StandardError)

  autoload :Document, 'elastictastic/document'
  autoload :Persistence, 'elastictastic/persistence'
  autoload :Resource, 'elastictastic/resource'
  autoload :Scope, 'elastictastic/scope'
  autoload :Scoped, 'elastictastic/scoped'
  autoload :Search, 'elastictastic/search'
  autoload :Util, 'elastictastic/util'

  class <<self
    def build_transport(&block)
      @transport_builder = block
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
        Elastictastic::IndividualPersister.instance
    end

    def bulk
      original_persister = self.persister
      begin
        self.persister = Elastictastic::BulkPersister.new
        yield
        self.persister.flush
      rescue Elastictastic::CancelBulkOperation
        # Nothing to see here...
      ensure
        self.persister = original_persister
      end
    end

    private

    def new_transport
      @transport_builder.call
    end
  end
end
