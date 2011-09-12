module Elastictastic
  class Index
    class <<self
      def default
        new(Elastictastic.config.default_index)
      end
    end

    def initialize(name)
      @name = name
    end

    def to_s
      @name
    end
  end
end
