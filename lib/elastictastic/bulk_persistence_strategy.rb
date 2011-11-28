require 'stringio'

module Elastictastic
  class BulkPersistenceStrategy
    DEFAULT_HANDLER = proc { |e| raise(e) if e }
    Operation = Struct.new(:id, :commands, :handler, :skip)

    def initialize(options)
      @operations = []
      @operations_by_id = {}
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
        instance.id,
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
        instance.id,
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
      add(instance.id, :delete => bulk_identifier(instance)) do |response|
        if response['delete']['error']
          block.call(ServerError[response['delete']['error']])
        else
          instance.transient!
          instance.version = response['delete']['_version']
          block.call
        end
      end
    end

    def flush
      return if @operations.empty?

      params = {}
      params[:refresh] = true if Elastictastic.config.auto_refresh
      io = StringIO.new
      operations = @operations.reject { |operation| operation.skip }
      operations.each do |operation|
        operation.commands.each { |command| io.puts command.to_json }
      end
      response = Elastictastic.client.bulk(io.string, params)

      response['items'].each_with_index do |op_response, i|
        operation = operations[i]
        operation.handler.call(op_response) if operation.handler
      end
      @operations.clear
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

    def add(id, *commands, &block)
      if id && @operations_by_id.key?(id)
        @operations_by_id[id].skip = true
      end
      @operations << operation = Operation.new(id, commands, block)
      @operations_by_id[id] = operation
      flush if @auto_flush && @operations.length >= @auto_flush
    end
  end
end
