module Elastictastic
  module Callbacks
    extend ActiveSupport::Concern

    HOOKS = [:save, :create, :update, :destroy]

    included do
      extend ActiveModel::Callbacks
      define_model_callbacks(*HOOKS)
    end

    def save(options = {})
      with_callbacks(:save, options) { super }
    end

    def create(options = {})
      with_callbacks(:create, options) { super }
    end

    def update(options = {})
      with_callbacks(:update, options) { super }
    end

    def destroy(options = {})
      with_callbacks(:destroy, options) { super }
    end

    private

    def with_callbacks(name, options)
      if options[:callbacks] == false then yield
      else run_callbacks(name) { yield }
      end
    end
  end
end
