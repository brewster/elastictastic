module Elastictastic
  class IndividualPersister
    include Singleton

    attr_accessor :auto_refresh

    def save(doc, params = {})
      params[:refresh] = true if auto_refresh
      path = doc.elasticsearch_path
      path = "#{path}?#{params.to_query}" if params.present?
      response = JSON.parse(Elastictastic.transport.put(path, doc.to_elasticsearch_doc.to_json))
      raise response['error'] if response['error']
    end

    def destroy(doc, params = {})
      params[:refresh] = true if auto_refresh
      path = doc.elasticsearch_path
      path = "#{path}?#{params.to_query}" if params.present?
      response = JSON.parse(Elastictastic.transport.delete(path))
      raise response['error'] if response['error']
    end
  end
end
