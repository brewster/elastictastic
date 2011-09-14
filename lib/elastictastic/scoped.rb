module Elastictastic
  module Scoped
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
