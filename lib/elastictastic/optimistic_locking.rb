module Elastictastic

  module OptimisticLocking

    extend ActiveSupport::Concern

    module ClassMethods

      def create_or_update(id, &block)
        scope = current_scope
        new.tap do |instance|
          instance.id = id
          yield instance
        end.create do |e|
          case e
          when nil # chill
          when Elastictastic::ServerError::DocumentAlreadyExistsEngineException,
            Elastictastic::ServerError::DocumentAlreadyExistsException # 0.19+
            scope.update(id, &block)
          else
            raise e
          end
        end
      rescue Elastictastic::CancelSave
        # Do Nothing
      end

      def update(id, &block)
        instance = scoped({}).find_one(id, :preference => '_primary_first')
        instance.try_update(current_scope, &block) if instance
      end

      def update_each(&block)
        all.each { |instance| instance.try_update(current_scope, &block) }
      end

    end

    def try_update(scope, &block) #:nodoc:
      yield self
      update do |e|
        case e
        when nil # chill
        when Elastictastic::ServerError::VersionConflictEngineException,
          Elastictastic::ServerError::VersionConflictException # 0.19
          scope.update(id, &block)
        else
          raise e
        end
      end
    rescue Elastictastic::CancelSave
      # Do Nothing
    end

  end

end
