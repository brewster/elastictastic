module Elastictastic
  module Persistence
    extend ActiveSupport::Concern

    module ClassMethods
      delegate :destroy_all, :sync_mapping, :to => :in_default_index

      def find(*args)
        if Hash === args.first
          multi_index_find_many(*args)
        else
          in_default_index.find(*args)
        end
      end

      def multi_index_find_many(ids_by_index, options = {})
        docs = []
        ids_by_index.each_pair do |index, ids|
          Array(ids).each do |id|
            docs << doc = {
              '_id' => id.to_s,
              '_type' => type,
              '_index' => index
            }
            doc['fields'] = Array(options[:fields]) if options[:fields]
          end
        end
        Elastictastic.client.mget(docs)
      end
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
