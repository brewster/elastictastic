require 'stringio'

module Elastictastic
  class BulkPersistenceStrategy
    def initialize
      @buffer = StringIO.new
      @handlers = []
    end

    def create(instance)
      add(
        { 'create' => bulk_identifier(instance) },
        instance.to_elasticsearch_doc
      ) do |response|
        instance.id = response['create']['_id']
        instance.persisted!
      end
    end

    def destroy(instance)
      add(:delete => bulk_identifier(instance)) do |response|
        instance.transient!
      end
    end

    def flush
      return if @buffer.length.zero?

      path = '/_bulk'
      path << '?refresh=true' if Elastictastic.config.auto_refresh
      response = JSON.parse(Elastictastic.transport.post(
        path,
        @buffer.string
      ))
      raise response['error'] if response['error']

      response['items'].each_with_index do |op_response, i|
        handler = @handlers[i]
        handler.call(op_response) if handler
      end
      response
    end

    private

    def bulk_identifier(instance)
      identifier = { :_index => instance.index, :_type => instance.class.type }
      identifier['_id'] = instance.id if instance.id
      identifier
    end

    def add(*requests, &block)
      requests.each do |request|
        @buffer.puts(request.to_json)
      end
      @handlers << block
    end
  end
end
