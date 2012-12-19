module Elastictastic
  module Persistence
    def save(options = {}, &block)
      persisted? ? update(options, &block) : create(options, &block)
    end

    def destroy(options = {}, &block)
      if persisted?
        Elastictastic.persister.destroy(self, &block)
      else
        raise OperationNotAllowed, "Cannot destroy transient document: #{inspect}"
      end
    end

    def persisted?
      !!@_persisted
    end

    def transient?
      !persisted?
    end

    def pending_save?
      !!@_pending_save
    end

    def pending_destroy?
      !!@_pending_destroy
    end

    def persisted!
      @_persisted = true
      @_pending_save = false
    end

    def transient!
      @_persisted = @_pending_destroy = false
    end

    def pending_save!
      @_pending_save = true
    end

    def pending_destroy!
      @_pending_destroy = true
    end

    protected

    def create(options = {}, &block)
      Elastictastic.persister.create(self, &block)
    end

    def update(options = {}, &block)
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
