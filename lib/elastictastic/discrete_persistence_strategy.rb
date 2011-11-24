require 'singleton'

module Elastictastic
  class DiscretePersistenceStrategy
    include Singleton

    DEFAULT_HANDLER = proc { |e| raise(e) if e }

    attr_accessor :auto_refresh

    def create(doc, &block)
      block ||= DEFAULT_HANDLER
      begin
        response = Elastictastic.client.create(
          doc.index,
          doc.class.type,
          doc.id,
          doc.elasticsearch_doc,
          params_for(doc)
        )
      rescue => e
        return block.call(e)
      end
      doc.id = response['_id']
      doc.version = response['_version']
      doc.persisted!
      block.call
    end

    def update(doc, &block)
      block ||= DEFAULT_HANDLER
      begin
        response = Elastictastic.client.update(
          doc.index,
          doc.class.type,
          doc.id,
          doc.elasticsearch_doc,
          params_for(doc)
        )
      rescue => e
        return block.call(e)
      end
      doc.version = response['_version']
      doc.persisted!
      block.call
    end

    def destroy(doc, &block)
      block ||= DEFAULT_HANDLER
      begin
        response = Elastictastic.client.delete(
          doc.index.name,
          doc.class.type,
          doc.id,
          params_for(doc)
        )
      rescue => e
        return block.call(e)
      end
      doc.transient!
      block.call
      response['found']
    end

    private

    def params_for(doc)
      {}.tap do |params|
        params[:refresh] = true if Elastictastic.config.auto_refresh
        params[:parent] = doc._parent_id if doc._parent_id
        params[:version] = doc.version if doc.version
      end
    end
  end
end
