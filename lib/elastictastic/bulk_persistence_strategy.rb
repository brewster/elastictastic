require 'stringio'

module Elastictastic
  class BulkPersistenceStrategy
    def initialize
      @buffer = StringIO.new
      @handlers = []
    end

    def create(instance, params = {})
      if instance.pending_save?
        raise Elastictastic::OperationNotAllowed,
          "Can't re-save transient document with pending save in bulk operation"
      end
      instance.pending_save!
      add(
        { 'create' => bulk_identifier(instance) },
        instance.elasticsearch_doc
      ) do |response|
        instance.id = response['create']['_id']
        instance.version = response['create']['_version']
        instance.persisted!
      end
    end

    def update(instance)
      instance.pending_save!
      add(
        { 'index' => bulk_identifier(instance) },
        instance.elasticsearch_doc
      ) do |response|
        instance.version = response['index']['_version']
      end
    end

    def destroy(instance)
      instance.pending_destroy!
      add(:delete => bulk_identifier(instance)) do |response|
        instance.transient!
        instance.version = response['delete']['_version']
      end
    end

    def flush
      return if @buffer.length.zero?

      params = {}
      params[:refresh] = true if Elastictastic.config.auto_refresh
      response = Elastictastic.client.bulk(@buffer.string, params)

      response['items'].each_with_index do |op_response, i|
        handler = @handlers[i]
        handler.call(op_response) if handler
      end
      response
    end

    private

    def bulk_identifier(instance)
      identifier = { :_index => instance.index.name, :_type => instance.class.type }
      identifier['_id'] = instance.id if instance.id
      identifier['_version'] = instance.version if instance.version
      identifier['parent'] = instance._parent_id if instance._parent_id
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
