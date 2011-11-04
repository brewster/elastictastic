module Elastictastic
  module Document
    extend ActiveSupport::Concern

    included do
      extend Elastictastic::Scoped
      include Elastictastic::Persistence
    end

    module ClassMethods
      include Elastictastic::Resource::ClassMethods

      attr_reader :parent_association

      delegate :find, :destroy_all, :sync_mapping, :inspect, :find_each,
               :find_in_batches, :first, :count, :empty?, :any?, :all,
               :query, :filter, :from, :size, :sort, :highlight, :fields,
               :script_fields, :preference, :facets, :to => :current_scope

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
            read_child(#{children_name.inspect})
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
      include Elastictastic::Resource::InstanceMethods

      attr_reader :id

      def initialize
        self.class.current_scope.initialize_instance(self)
        super
        @children = Hash.new do |hash, child_association_name|
          hash[child_association_name] = Elastictastic::ChildCollectionProxy.new(
            self.class.child_association(child_association_name.to_s),
            self
          )
        end
      end

      def elasticsearch_hit=(hit) #:nodoc:
        @id = hit['_id']
        @index = Index.new(hit['_index'])
        persisted!

        doc = {}
        doc.merge!(hit['_source']) if hit['_source']
        fields = hit['fields']
        if fields
          unflattened_fields =
            Util.unflatten_hash(fields.reject { |k, v| v.nil? })
          if unflattened_fields.has_key?('_source')
            doc.merge!(unflattened_fields.delete('_source'))
          end
          doc.merge!(unflattened_fields)
        end
        self.elasticsearch_doc=(doc)
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

      def read_child(field_name)
        @children[field_name.to_s]
      end

      def ==(other)
        index == other.index && id == other.id
      end
    end
  end
end
