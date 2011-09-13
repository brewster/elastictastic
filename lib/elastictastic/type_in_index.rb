module Elastictastic
  class TypeInIndex
    attr_reader :clazz, :index

    def initialize(clazz, index)
      @clazz, @index = clazz, index
    end

    def new(*args)
      @clazz.new(*args).tap do |document|
        index = @index
        document.instance_eval { @index = index }
      end
    end

    def destroy_all
      Elastictastic.transport.delete("/#{index}/#{type}")
    end

    def sync_mapping
      Elastictastic.transport.put("/#{index}/#{type}/_mapping", @clazz.mapping.to_json)
    end

    def type
      @clazz.type
    end

    def find(id)
      data = JSON.parse(Elastictastic.transport.get(
        "/#{index}/#{type}/#{id}"
      ))
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
  end
end
