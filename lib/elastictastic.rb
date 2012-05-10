require 'active_support/core_ext'
require 'active_model'

require 'elastictastic/basic_document'
require 'elastictastic/errors'
require 'elastictastic/client'
require 'elastictastic/configuration'
require 'elastictastic/discrete_persistence_strategy'
require 'elastictastic/embedded_document'
require 'elastictastic/field'
require 'elastictastic/index'
require 'elastictastic/middleware'
require 'elastictastic/optimistic_locking'
require 'elastictastic/persistence'
require 'elastictastic/properties'
require 'elastictastic/scope'
require 'elastictastic/scope_builder'
require 'elastictastic/scoped'
require 'elastictastic/search'
require 'elastictastic/server_error'
require 'elastictastic/util'

module Elastictastic
  autoload :Association, 'elastictastic/association'
  autoload :BulkPersistenceStrategy, 'elastictastic/bulk_persistence_strategy'
  autoload :Callbacks, 'elastictastic/callbacks'
  autoload :ChildCollectionProxy, 'elastictastic/child_collection_proxy'
  autoload :Dirty, 'elastictastic/dirty'
  autoload :Document, 'elastictastic/document'
  autoload :MassAssignmentSecurity, 'elastictastic/mass_assignment_security'
  autoload :MultiSearch, 'elastictastic/multi_search'
  autoload :NestedCollectionProxy, 'elastictastic/nested_collection_proxy'
  autoload :Observer, 'elastictastic/observer'
  autoload :Observing, 'elastictastic/observing'
  autoload :ParentChild, 'elastictastic/parent_child'
  autoload :Rotor, 'elastictastic/rotor'
  autoload :TestHelpers, 'elastictastic/test_helpers'
  autoload :ThriftAdapter, 'elastictastic/thrift_adapter'
  autoload :Validations, 'elastictastic/validations'

  autoload :NestedDocument, 'elastictastic/nested_document' # Deprecated

  class <<self
    attr_writer :config

    # 
    # Elastictastic global configuration. In a Rails environment, you can
    # configure Elastictastic by creating a `config/elastictastic.yml` file,
    # whose keys will be passed into the Configuration object when your
    # application boots. In non-Rails environment, you can configure
    # Elastictastic directly using the object returned by this method.
    #
    # @return [Configuration] global configuration object
    #
    def config
      @config ||= Configuration.new
    end

    #
    # Perform multiple searches in a single request to ElasticSearch. Each
    # scope will be eagerly populated with results.
    #
    # @param [Scope, Array] collection of scopes to execute multisearch on
    #
    def multi_search(*scopes)
    end

    #
    # Return a lower-level ElasticSearch client. This is likely to be extracted
    # into a separate gem in the future.
    #
    # @return [Client] client
    # @api private
    #
    def client
      Thread.current['Elastictastic::client'] ||= Client.new(config)
    end

    # 
    # Set the current persistence strategy
    #
    # @param [DiscretePersistenceStrategy,BulkPersistenceStrategy] persistence strategy
    # @api private
    # @see ::persister
    #
    def persister=(persister)
      Thread.current['Elastictastic::persister'] = persister
    end

    # 
    # The current persistence strategy for ElasticSearch. Usually this will
    # be the DiscretePersistenceStrategy singleton; inside a ::bulk block, it
    # will be an instance of BulkPersistenceStrategy
    #
    # @return [DiscretePersistenceStrategy,BulkPersistenceStrategy] current persistence strategy
    # @api private
    # @see ::bulk
    #
    def persister
      Thread.current['Elastictastic::persister'] ||=
        Elastictastic::DiscretePersistenceStrategy.instance
    end

    # 
    # Perform write operations in a single request to ElasticSearch. Highly
    # recommended for any operation which writes a large quantity of data to
    # ElasticSearch. Write operations (e.g. save/destroy documents) are buffered
    # in the client and sent to ElasticSearch when the bulk operation exits
    # (or when an auto-flush threshold is reached; see below).
    #
    # @example Create posts in bulk
    #   Elastictastic.bulk do
    #     params[:posts].each do |post_params|
    #       Post.new(post_params).save!
    #     end
    #   end # posts are actually persisted here
    #
    # Since write operations inside a bulk block are not performed
    # synchronously, server-side errors will only be raised once the bulk block
    # completes; you may pass a block into Document#save and Document#destroy
    # that will be called once the operation completes. The block is passed an
    # error param if the operation was not successful.
    #
    # @example Custom handling for conflicting IDs in a bulk block
    #   errors = []
    #   Elastictastic.bulk do
    #     params[:posts].each do |post_params|
    #       Post.new(post_params).save! do |e|
    #         case e
    #         when nil # success!
    #         when Elastictastic::ServerError::DocumentAlreadyExistsEngineException
    #           conflicting_ids << post_params[:id]
    #         else
    #           raise e
    #         end
    #       end
    #     end
    #   end
    #
    # @option options [Fixnum] :auto_flush Flush to ElasticSearch after this many operations performed.
    # @yield Block during which all write operations are buffered for bulk
    #
    def bulk(options = {})
      original_persister = self.persister
      bulk_persister = self.persister =
        Elastictastic::BulkPersistenceStrategy.new(options)
      begin
        yield
      ensure
        self.persister = original_persister
      end
      bulk_persister.flush
    end

    #
    # Use Elastictastic's configured JSON encoder to encode a JSON message.
    #
    # @param [Object] Object to encode to JSON
    # @return JSON representation of object
    # @api private
    #
    def json_encode(object)
      config.json_engine.dump(object)
    end

    #
    # Use Elastictastic's configured JSON decoder to decode a JSON message
    #
    # @param [String] JSON message to decode
    # @return Ruby object represented by json param
    # @api private
    #
    def json_decode(json)
      config.json_engine.load(json)
    end

    #
    # Coerce the argument to an Elastictastic index.
    # 
    # @param [String,Elastictastic::Index] name_or_index Index name or object
    # @api private
    #
    def Index(name_or_index)
      Index === name_or_index ?  name_or_index : Index.new(name_or_index)
    end
  end
end

require 'elastictastic/railtie' if defined? Rails
