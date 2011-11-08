module Elastictastic
  module Validations
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Validations
    end

    module ClassMethods
      def embed(*embed_names)
        super
        args = embed_names + [{ :nested => true }]
        validates(*args)
      end
    end

    module InstanceMethods
      def save
        if valid?
          super
          true
        else
          false
        end
      end

      def save!
        if !save
          raise Elastictastic::RecordInvalid, errors.full_messages.to_sentence
        end
        self
      end
    end

    class NestedValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        value = [value].compact unless Array === value
        unless value.all? { |el| el.valid? }
          record.errors[:attribute] = :invalid
        end
      end
    end
  end
end
