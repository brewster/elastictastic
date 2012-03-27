module Elastictastic
  module Dirty
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Dirty
    end

    module ClassMethods
      def define_field(field_name, options, &block)
        super
        define_dirty_accessors(field_name)
      end

      def define_embed(embed_name, options)
        super
        define_dirty_accessors(embed_name)
      end

      private

      # 
      # We have to rewrite ActiveModel functionality here because in Rails 3.0,
      # #define_attribute_methods has to be called exactly one time, and there's
      # no place for us to do that. This appears to be fixed in ActiveModel 3.1
      #
      def define_dirty_accessors(attribute)
        attribute = attribute.to_s
        module_eval <<-RUBY, __FILE__, __LINE__+1
          def #{attribute}_changed?
            attribute_changed?(#{attribute.inspect})
          end

          def #{attribute}_change
            attribute_change(#{attribute.inspect})
          end

          def #{attribute}_will_change!
            attribute_will_change!(#{attribute.inspect})
          end

          def #{attribute}_was
            attribute_was(#{attribute.inspect})
          end

          def reset_#{attribute}!
            reset_attribute!(#{attribute})
          end
        RUBY
      end
    end

    def write_attribute(field, value)
      attribute_may_change!(field) { super }
    end

    def write_embed(field, value)
      attribute_may_change!(field) do
        if Array === value
          value.each do |el|
            el.nesting_document = self
            el.nesting_association = field
          end
          super(field, NestedCollectionProxy.new(self, field, value))
        elsif value
          value.nesting_document = self
          value.nesting_association = field
          super
        else
          super
        end
      end
    end

    def save(options = {})
      super
      clean_attributes!
    end

    def elasticsearch_doc=(doc)
      super
      clean_attributes!
    end

    protected

    def clean_attributes!
      changed_attributes.clear
      @embeds.each_pair do |name, embedded|
        Util.call_or_map(embedded) { |doc| doc && doc.clean_attributes! }
      end
    end

    def attribute_may_change!(field)
      attribute_will_change!(field) unless changed_attributes.key?(field)
      old_value = changed_attributes[field]
      yield
      attribute_not_changed!(field) if old_value == __send__(field)
    end

    def attribute_not_changed!(field)
      changed_attributes.delete(field)
    end

    module EmbeddedDocumentMethods
      attr_writer :nesting_document, :nesting_association

      def attribute_may_change!(field)
        if @nesting_document
          @nesting_document.attribute_may_change!(@nesting_association) do
            super
          end
        else
          super
        end
      end
    end

    class NestedCollectionProxy < Array
      def initialize(owner, embed_name, collection = [])
        @owner, @embed_name = owner, embed_name
        super(collection)
      end

      [
        :<<, :[]=, :collect!, :compact!, :delete, :delete_at, :delete_if,
        :flatten!, :insert, :keep_if, :map!, :push, :reject!, :replace,
        :reverse!, :rotate!, :select!, :shuffle!, :slice!, :sort!, :sort_by!,
        :uniq!
      ].each do |destructive_method|
        module_eval <<-RUBY, __FILE__, __LINE__+1
          def #{destructive_method}(*args)
            @owner.__send__(:attribute_may_change!, @embed_name) do
              super
            end
          end
        RUBY
      end

      def clone
        NestedCollectionProxy.new(@owner, @embed_name, map { |el| el.clone })
      end
    end
  end
end
