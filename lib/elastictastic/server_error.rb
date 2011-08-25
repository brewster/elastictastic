module Elastictastic
  module ServerError
    class ServerError < StandardError
      attr_accessor :status
    end

    class <<self
      def const_missing(name)
        Class.new(::Elastictastic::ServerError::ServerError).tap do |error|
          const_set(name, error)
        end
      end
    end
  end
end
