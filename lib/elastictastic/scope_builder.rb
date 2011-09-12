module Elastictastic
  class ScopeBuilder < BasicObject
    class <<self
      private :new

      def build(&block)
        new(&block).build
      end
    end

    def initialize(&block)
      @block = block
    end

    def build
      @scope = {}
      instance_eval(&@block)
      @scope
    end

    def method_missing(method, *args, &block)
      args << ScopeBuilder.build(&block) if block
      value =
        case args.length
        when 0 then {}
        when 1 then args.first
        else args
        end
      @scope[method.to_s] = value
    end
  end
end
