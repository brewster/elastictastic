require 'singleton'

module Elastictastic
  class IndividualPersister
    include Singleton
    include Elastictastic::Requests

    attr_accessor :auto_refresh

    def create(doc, params = {})
      params[:refresh] = true if auto_refresh
      path = "/#{doc.index}/#{doc.class.type}"
      if doc.id
        path << "/" << doc.id << "/_create"
        method = :put
      else
        method = :post
      end
      path << '?' << params.to_query if params.present?
      response = request(method, path, doc.to_elasticsearch_doc.to_json)
      doc.id = response['_id']
      doc.persisted!
    end

    def update(doc, params = {})
      params[:refresh] = true if auto_refresh
      path = doc.elasticsearch_path
      path = "#{path}?#{params.to_query}" if params.present?
      request(:put, path, doc.to_elasticsearch_doc.to_json)
      doc.persisted!
    end

    def destroy(doc, params = {})
      params[:refresh] = true if auto_refresh
      path = doc.elasticsearch_path
      path = "#{path}?#{params.to_query}" if params.present?
      request(:delete, path)
    end
  end
end
