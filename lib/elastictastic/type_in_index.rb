module Elastictastic
  class TypeInIndex
    attr_reader :index

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
  end
end
