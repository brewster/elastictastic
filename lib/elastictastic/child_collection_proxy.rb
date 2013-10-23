module Elastictastic
  class ChildCollectionProxy < Scope
    attr_reader :parent

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
        ),
        self
      )
      @parent = parent
      @transient_children = []
    end

    def initialize_instance(instance)
      super
      self << instance
    end

    def first
      super || transient_children.first
    end

    def each(&block)
      if block
        super if @parent.persisted?
        transient_children.each(&block)
      else
        ::Enumerator.new do |y|
          self.each do |val|
            y.yield val
          end
        end
      end
    end

    def <<(child)
      child.parent = @parent
      @transient_children << child
      self
    end

    def transient_children
      @transient_children.tap do |children|
        children.reject! do |child|
          !child.transient?
        end
      end
    end

    private

    def params_for_find
      super.merge('routing' => @parent.id)
    end
  end
end
