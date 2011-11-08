module Elastictastic
  module NestedDocument
    extend ActiveSupport::Concern

    included do
      include Properties
      include Dirty
      include Dirty::NestedDocumentMethods
      include MassAssignmentSecurity
      include Validations
    end

    module InstanceMethods
      def initialize_copy(original)
        self.write_attributes(original.read_attributes.dup)
      end

      def inspect
        inspected = "#<#{self.class.name}"
        if attributes.any?
          inspected << ' ' << attributes.each_pair.map do |attr, value|
            "#{attr}: #{value.inspect}"
          end.join(', ')
        end
        inspected << '>'
      end
    end
  end
end
