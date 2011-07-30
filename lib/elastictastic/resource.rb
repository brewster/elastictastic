module Elastictastic
  module Resource
    extend ActiveSupport::Concern

    module ClassMethods
      def new_from_elasticsearch_doc(doc)
        allocate.tap do |instance|
          instance.instance_eval { initialize_from_elasticsearch_doc(doc) }
        end
      end

      def each_field
        properties.each_pair do |field, properties|
          if properties['properties']
            embeds[field].each_field do |embed_field, embed_properties|
              yield("#{field}.#{embed_field}", embed_properties)
            end
          elsif properties['fields']
            properties['fields'].each_pair do |variant_field, variant_properties|
              if variant_field == field
                yield(field, variant_properties)
              else
                yield("#{field}.#{variant_field}", variant_properties)
              end
            end
          else
            yield field, properties
          end
        end
      end

      def select_fields
        [].tap do |fields|
          each_field do |field, properties|
            fields << [field, properties] if yield(field, properties)
          end
        end
      end

      def all_fields
        @all_fields ||= {}.tap do |fields|
          each_field { |field, properties| fields[field] = properties }
        end
      end

      def properties
        @properties ||= {}
      end

      def properties_for_field(field_name)
        properties[field_name.to_s]
      end

      def embeds
        @embeds ||= {}
      end

      def field(*field_names, &block)
        options = field_names.extract_options!

        field_names.each do |field_name|
          attr_accessor(field_name)

          properties[field_name.to_s] =
            Field.process(field_name, options, &block)
        end
      end

      def embed(*embed_names)
        clazz = embed_names.pop

        embed_names.each do |embed_name|
          attr_reader(embed_name)
          module_eval <<-RUBY
            def #{embed_name}=(value)
              Util.call_or_each(value) do |check_value|
                unless check_value.nil? || check_value.is_a?(#{clazz.name})
                  raise TypeError, "Expected instance of class #{clazz.name}; got \#{check_value.inspect}"
                end
              end
              @#{embed_name} = value
            end
          RUBY

          embed_name = embed_name.to_s

          properties[embed_name] = {
            'properties' => clazz.properties
          }
          embeds[embed_name] = clazz
        end
      end
    end

    module InstanceMethods
      def to_elasticsearch_doc
        {}.tap do |doc|
          self.class.properties.each_pair do |field_name, options|
            value = __send__(field_name)
            next if value.nil?
            doc[field_name] =
              Util.call_or_map(value) { |item| serialize_value(field_name, item) }
          end
        end
      end

      def valid? #XXX temporary for RABL compatibility
        true
      end

      def ==(other)
        to_elasticsearch_doc == other.to_elasticsearch_doc
      end

      private

      def initialize_from_elasticsearch_doc(doc)
        return if doc.nil?
        doc.each_pair do |field_name, value|
          deserialized = Util.call_or_map(value) { |item| deserialize_value(field_name, item) }
          instance_variable_set(:"@#{field_name}", deserialized)
        end
      end

      def serialize_value(field_name, value)
        if value.respond_to?(:to_elasticsearch_doc)
          value.to_elasticsearch_doc
        else
          type = self.class.properties_for_field(field_name)['type'].to_s
          case type
          when 'date'
            value.to_time.utc.xmlschema
          when 'integer', 'byte', 'short', 'long'
            value.to_i
          when 'float', 'double'
            value.to_f
          when 'boolean'
            !!value
          else
            value.to_s
          end
        end
      end

      def deserialize_value(field_name, value)
        return nil if value.nil?
        embed_class = self.class.embeds[field_name]
        if embed_class
          embed_class.new_from_elasticsearch_doc(value)
        elsif self.class.properties_for_field(field_name)['type'].to_s == 'date'
          Time.xmlschema(value)
        else
          value
        end
      end
    end
  end
end
