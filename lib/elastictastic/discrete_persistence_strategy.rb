require 'singleton'

module Elastictastic
  class DiscretePersistenceStrategy
    include Singleton

    attr_accessor :auto_refresh

    def create(doc, params = {})
      params[:refresh] = true if Elastictastic.config.auto_refresh
      response = Elastictastic.client.create(doc.index, doc.class.type, doc.id, doc.to_elasticsearch_doc, params)
      doc.id = response['_id']
      doc.persisted!
    end

    def update(doc, params = {})
      params[:refresh] = true if Elastictastic.config.auto_refresh
      Elastictastic.client.update(
        doc.index, doc.class.type, doc.id, doc.to_elasticsearch_doc, params)
      doc.persisted!
    end

    def destroy(doc, params = {})
      params[:refresh] = true if Elastictastic.config.auto_refresh
      response = Elastictastic.client.delete(doc.index.name, doc.class.type, doc.id, params)
      doc.transient!
      response['found']
    end
  end
end
