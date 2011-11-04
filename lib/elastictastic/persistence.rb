module Elastictastic
  module Persistence
    def save
      if persisted?
        Elastictastic.persister.update(self)
      else
        Elastictastic.persister.create(self)
      end
      self.class.child_associations.each_pair do |name, association|
        association.extract(self).transient_children.each do |child|
          child.save unless child.pending_save?
        end
      end
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

    private

    def assert_transient!
      if persisted?
        raise IllegalModificationError,
          "Cannot modify identity attribute after model has been saved."
      end
    end
  end
end
