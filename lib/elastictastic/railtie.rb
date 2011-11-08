module Elastictastic
  class Railtie < Rails::Railtie
    config.elastictastic = Elastictastic.config

    initializer "elastictastic.configure_rails" do
      config_path = Rails.root.join('config/elastictastic.yml').to_s
      config = Elastictastic.config
      app_name = Rails.application.class.name.split('::').first.underscore
      config.default_index = "#{app_name}_#{Rails.env}"

      if File.exist?(config_path)
        yaml = YAML.load_file(config_path)[Rails.env]
        if yaml
          yaml.each_pair do |name, value|
            config.__send__("#{name}=", value)
          end
        end
      end

      Elastictastic.config.logger = Rails.logger

      require 'elastictastic/new_relic_instrumentation' if defined? NewRelic
    end

    initializer "elastictastic.instantiate_observers" do
      config.after_initialize do
        ::Elastictastic::Observing.instantiate_observers

        ActionDispatch::Callbacks.to_prepare do
          ::Elastictastic::Observing.instantiate_observers
        end
      end
    end
  end
end
