module Elastictastic
  module Callbacks
    extend ActiveSupport::Concern

    HOOKS = [:save, :create, :update, :destroy]

    included do
      extend ActiveModel::Callbacks
      define_model_callbacks(*HOOKS)
    end

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
