module Elastictastic
  module OptimisticLocking
    extend ActiveSupport::Concern

    module ClassMethods
      def update(id, &block)
        instance = find(id)
        instance.try_update(current_scope, &block) if instance
      end

      def update_each(&block)
        all.each { |instance| instance.try_update(current_scope, &block) }
      end
    end

    module InstanceMethods
      def try_update(scope, &block) #:nodoc:
        yield self
        update do |e|
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
end
