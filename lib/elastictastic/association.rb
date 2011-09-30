module Elastictastic
  class Association
    attr_reader :name, :options

    def initialize(name, options = {})
      @name, @options = name.to_s, options.symbolize_keys
    end

    def class_name
      @options[:class_name] || @name.to_s.classify
    end

    def clazz
      @clazz ||= class_name.constantize
    end
  end
end
