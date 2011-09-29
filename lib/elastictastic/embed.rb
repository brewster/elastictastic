module Elastictastic
  class Embed
    attr_reader :name, :class_name

    def initialize(name, class_name = nil)
      @name, @class_name = name, class_name || name.to_s.classify
    end

    def clazz
      @clazz ||= @class_name.constantize
    end

    def properties
      { name => { 'properties' => clazz.properties }}
    end
  end
end
