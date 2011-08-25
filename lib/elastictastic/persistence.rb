module Elastictastic
  module Persistence
    extend ActiveSupport::Concern

    module ClassMethods
      def get(*args)
        if args.length < 1 || args.length > 2
          raise NoMethodError, "wrong number of arguments (#{args.length} for 1-2)"
        end
        id = args.pop
        index = args.pop || default_index

        data = JSON.parse(Elastictastic.transport.get(
          "/#{index}/#{type}/#{id}"
        ))
        return nil if data['exists'] == false
        case data['status']
        when nil
          new_from_elasticsearch_response(data)
        when 404
          nil
        else
          raise data['error'] || "Unexpected response from ElasticSearch: #{data.inspect}"
        end
      end

      def sync_mapping(index = '_all')
        Elastictastic.transport.put("/#{index}/#{type}/_mapping", mapping.to_json)
      end

      def destroy_all
        index = Elastictastic.config.default_index
        # TODO handle delete by query
        Elastictastic.transport.delete("/#{index}/#{type}")
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
          path << '/' << id if id
        end
      end
    end
  end
end
