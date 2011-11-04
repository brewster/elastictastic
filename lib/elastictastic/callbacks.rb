module Elastictastic
  module Callbacks
    extend ActiveSupport::Concern

    included do
      extend ActiveModel::Callbacks
      define_model_callbacks :save, :create, :update, :destroy
    end

    module ClassMethods
    end

    module InstanceMethods
      def save
        run_callbacks(:save) { super }
      end

      def create
        run_callbacks(:create) { super }
      end

      def update
        run_callbacks(:update) { super }
      end

      def destroy
        run_callbacks(:destroy) { super }
      end
    end
  end
end
