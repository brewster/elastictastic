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

      def new_from_elasticsearch_hit(hit)
        allocate.tap do |instance|
          instance.instance_eval do
            initialize_from_elasticsearch_hit(hit)
          end
        end
      end

      def new_from_elasticsearch_hits(hits)
        [].tap do |docs|
          hits.each do |hit|
            docs << new_from_elasticsearch_hit(hit) unless hit['exists'] == false
          end
        end
      end

      def mapping
        { type => { 'properties' => properties }}.tap do |mapping|
          mapping[type]['_parent'] = { 'type' => @parent.clazz.type } if @parent
        end
      end

      def type
        name.underscore
      end

      def in_index(name_or_index)
        TypeInIndex.new(self, Elastictastic::Index(name_or_index))
      end

      def belongs_to(parent_name, options = {})
        @parent = Association.new(parent_name, options)

        module_eval(<<-RUBY, __FILE__, __LINE__+1)
          def #{parent_name}
            @_parent
          end

          def #{parent_name}=(parent)
            @_parent = parent
          end
        RUBY
      end

      private

      def in_default_index
        in_index(Index.default)
      end
    end

    module InstanceMethods
      attr_reader :id
      attr_accessor :_parent #:nodoc:

      def initialize_from_elasticsearch_hit(response)
        @id = response['_id']
        @index = Index.new(response['_index'])
        persisted!

        doc = response['_source']
        doc ||=
          begin
            fields = response['fields']
            if fields
              Util.unflatten_hash(fields.reject { |k, v| v.nil? })
            end
          end

        if doc
          if doc.has_key?('_source')
            doc.merge!(doc.delete('_source'))
          end
          initialize_from_elasticsearch_doc(doc)
        end
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
