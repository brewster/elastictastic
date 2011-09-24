module Elastictastic
  class TypeInIndex < BasicObject
    include Search

    attr_reader :clazz, :index

    def initialize(clazz, index)
      @clazz, @index = clazz, index
    end

    def new(*args)
      @clazz.allocate.tap do |document|
        index = @index
        document.instance_eval do
          @index = index
          initialize(*args)
        end
      end
    end

    def destroy_all
      ::Elastictastic.client.delete(index, type)
    end

    def sync_mapping
      ::Elastictastic.client.put_mapping(index, type, @clazz.mapping)
    end

    def type
      @clazz.type
    end

    def find(*args)
      options = args.extract_options!
      if args.length == 1
        find_one(args.first, options)
      else
        find_many(args, options)
      end
    end

    def find_one(id, options = {})
      params = {}
      if options[:fields]
        params[:fields] = Array(options[:fields]).join(',')
      end
      data = ::Elastictastic.client.get(index, type, id, params)
      return nil if data['exists'] == false
      case data['status']
      when nil
        @clazz.new_from_elasticsearch_hit(data)
      when 404
        nil
      else
        raise data['error'] || "Unexpected response from ElasticSearch: #{data.inspect}"
      end
    end

    def find_many(ids, options = {})
      docspec = ids.map do |id|
        { '_id' => id }.tap do |identifier|
          identifier['fields'] = Array(options[:fields]) if options[:fields]
        end
      end
      data = ::Elastictastic.client.mget(docspec, index, type)
      data['docs'].map do |hit|
        @clazz.new_from_elasticsearch_hit(hit)
      end
    end

    def scoped(params, index = nil)
      if @clazz.current_scope
        @clazz.current_scope.scoped(params)
      else
        Scope.new(self, params)
      end
    end

    def method_missing(method, *args, &block)
      @clazz.with_scope(all) do
        @clazz.__send__(method, *args, &block)
      end
    end
  end
end
