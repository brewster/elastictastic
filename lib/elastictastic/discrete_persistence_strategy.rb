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
          params_for_doc(doc)
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
          params_for_doc(doc)
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
          params_for_doc(doc)
        )
      rescue => e
        return block.call(e)
      end
      doc.transient!
      block.call
      response['found']
    end

    def destroy!(index, type, id, routing, parent)
      response = Elastictastic.client.delete(
        index,
        type,
        id,
        params_for(routing, parent, nil)
      )
      response['found']
    end

    private

    def params_for_doc(doc)
      params_for(
        doc.class.route(doc),
        doc._parent_id,
        doc.version
      )
    end

    def params_for(routing, parent_id, version)
      {}.tap do |params|
        params[:refresh] = true if Elastictastic.config.auto_refresh
        params[:parent] = parent_id if parent_id
        params[:version] = version if version
        params[:routing] = routing.to_s if routing
      end
    end
  end
end
