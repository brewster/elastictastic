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
        instance.index,
        instance.id,
        { 'create' => bulk_identifier_for_instance(instance) },
        instance.elasticsearch_doc
      ) do |response|
        if response['create']['error']
          block.call(ServerError[response['create']['error']])
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
        instance.index,
        instance.id,
        { 'index' => bulk_identifier_for_instance(instance) },
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
      add(instance.index, instance.id, :delete => bulk_identifier_for_instance(instance)) do |response|
        if response['delete']['error']
          block.call(ServerError[response['delete']['error']])
        else
          instance.transient!
          instance.version = response['delete']['_version']
          block.call
        end
      end
    end

    def destroy!(index, type, id, routing, parent)
      add(
        index, id,
        :delete => bulk_identifier(index, type, id, routing, parent, nil)
      )
    end

    def flush
      return if @operations.empty?

      params = {}
      params[:refresh] = true if Elastictastic.config.auto_refresh
      io = StringIO.new
      operations = @operations.reject { |operation| operation.skip }
      @operations.clear

      operations.each do |operation|
        operation.commands.each do |command|
          io.puts Elastictastic.json_encode(command)
        end
      end
      response = Elastictastic.client.bulk(io.string, params)

      response['items'].each_with_index do |op_response, i|
        operation = operations[i]
        operation.handler.call(op_response) if operation.handler
      end
      response
    end

    private

    def bulk_identifier_for_instance(instance)
      bulk_identifier(
        instance.index,
        instance.class.type,
        instance.id,
        instance.class.route(instance),
        instance._parent_id,
        instance.version
      )
    end

    def bulk_identifier(index, type, id, routing, parent_id, version)
      identifier = { :_index => index.name, :_type => type }
      identifier['_id'] = id if id
      identifier['_version'] = version if version
      identifier['_routing'] = routing.to_s if routing
      identifier['parent'] = parent_id if parent_id
      identifier
    end

    def add(index, id, *commands, &block)
      document_id = [index.name, id]
      if id && @operations_by_id.key?(document_id)
        @operations_by_id[document_id].skip = true
      end
      @operations << operation = Operation.new(id, commands, block)
      @operations_by_id[document_id] = operation
      flush if @auto_flush && @operations.length >= @auto_flush
    end
  end
end
