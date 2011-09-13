module Elastictastic
  module Requests
    ERROR_PATTERN = /^([A-Z][A-Za-z]*).*?:\s*(.*)$/

    private

    def request(method, *args)
      JSON.parse(Elastictastic.transport.__send__(method, *args)).tap do |parsed|
        if parsed['error']
          error = parsed['error']
        elsif parsed['_shards'] && parsed['_shards']['failures']
          error = parsed['_shards']['failures'].first['reason']
        end

        if error
          match = ERROR_PATTERN.match(error)
          if match
            clazz = Elastictastic::ServerError.const_get(match[1])
            error = clazz.new(match[2])
            error.status = parsed['status']
            raise error
          else
            raise Elastictastic::ServerError::ServerError, parsed['error']
          end
        end
      end
    end
  end
end
