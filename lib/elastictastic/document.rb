module Elastictastic
  module Document
    extend ActiveSupport::Concern

    included do
      include Elastictastic::Resource
      extend Elastictastic::Search # needs to go before Elastictastic::Persistence
      include Elastictastic::Persistence
      extend Elastictastic::Scoped
    end

    module ClassMethods
      delegate :scoped, :to => :in_default_index

      def new_from_elasticsearch_hit(response)
        allocate.tap do |instance|
          instance.instance_eval do
            initialize_from_elasticsearch_hit(response)
          end
        end
      end

      def mapping
        { type => { 'properties' => properties }}
      end

      def type
        name.underscore
      end

      def in_index(name_or_index)
        TypeInIndex.new(self, Elastictastic::Index(name_or_index))
      end

      private

      def in_default_index
        in_index(Index.default)
      end
    end

    module InstanceMethods
      attr_reader :id

      def initialize_from_elasticsearch_hit(response)
        @id = response['_id']
        @index = Index.new(response['_index'])
        persisted!

        doc = response['_source'] || Util.unflatten_hash(response['fields'] || {})

        initialize_from_elasticsearch_doc(doc)
      end

      def id=(id)
        assert_transient!
        @id = id
      end

      def index
        return @index if defined? @index
        @index = Index.default
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
