module Elastictastic
  class Index
    class <<self
      def default
        new(Elastictastic.config.default_index)
      end
    end

    attr_reader :name

    def initialize(name)
      @name = name
    end

    def to_s
      @name
    end

    def ==(other)
      name == other.name
    end
  end
end
