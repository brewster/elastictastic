module Elastictastic
  module Persistence
    def save(&block)
      persisted? ? update(&block) : create(&block)
    end
    
    def destroy(&block)
      if persisted?
        Elastictastic.persister.destroy(self, &block)
      else
        raise OperationNotAllowed, "Cannot destroy transient document: #{inspect}"
      end
    end

    def persisted?
      !!@persisted
    end

    def transient?
      !persisted?
    end

    def pending_save?
      !!@pending_save
    end

    def pending_destroy?
      !!@pending_destroy
    end

    def persisted!
      @persisted = true
      @pending_save = false
    end

    def transient!
      @persisted = @pending_destroy = false
    end

    def pending_save!
      @pending_save = true
    end

    def pending_destroy!
      @pending_destroy = true
    end

    protected

    def create(&block)
      Elastictastic.persister.create(self, &block)
    end

    def update(&block)
      Elastictastic.persister.update(self, &block)
    end

    private

    def assert_transient!
      if persisted?
        raise IllegalModificationError,
          "Cannot modify identity attribute after model has been saved."
      end
    end
  end
end
