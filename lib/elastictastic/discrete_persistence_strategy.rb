require 'singleton'

module Elastictastic
  class DiscretePersistenceStrategy
    include Singleton

    attr_accessor :auto_refresh

    def create(doc)
      response = Elastictastic.client.create(
        doc.index,
        doc.class.type,
        doc.id,
        doc.to_elasticsearch_doc,
        params_for(doc)
      )
      doc.id = response['_id']
      doc.persisted!
    end

    def update(doc)
      Elastictastic.client.update(
        doc.index,
        doc.class.type,
        doc.id,
        doc.to_elasticsearch_doc,
        params_for(doc)
      )
      doc.persisted!
    end

    def destroy(doc)
      response = Elastictastic.client.delete(
        doc.index.name,
        doc.class.type,
        doc.id,
        params_for(doc)
      )
      doc.transient!
      response['found']
    end

    private

    def params_for(doc)
      {}.tap do |params|
        params[:refresh] = true if Elastictastic.config.auto_refresh
        params[:parent] = doc._parent.id if doc._parent
      end
    end
  end
end
