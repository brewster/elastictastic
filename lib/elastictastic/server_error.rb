module Elastictastic
  module ServerError
    ERROR_PATTERN = /^([A-Z][A-Za-z]*)(?::\s*)?(.*)$/
    NESTED_PATTERN = /^.*nested:\s+(.*)$/

    class ServerError < StandardError
      attr_accessor :status
    end

    class <<self
      def const_missing(name)
        Class.new(::Elastictastic::ServerError::ServerError).tap do |error|
          const_set(name, error)
        end
      end

      def [](server_message, status = nil)
        match = ERROR_PATTERN.match(server_message)
        if match
          if (nested_match = NESTED_PATTERN.match(match[2]))
            return self[nested_match[1], status]
          else
            clazz = Elastictastic::ServerError.const_get(match[1])
            error = clazz.new(match[2])
            error.status = status
            error
          end
        else
          Elastictastic::ServerError::ServerError.new(server_message)
        end
      end
    end
  end
end
