module Elastictastic
  module Document
    extend ActiveSupport::Concern

    included do
      extend Scoped
      include Properties
      include Persistence
      include ParentChild
      include Callbacks
      include Observing
      include Dirty
      include MassAssignmentSecurity

      extend ActiveModel::Naming
      include ActiveModel::Conversion
      include ActiveModel::Validations
    end

    module ClassMethods
      delegate :find, :destroy_all, :sync_mapping, :inspect, :find_each,
               :find_in_batches, :first, :count, :empty?, :any?, :all,
               :query, :filter, :from, :size, :sort, :highlight, :fields,
               :script_fields, :preference, :facets, :to => :current_scope

      def mapping
        { type => { 'properties' => properties }}
      end

      def type
        name.underscore
      end

      def in_index(name_or_index)
        Scope.new(Elastictastic::Index(name_or_index), self)
      end

      def scoped(params)
        current_scope.scoped(params)
      end

      private

      def default_scope
        in_index(Index.default)
      end
    end

    module InstanceMethods
      attr_reader :id

      def initialize(attributes = {})
        self.class.current_scope.initialize_instance(self)
      end

      def elasticsearch_hit=(hit) #:nodoc:
        @id = hit['_id']
        @index = Index.new(hit['_index'])
        persisted!

        doc = {}
        doc.merge!(hit['_source']) if hit['_source']
        fields = hit['fields']
        if fields
          unflattened_fields =
            Util.unflatten_hash(fields.reject { |k, v| v.nil? })
          if unflattened_fields.has_key?('_source')
            doc.merge!(unflattened_fields.delete('_source'))
          end
          doc.merge!(unflattened_fields)
        end
        self.elasticsearch_doc=(doc)
      end

      def id=(id)
        assert_transient!
        @id = id
      end

      def index
        return @index if defined? @index
        @index = Index.default
      end

      def ==(other)
        index == other.index && id == other.id
      end
    end
  end
end
