module Elastictastic
  module Scoped
    def scoped(params, index = nil)
      if current_scope
        current_scope.scoped(params)
      else
        Scope.new(in_default_index, params)
      end
    end

    def with_scope(scope)
      scope_stack.push(scope)
      begin
        yield
      ensure
        scope_stack.pop
      end
    end

    def scope_stack
      Thread.current["#{name}::scope_stack"] ||= []
    end

    def current_scope
      scope_stack.last
    end
  end
end
