module Elastictastic
  module Dirty
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Dirty
    end

    module ClassMethods
      def define_field(field_name, options, &block)
        super
        define_attribute_methods([field_name])
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
  end
end
