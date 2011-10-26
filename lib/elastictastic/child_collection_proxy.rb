module Elastictastic
  class ChildCollectionProxy < Scope
    attr_reader :parent, :transient_children

    def initialize(association, parent)
      super(
        parent.index,
        association.clazz,
        Search.new(
          'query' => {
            'constant_score' => {
              'filter' => { 'term' => { '_parent' => parent.id }}
            }
          }
        )
      )
      @parent = parent
      @parent_collection = self
      @transient_children = []
    end

    def initialize_instance(instance)
      super
      self << instance
    end

    def first
      super || @transient_children.first
    end

    def each(&block)
      super.tap { @transient_children.each(&block) if block }
    end

    def persisted!(child)
      @transient_children.delete(child)
    end

    def <<(child)
      child._parent_collection = self
      @transient_children << child
      self
    end

    private

    def params_for_find
      super.merge('routing' => @parent.id)
    end
  end
end
