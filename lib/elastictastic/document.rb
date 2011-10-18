module Elastictastic
  module Document
    extend ActiveSupport::Concern

    included do
      include Elastictastic::Resource
      extend Elastictastic::Search # needs to go before Elastictastic::Persistence
      extend Elastictastic::Scoped
    end

    module ClassMethods
      delegate :find, :destroy_all, :sync_mapping, :inspect, :to => :default_scope

      def new(*args)
        allocate.tap do |instance|
          index = current_scope ? current_scope.index : default_scope.index
          instance.instance_eval do
            @index = index
            initialize(*args)
          end
        end
      end

      def new_from_elasticsearch_hit(hit)
        allocate.tap do |instance|
          instance.instance_eval do
            initialize_from_elasticsearch_hit(hit)
          end
        end
      end

      def new_from_elasticsearch_hits(hits)
        [].tap do |docs|
          hits.each do |hit|
            docs << new_from_elasticsearch_hit(hit) unless hit['exists'] == false
          end
        end
      end

      def mapping
        { type => { 'properties' => properties }}.tap do |mapping|
          mapping[type]['_parent'] = { 'type' => @parent.clazz.type } if @parent
        end
      end

      def type
        name.underscore
      end

      def in_index(name_or_index)
        Scope.new(Elastictastic::Index(name_or_index), self, {})
      end

      def scoped(params)
        (current_scope || default_scope).scoped(params)
      end

      def belongs_to(parent_name, options = {})
        @parent = Association.new(parent_name, options)

        module_eval(<<-RUBY, __FILE__, __LINE__+1)
          def #{parent_name}
            @_parent
          end

          def #{parent_name}=(parent)
            @_parent = parent
          end
        RUBY
      end

      private

      def default_scope
        in_index(Index.default)
      end
    end

    module InstanceMethods
      attr_reader :id
      attr_accessor :_parent #:nodoc:

      def initialize_from_elasticsearch_hit(response)
        @id = response['_id']
        @index = Index.new(response['_index'])
        persisted!

        doc = response['_source']
        doc ||=
          begin
            fields = response['fields']
            if fields
              Util.unflatten_hash(fields.reject { |k, v| v.nil? })
            end
          end

        if doc
          if doc.has_key?('_source')
            doc.merge!(doc.delete('_source'))
          end
          initialize_from_elasticsearch_doc(doc)
        end
      end

      def id=(id)
        assert_transient!
        @id = id
      end

      def index
        return @index if defined? @index
        @index = Index.default
      end

      def save
        if persisted?
          Elastictastic.persister.update(self)
        else
          Elastictastic.persister.create(self)
        end
      end
      
      def destroy
        if persisted?
          Elastictastic.persister.destroy(self)
        else
          raise OperationNotAllowed, "Cannot destroy transient document: #{inspect}"
        end
      end

      def persisted?
        !!@persisted
      end

      def transient?
        !persisted?
      end

      def persisted!
        @persisted = true
      end

      def transient!
        @persisted = false
      end

      def ==(other)
        index == other.index && id == other.id
      end

      private

      def assert_transient!
        if persisted?
          raise IllegalModificationError,
            "Cannot modify identity attribute after model has been saved."
        end
      end
    end
  end
end
