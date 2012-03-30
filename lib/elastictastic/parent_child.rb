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
        @_child_associations ||= {}
      end

      def mapping
        super.tap do |mapping|
          mapping[type]['_parent'] = { 'type' => @parent_association.clazz.type } if @parent_association
        end
      end
    end


    def initialize(attributes = {})
      super
      @_children = Hash.new do |hash, child_association_name|
        hash[child_association_name] = Elastictastic::ChildCollectionProxy.new(
          self.class.child_association(child_association_name.to_s),
          self
        )
      end
    end

    def elasticsearch_doc=(doc)
      @_parent_id = doc.delete('_parent')
      super
    end

    def _parent #:nodoc:
      return @_parent if defined? @_parent
      @_parent =
        if @_parent_id
          self.class.parent_association.clazz.in_index(index).find(@_parent_id)
        end
      #TODO - here's a piece of debugging to fix a problem where we get weird parents. remove after fixing
      if @_parent && !@_parent.respond_to?(:id)
        raise ArgumentError.new("Bad parent loaded from id #{@_parent_id} is a #{@_parent.class.name}.")
      end
      @_parent
    end

    def _parent_id #:nodoc:
      if @_parent_id
        @_parent_id
      elsif @_parent
        @_parent_id = @_parent.id
      end
    end

    def parent=(parent)
      if @_parent
        raise Elastictastic::IllegalModificationError,
          "Document is already a child of #{_parent}"
      end
      if persisted?
        raise Elastictastic::IllegalModificationError,
          "Can't change parent of persisted object"
      end
      #TODO - here's a piece of debugging to fix a problem where we get weird parents. remove after fixing
      if parent && !parent.respond_to?(:id)
        raise ArgumentError.new("Bad parent loaded from id #{parent_id} is a #{parent.class.name}.")
      end
      @_parent = parent
    end

    def save(options = {})
      super
      self.class.child_associations.each_pair do |name, association|
        association.extract(self).transient_children.each do |child|
          child.save unless child.pending_save?
        end
      end
    end

    protected

    def read_child(field_name)
      @_children[field_name.to_s]
    end

  end
end
