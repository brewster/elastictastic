module Elastictastic
  module NestedDocument
    extend ActiveSupport::Concern

    included do
      include Properties
      include Dirty
      include Dirty::NestedDocumentMethods
      include MassAssignmentSecurity
      include Validations

      include ActiveModel::Serializers::JSON
      include ActiveModel::Serializers::Xml

      self.include_root_in_json = false
    end

    module InstanceMethods
      def initialize_copy(original)
        self.write_attributes(original.read_attributes.dup)
      end

      def attributes
        {}
      end

      def ==(other)
        other.nil? ? false : @attributes == other.read_attributes && @embeds == other.read_embeds
      end

      def eql?(other)
        self.class == other.class && self == other
      end
    end
  end
end
