module Elastictastic
  module Callbacks
    extend ActiveSupport::Concern

    HOOKS = [:save, :create, :update, :destroy, :validation]

    included do
      extend ActiveModel::Callbacks
      define_model_callbacks(*(HOOKS - [:validation]))
      define_callbacks :validation, terminator: 'result == false', scope: [:kind, :name]
    end

    module ClassMethods
      def before_validation(*args, &block)
        options = args.last
        if options.is_a?(Hash) && options[:on]
          options[:if] = Array(options[:if])
          options[:if] << "@_on_validate == :#{options[:on]}"
        end
        set_callback(:validation, :before, *args, &block)
      end

      def after_validation(*args, &block)
        options = args.extract_options!
        options[:prepend] = true
        options[:if] = Array(options[:if])
        options[:if] << "!halted && value != false"
        options[:if] << "@_on_validate == :#{options[:on]}" if options[:on]
        set_callback(:validation, :after, *(args << options), &block)
      end
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

    def valid?(*args, &block)
      @_on_validate = new? ? :create : :update
      run_callbacks(:validation) { super }
    end

    def with_callbacks(name, options)
      if options[:callbacks] == false then yield
      else run_callbacks(name) { yield }
      end
    end
  end
end
