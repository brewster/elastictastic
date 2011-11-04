module Elastictastic
  module Persistence
    def save
      persisted? ? update : create
    end
    
    def destroy
      if persisted?
        Elastictastic.persister.destroy(self)
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

    def create
      Elastictastic.persister.create(self)
    end

    def update
      Elastictastic.persister.update(self)
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
