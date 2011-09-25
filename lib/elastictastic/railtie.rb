module Elastictastic
  class Railtie < Rails::Railtie
    initializer "elastictastic.configure_rails" do
      config_path = Rails.root.join('config/elastictastic.yml').to_s
      if File.exist?(config_path)
        yaml = YAML.load_file(config_path)[Rails.env]
        if yaml
          yaml.each_pair do |name, value|
            Elastictastic.config.__send__("#{name}=", value)
          end
        end
      end

      Elastictastic.config.logger = Rails.logger
    end
  end
end
