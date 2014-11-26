module Elastictastic
  class Search
    KEYS = %w(query filter from size sort highlight fields script_fields
              preference facets _source)

    attr_reader :sort, :from, :size, :fields, :script_fields, :preference, :facets, :_source
    delegate :[], :to => :params

    def initialize(params = {})
      params = Util.deep_stringify(params) # this creates a copy
      @queries, @query_filters = extract_queries_and_query_filters(params['query'])
      @filters = extract_filters(params['filter'])
      @from = params.delete('from')
      @size = params.delete('size')
      @sort = Util.ensure_array(params.delete('sort'))
      highlight = params.delete('highlight')
      if highlight
        @highlight_fields = highlight.delete('fields')
        @highlight_settings = highlight
      end
      @fields = Util.ensure_array(params.delete('fields'))
      @script_fields = params.delete('script_fields')
      @preference = params.delete('preference')
      @facets = params.delete('facets')
      @_source = Util.ensure_array(params.delete('_source'))
    end

    def initialize_copy(other)
      @queries = deep_copy(other.queries)
      @query_filters = deep_copy(other.query_filters)
      @filters = deep_copy(other.filters)
      @sort = deep_copy(other.sort)
      @highlight = deep_copy(other.highlight)
      @fields = other.fields.dup if other.fields
      @script_fields = deep_copy(other.script_fields)
      @facets = deep_copy(other.facets)
      @_source = other._source.dup if other._source
    end

    def params
      {}.tap do |params|
        params['query'] = query
        params['filter'] = filter
        params['from'] = from
        params['size'] = size
        params['sort'] = maybe_array(sort)
        params['highlight'] = highlight
        params['fields'] = maybe_array(fields)
        params['script_fields'] = script_fields
        params['facets'] = facets
        params['_source'] = maybe_array(_source)
        params.reject! { |k, v| v.blank? }
      end
    end

    def query
      query_query = maybe_array(queries) do
        { 'bool' => { 'must' => queries }}
      end
      query_filter = maybe_array(query_filters) do
        { 'and' => query_filters }
      end
      if query_query
        if query_filter
          { 'filtered' => { 'query' => query_query, 'filter' => query_filter }}
        else
          query_query
        end
      elsif query_filter
        { 'constant_score' => { 'filter' => query_filter }}
      end
    end

    def filter
      maybe_array(filters) do
        { 'and' => filters }
      end
    end

    def highlight
      if @highlight_fields
        @highlight_settings.merge('fields' => @highlight_fields)
      end
    end

    def merge(other)
      dup.merge!(other)
    end

    def merge!(other)
      @queries = combine(@queries, other.queries)
      @query_filters = combine(@query_filters, other.query_filters)
      @filters = combine(@filters, other.filters)
      @from = other.from  || @from
      @size = other.size || @size
      @sort = combine(@sort, other.sort)
      if @highlight_fields && other.highlight_fields
        @highlight_fields = combine(highlight_fields_with_settings, other.highlight_fields_with_settings)
        @highlight_settings = {}
      else
        @highlight_settings = combine(@highlight_settings, other.highlight_settings)
        @highlight_fields = combine(@highlight_fields, other.highlight_fields)
      end
      @fields = combine(@fields, other.fields)
      @script_fields = combine(@script_fields, other.script_fields)
      @preference = other.preference || @preference
      @facets = combine(@facets, other.facets)
      @_source = combine(@_source, other._source)
      self
    end

    protected
    attr_reader :queries, :query_filters, :filters, :highlight_fields,
                :highlight_settings

    def highlight_fields_with_settings
      if @highlight_fields
        {}.tap do |fields_with_settings|
          @highlight_fields.each_pair do |field, settings|
            fields_with_settings[field] = @highlight_settings.merge(settings)
          end
        end
      end
    end

    private

    def maybe_array(array)
      case array.length
      when 0 then nil
      when 1 then array.first
      else
        if block_given? then yield
        else array
        end
      end
    end

    def combine(object1, object2)
      if object1.nil? then object2
      elsif object2.nil? then object1
      else 
        case object1
        when Array then object1 + object2
        when Hash then object1.merge(object2)
        else raise ArgumentError, "Don't know how to combine #{object1.inspect} with #{object2.inspect}"
        end
      end
    end

    def extract_queries_and_query_filters(params)
      if params.nil? then [[], []]
      elsif params.keys == %w(filtered)
        [extract_queries(params['filtered']['query']), extract_filters(params['filtered']['filter'])]
      elsif params.keys == %w(constant_score) && params['constant_score'].keys == %w(filter)
        [[], extract_filters(params['constant_score']['filter'])]
      else
        [extract_queries(params), []]
      end
    end

    def extract_queries(params)
      if params.nil? then []
      elsif params.keys == %w(bool) && params['bool'].keys == %w(must)
        params['bool']['must']
      else [params]
      end
    end

    def extract_filters(params)
      if params.nil? then []
      elsif params.keys == %w(and)
        params['and']
      else
        [params]
      end
    end

    def deep_copy(object)
      Marshal.load(Marshal.dump(object)) unless object.nil?
    end
  end
end
