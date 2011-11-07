module Elastictastic
  module NestedDocument
    extend ActiveSupport::Concern

    included do
      include Properties
      include Dirty
      include Dirty::NestedDocumentMethods
      include MassAssignmentSecurity
    end

    module InstanceMethods
      attr_writer :nesting_document, :nesting_association

      def initialize_copy(original)
        self.write_attributes(original.read_attributes.dup)
      end
    end
  end
end
