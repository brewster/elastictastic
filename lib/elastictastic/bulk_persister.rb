require 'stringio'

module Elastictastic
  class BulkPersister
    def initialize
      @buffer = StringIO.new
    end

    def save(instance)
      @buffer.puts({ :index => bulk_identifier(instance) }.to_json)
      @buffer.puts(instance.to_elasticsearch_doc.to_json)
    end

    def destroy(instance)
      @buffer.puts({ :delete => bulk_identifier(instance) }.to_json)
    end

    def flush
      return if @buffer.length.zero?
      path = '/_bulk'
      path << '?refresh=true' if IndividualPersister.instance.auto_refresh
      response = JSON.parse(Elastictastic.transport.post(
        path,
        @buffer.string
      ))
      raise response['error'] if response['error']
      response
    end

    private

    def bulk_identifier(instance)
      { :_index => instance.index, :_type => instance.class.type, :_id => instance.id }
    end
  end
end
