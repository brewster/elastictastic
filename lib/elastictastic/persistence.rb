module Elastictastic
  module Persistence
    extend ActiveSupport::Concern

    module ClassMethods
      delegate :find, :destroy_all, :sync_mapping, :to => :default_scope
    end
    
    module InstanceMethods
      def save
        if persisted?
          Elastictastic.persister.update(self)
        else
          Elastictastic.persister.create(self)
        end
      end
      
      def destroy
        if persisted?
          Elastictastic.persister.destroy(self)
        else
          raise OperationNotAllowed, "Cannot destroy transient document: #{inspect}"
        end
      end

      def elasticsearch_path
        "/#{index}/#{self.class.type}".tap do |path|
          path << '/' << id.to_s if id
        end
      end
    end
  end
end
