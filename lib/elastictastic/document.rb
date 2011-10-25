module Elastictastic
  module Document
    extend ActiveSupport::Concern

    included do
      include Elastictastic::Resource
      extend Elastictastic::Scoped
    end

    module ClassMethods
      attr_reader :parent_association

      delegate :find, :destroy_all, :sync_mapping, :inspect, :find_each,
               :find_in_batches, :first, :count, :empty?, :any?, :all,
               :query, :filter, :from, :size, :sort, :highlight, :fields,
               :script_fields, :preference, :facets, :to => :current_scope

      def new(*args)
        allocate.tap do |instance|
          current_scope.initialize_instance(instance)
          instance.instance_eval { initialize(*args) }
        end
      end

      def new_from_elasticsearch_hit(hit)
        allocate.tap do |instance|
          instance.instance_eval do
            initialize_from_elasticsearch_hit(hit)
          end
        end
      end

      def mapping
        { type => { 'properties' => properties }}.tap do |mapping|
          mapping[type]['_parent'] = { 'type' => @parent_association.clazz.type } if @parent_association
        end
      end

      def type
        name.underscore
      end

      def in_index(name_or_index)
        Scope.new(Elastictastic::Index(name_or_index), self)
      end

      def scoped(params)
        current_scope.scoped(params)
      end

      def belongs_to(parent_name, options = {})
        @parent_association = Association.new(parent_name, options)

        module_eval(<<-RUBY, __FILE__, __LINE__+1)
          def #{parent_name}
            _parent
          end
        RUBY
      end

      def has_many(children_name, options = {})
        children_name = children_name.to_s
        child_associations[children_name] = Association.new(children_name, options)

        module_eval(<<-RUBY, __FILE__, __LINE__ + 1)
          def #{children_name}
            @#{children_name} ||= Elastictastic::ChildCollectionProxy.new(
              self.class.child_association(#{children_name.inspect}),
              self
            )
          end
        RUBY
      end

      def child_association(name)
        child_associations[name.to_s]
      end

      def child_associations
        @child_associations ||= {}
      end

      private

      def default_scope
        in_index(Index.default)
      end
    end

    module InstanceMethods
      attr_reader :id

      def initialize_from_elasticsearch_hit(response)
        @id = response['_id']
        @index = Index.new(response['_index'])
        persisted!

        doc = {}
        doc.merge!(response['_source']) if response['_source']
        fields = response['fields']
        if fields
          unflattened_fields =
            Util.unflatten_hash(fields.reject { |k, v| v.nil? })
          if unflattened_fields.has_key?('_source')
            doc.merge!(unflattened_fields.delete('_source'))
          end
          doc.merge!(unflattened_fields)
        end
        initialize_from_elasticsearch_doc(doc)
      end

      def id=(id)
        assert_transient!
        @id = id
      end

      def index
        return @index if defined? @index
        @index = Index.default
      end

      def _parent #:nodoc:
        return @_parent if defined? @_parent
        @_parent =
          if @_parent_collection
            @_parent_collection.parent
          elsif @_parent_id
            self.class.parent_association.clazz.find(@_parent_id)
          end
      end

      def _parent_id #:nodoc:
        if @_parent_collection
          @_parent_collection.parent.id
        elsif @_parent_id
          @_parent_id
        end
      end

      def _parent_collection=(parent_collection)
        if @_parent_collection
          raise Elastictastic::IllegalModificationError,
            "Document is already a child of #{_parent}"
        end
        if persisted?
          raise Elastictastic::IllegalModificationError,
            "Can't change parent of persisted object"
        end
        @_parent_collection = parent_collection
      end

      def save
        if persisted?
          Elastictastic.persister.update(self)
        else
          Elastictastic.persister.create(self)
        end
        self.class.child_associations.each_pair do |name, association|
          association.extract(self).transient_children.each do |child|
            child.save unless child.pending_save?
          end
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

      def pending_save?
        !!@pending_save
      end

      def pending_destroy?
        !!@pending_destroy
      end

      def persisted!
        was_persisted = @persisted
        @persisted = true
        @pending_save = false
        if @_parent_collection && !was_persisted
          @_parent_collection.persisted!(self)
        end
      end

      def transient!
        @persisted = @pending_destroy = false
      end

      def pending_save!
        @pending_save = true
      end

      def pending_destroy!
        @pending_destroy = true
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
