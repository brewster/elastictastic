module Elastictastic
  class Field < BasicObject
    private_class_method :new

    def self.process(field_name, default_options, &block)
      {}.tap do |properties|
        new(field_name, default_options, properties, &block)
      end
    end

    def self.with_defaults(options)
      options = Util.deep_stringify(options)
      if preset = options.delete('preset')
        options = ::Elastictastic.config.presets[preset].merge(options)
      end
      { 'type' => 'string' }.merge(options).tap do |field_properties|
        if field_properties['type'].to_s == 'date'
          field_properties['format'] = 'date_time_no_millis'
        end
      end
    end

    def initialize(field_name, default_options, properties, &block)
      @field_name = field_name
      @properties = properties
      @properties.merge!(Field.with_defaults(default_options))
      if block
        @properties['fields'] = {}
        instance_eval(&block)
      end
    end

    def field(field_name, options = {})
      @properties['fields'][field_name.to_s] =
        Field.with_defaults(options)
    end
  end
end
