require 'hashie'

module Elastictastic
  class Scope < BasicObject
    include ::Enumerable
    include Search

    attr_reader :params

    def initialize(type_in_index, params)
      @type_in_index, @params = type_in_index, Util.deep_stringify(params)
    end

    def each(&block)
      find_each(&block)
    end

    def find_each(batch_options = {}, &block)
      find_in_batches(batch_options) do |batch|
        batch.each(&block)
      end
    end

    def find_in_batches(batch_options = {}, &block)
      if params.key?('size') || params.key('from')
        yield search_all
      elsif params.key?('sort') || params.key('facets')
        search_in_batches(&block)
      else
        scan_in_batches(batch_options, &block)
      end
    end

    def count
      return @count if defined? @count
      populate_counts
      @count
    end

    def empty?
      count == 0
    end

    def any?
      !empty?
    end

    def first
      @type_in_index.scoped(
        params.merge('from' => 0, 'size' => 1)).to_a.first
    end

    def all_facets
      return @all_facets if defined? @all_facets
      populate_counts
      @all_facets ||= nil
    end

    def scoped(params, index = @index)
      dup_params = ::Marshal.load(::Marshal.dump(@params))
      copy = ::Elastictastic::Scope.new(@type_in_index, dup_params)
      copy.merge!(params)
      copy
    end

    def method_missing(method, *args, &block)
      @type_in_index.clazz.with_scope(self) do
        @type_in_index.clazz.__send__(method, *args, &block)
      end
    end

    def index
      @type_in_index.index
    end

    def inspect
      @params.inspect
    end

    protected

    def merge!(params)
      @params = Util.deep_merge(@params, Util.deep_stringify(params))
    end

    def search(search_params = {})
      ::Elastictastic.client.search(
        @type_in_index.index,
        @type_in_index.type,
        params,
        search_params
      )
    end

    private

    def search_all
      response = search(:search_type => 'query_then_fetch')
      populate_counts(response)
      response['hits']['hits'].map do |hit|
        @type_in_index.clazz.new_from_elasticsearch_hit(hit)
      end
    end

    def search_in_batches(&block)
      from, size, result_count = 0, 100, 0
      scope_with_size = self.size(size)
      begin
        scope = scope_with_size.from(from)
        response = scope.search(:search_type => 'query_then_fetch')
        populate_counts(response)
        results = response['hits']['hits'].map do |hit|
          @type_in_index.clazz.new_from_elasticsearch_hit(hit)
        end
        yield(results)
        from += size
        result_count += results.length
        @count ||= scope.count
      end while result_count < @count
    end

    def scan_in_batches(batch_options, &block)
      batch_options = batch_options.symbolize_keys
      scroll_options = {
        :scroll => "#{batch_options[:ttl] || 60}s",
        :size => batch_options[:batch_size] || 100
      }
      scan_response = ::Elastictastic.client.search(
        @type_in_index.index,
        @type_in_index.type,
        params,
        scroll_options.merge(:search_type => 'scan')
      )

      @count = scan_response['hits']['total']
      scroll_id = scan_response['_scroll_id']

      begin
        response = ::Elastictastic.client.scroll(scroll_id, scroll_options.slice(:scroll))
        scroll_id = response['_scroll_id']
        docs = response['hits']['hits'].map do |hit|
          @type_in_index.clazz.new_from_elasticsearch_hit(hit)
        end
        yield(docs)
      end until response['hits']['hits'].empty?
    end

    def populate_counts(response = nil)
      response ||= search(:search_type => 'count')
      @count ||= response['hits']['total']
      if response['facets']
        @all_facets ||= ::Hashie::Mash.new(response['facets'])
      end
    end
  end
end
