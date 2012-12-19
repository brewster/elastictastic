module Elastictastic
  #
  # The top-level module mixed in to classes which will be mapped as
  # ElasticSearch documents. Note that most people will want to use the Document
  # mixin, which extends BasicDocument with ActiveModel functionality such as
  # validations, lifecycle hooks, observers, mass-assignment security, etc. The
  # BasicDocument module is exposed directly for those who wish to avoid the
  # performance penalty associated with ActiveModel functionality, or those who
  # wish to only mix in the ActiveModel modules they need.
  #
  # Most of the functionality for BasicDocument is provided by submodules; see
  # below.
  #
  # @see Document
  # @see Scoped
  # @see Properties
  # @see Persistence
  # @see OptimisticLocking
  # @see ParentChild
  #
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
      #
      # Retrieve one or more documents by ID.
      #
      # @param (see Elastictastic::Scope#find)
      # @overload (see Elastictastic::Scope#find)
      #

      #
      # @method destroy_all
      #
      # Destroy all instances of this class in the default index
      #

      #
      # @method sync_mapping
      #
      # Push the mapping defined in this class to ElasticSearch. Be sure to do
      # this before saving instances of your class, or after making changes to
      # the class's mapping (e.g. adding fields)
      #

      #
      # @method find_each(batch_options = {}) {|document, hit| ... }
      #
      # Iterate over all documents in the default index, retrieving documents
      # in batches using a cursor, but yielding them one by one.
      #
      # @param (see Elastictastic::Scope#find_each)
      # @option (see Elastictastic::Scope#find_each)
      # @yield (see Elastictastic::Scope#find_each)
      # @yieldparam (see Elastictastic::Scope#find_each)
      # @return (see Elastictastic::Scope#find_each)
      #

      #
      # @method find_in_batches(batch_options = {}) {|batch| ... }
      #
      # Retrieve all documents in the default index, yielding them in batches.
      #
      # @param (see Elastictastic::Scope#find_in_batches)
      # @option (see Elastictastic::Scope#find_in_batches)
      # @yield (see Elastictastic::Scope#find_in_batches)
      # @yieldparam (see Elastictastic::Scope#find_in_batches)
      # @return (see Elastictastic::Scope#find_in_batches)
      #

      #
      # @method first
      #
      # @return [Document] The "first" document in the index ("first" is
      #   undefined).
      #

      #
      # @method count
      #
      # @return [Fixnum] The number of documents of this type in the default index.
      #

      #
      # @method empty?
      #
      # @return [TrueClass,FalseClass] True if there are no documents of this
      #   type in the default index.
      #

      #
      # @method any?
      #
      # @return [TrueClass,FalseClass] True if there are documents of this type
      #   in the default index.
      #

      delegate :find, :destroy, :destroy_all, :sync_mapping, :inspect,
               :find_each, :find_in_batches, :first, :count, :empty?, :any?,
               :all, :query, :filter, :from, :size, :sort, :highlight, :fields,
               :script_fields, :preference, :facets, :routing,
               :to => :current_scope

      attr_writer :default_index

      def mapping
        mapping_for_type = { 'properties' => properties }
        mapping_for_type['_boost'] = @_boost if @_boost
        if @_routing_field
          mapping_for_type['_routing'] = {
            'path' => @_routing_field.to_s,
            'required' => @_routing_required
          }
        end
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
        in_index(default_index)
      end

      def default_index
        @default_index || Index.default
      end
    end

    attr_reader :id
    attr_accessor :version

    def initialize(attributes = {})
      self.class.current_scope.initialize_instance(self)
    end

    def reload
      params = {}
      params['routing'] = @_parent_id if @_parent_id
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
      index == other.index && self.class == other.class && id == other.id
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
