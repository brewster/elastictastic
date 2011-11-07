module Elastictastic
  class NestedCollectionProxy < BasicObject
    attr_reader :owner, :association, :target

    def initialize(owner, association, elasticsearch_docs)
      @owner, @association = owner, association
      @target = elasticsearch_docs.map do |elasticsearch_doc|
        association.clazz.new.tap do |nested_document|
          nested_document.elasticsearch_doc = elasticsearch_doc
        end
      end
    end

    def method_missing(method, *args, &block)
      @target.__send__(method, *args, &block)
    end
  end
end
