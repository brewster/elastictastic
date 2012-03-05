module Elastictastic
  module Observing
    extend ActiveSupport::Concern
    extend ActiveModel::Observing::ClassMethods

    included do
      include ActiveModel::Observing
    end

    Callbacks::HOOKS.each do |method|
      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{method}(options = {})
          if options[:observers] == false
            super
          else
            notify_observers(:before_#{method})
            super.tap { notify_observers(:after_#{method}) }
          end
        end
      RUBY
    end
  end
end
