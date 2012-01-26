module Elastictastic
  module BasicDocument
    extend ActiveSupport::Concern

    included do
      extend Scoped
      include Properties
      include Persistence
      include OptimisticLocking
      include ParentChild

      extend ActiveModel::Naming
      include ActiveModel::Conversion
      include ActiveModel::Serializers::JSON
      include ActiveModel::Serializers::Xml

      self.include_root_in_json = false
    end

    module ClassMethods
      delegate :find, :destroy_all, :sync_mapping, :inspect, :find_each,
               :find_in_batches, :first, :count, :empty?, :any?, :all,
               :query, :filter, :from, :size, :sort, :highlight, :fields,
               :script_fields, :preference, :facets, :to => :current_scope

      def mapping
        mapping_for_type = { 'properties' => properties }
        mapping_for_type['_boost'] = @boost if @boost
        { type => mapping_for_type }
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

    attr_reader :id
    attr_accessor :version

    def initialize(attributes = {})
      self.class.current_scope.initialize_instance(self)
    end

    def reload
      params = {}
      params['routing'] = @parent_id if @parent_id
      self.elasticsearch_hit =
        Elastictastic.client.get(index, self.class.type, id, params)
    end

    def elasticsearch_hit=(hit) #:nodoc:
      @id = hit['_id']
      @index = Index.new(hit['_index'])
      @version = hit['_version']
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

    def attributes
      { :id => id, :index => index.name }
    end

    def inspect
      inspected = "#<#{self.class.name} id: #{id}, index: #{index.name}"
      attributes.each_pair do |attr, value|
        inspected << ", #{attr}: #{value.inspect}"
      end
      embeds.each_pair do |attr, value|
        inspected << ", #{attr}: #{value.inspect}"
      end
      inspected << ">"
    end
  end
end
