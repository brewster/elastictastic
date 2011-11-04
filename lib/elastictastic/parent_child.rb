module Elastictastic
  module ParentChild
    extend ActiveSupport::Concern

    module ClassMethods
      attr_reader :parent_association

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

      def mapping
        super.tap do |mapping|
          mapping[type]['_parent'] = { 'type' => @parent_association.clazz.type } if @parent_association
        end
      end
    end

    module InstanceMethods

      def initialize(attributes = {})
        super
        @children = Hash.new do |hash, child_association_name|
          hash[child_association_name] = Elastictastic::ChildCollectionProxy.new(
            self.class.child_association(child_association_name.to_s),
            self
          )
        end
      end

      def elasticsearch_doc=(doc)
        @parent_id = doc.delete('_parent')
        super
      end

      def _parent #:nodoc:
        return @parent if defined? @parent
        @parent =
          if @parent_id
            self.class.parent_association.clazz.find(@parent_id)
          end
      end

      def _parent_id #:nodoc:
        if @parent
          @parent_id = @parent.id
        elsif @parent_id
          @parent_id
        end
      end

      def parent_collection=(parent_collection)
        if @parent_collection
          raise Elastictastic::IllegalModificationError,
            "Document is already a child of #{_parent}"
        end
        if persisted?
          raise Elastictastic::IllegalModificationError,
            "Can't change parent of persisted object"
        end
        @parent_collection = parent_collection
        @parent = parent_collection.parent
      end

      def save
        super
        self.class.child_associations.each_pair do |name, association|
          association.extract(self).transient_children.each do |child|
            child.save unless child.pending_save?
          end
        end
      end

      def persisted!
        was_persisted = @persisted
        super
        if @parent_collection && !was_persisted
          @parent_collection.persisted!(self)
        end
      end

      protected

      def read_child(field_name)
        @children[field_name.to_s]
      end

    end
  end
end
