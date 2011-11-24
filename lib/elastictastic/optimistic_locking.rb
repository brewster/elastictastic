module Elastictastic
  module OptimisticLocking
    def update(id, &block)
      scope = current_scope
      instance = find(id)
      yield instance
      instance.save do |e|
        case e
        when nil # chill
        when Elastictastic::ServerError::VersionConflictEngineException
          scope.update(id, &block)
        else
          raise e
        end
      end
    end
  end
end
