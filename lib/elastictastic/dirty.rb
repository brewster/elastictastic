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

    module InstanceMethods
      def write_attribute(field, value)
        attribute_will_change!(field)
        super
      end

      def save
        super
        changed_attributes.clear
      end
    end

    module NestedDocumentMethods
      def attribute_will_change!(field)
        super
        if @nesting_document
          @nesting_document.__send__("attribute_will_change!", @nesting_association.name)
        end
      end
    end
  end
end
