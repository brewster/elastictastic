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
    end

    module InstanceMethods
      attr_reader :id

      def initialize_from_elasticsearch_response(response)
        @id = response['_id']
        @index = response['_index']

        doc = response['_source'] || Util.unflatten_hash(response['fields'] || {})

        initialize_from_elasticsearch_doc(doc)
      end

      def id=(id)
        assert_transient!
        @id = id
      end

      def index=(index)
        assert_transient!
        @index = index
      end

      def index
        return @index if defined? @index
        @index = Elastictastic.config.default_index
      end

      def persisted?
        !!@persisted
      end

      def transient?
        !persisted?
      end

      def persisted!
        @persisted = true
      end

      def transient!
        @persisted = false
      end

      def ==(other)
        index == other.index && id == other.id
      end

      private

      def assert_transient!
        if persisted?
          raise IllegalModificationError,
            "Cannot modify identity attribute after model has been saved."
        end
      end
    end
  end
end
