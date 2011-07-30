module Elastictastic
  module Document
    extend ActiveSupport::Concern

    included do
      include Elastictastic::Resource
      include Elastictastic::Persistence
      extend Elastictastic::Scoped
      extend Elastictastic::Search
    end

    module ClassMethods
      def new_from_elasticsearch_response(response)
        allocate.tap do |instance|
          instance.instance_eval do
            initialize_from_elasticsearch_response(response)
          end
        end
      end

      def mapping
        { type => { 'properties' => properties }}
      end

      def type
        name.underscore
      end

      def default_index
        type.pluralize
      end
    end

    module InstanceMethods
      attr_reader :id
      attr_writer :index

      def initialize_from_elasticsearch_response(response)
        @id = response['_id']
        @index = response['_index']

        doc = response['_source'] || Util.unflatten_hash(response['fields'] || {})

        initialize_from_elasticsearch_doc(doc)
      end

      def index
        return @index if defined? @index
        self.class.default_index
      end

      def ==(other)
        index == other.index && id == other.id
      end
    end
  end
end
