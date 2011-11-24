require 'stringio'

module Elastictastic
  class BulkPersistenceStrategy
    DEFAULT_HANDLER = proc { |e| raise(e) if e }

    def initialize(options)
      @buffer = StringIO.new
      @buffered_operations = 0
      @handlers = []
      @auto_flush = options.delete(:auto_flush)
    end

    def create(instance, params = {}, &block)
      block ||= DEFAULT_HANDLER
      if instance.pending_save?
        raise Elastictastic::OperationNotAllowed,
          "Can't re-save transient document with pending save in bulk operation"
      end
      instance.pending_save!
      add(
        { 'create' => bulk_identifier(instance) },
        instance.elasticsearch_doc
      ) do |response|
        if response['create']['error']
          block.call(ServerError[response['error']])
        else
          instance.id = response['create']['_id']
          instance.version = response['create']['_version']
          instance.persisted!
          block.call
        end
      end
    end

    def update(instance, &block)
      block ||= DEFAULT_HANDLER
      instance.pending_save!
      add(
        { 'index' => bulk_identifier(instance) },
        instance.elasticsearch_doc
      ) do |response|
        if response['index']['error']
          block.call(ServerError[response['index']['error']])
        else
          instance.version = response['index']['_version']
          block.call
        end
      end
    end

    def destroy(instance, &block)
      block ||= DEFAULT_HANDLER
      instance.pending_destroy!
      add(:delete => bulk_identifier(instance)) do |response|
        if response['delete']['error']
          block.call(ServerError[response['index']['error']])
        else
          instance.transient!
          instance.version = response['delete']['_version']
          block.call
        end
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
      @buffer.reopen
      @handlers.clear
      @buffered_operations = 0
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
      requests.each { |request| @buffer.puts(request.to_json) }
      @buffered_operations += 1
      @handlers << block
      flush if @auto_flush && @buffered_operations >= @auto_flush
    end
  end
end
