module Elastictastic
  module Requests
    private

    def request(method, *args)
      JSON.parse(Elastictastic.transport.__send__(method, *args)).tap do |parsed|
        raise parsed['error'] if parsed['error']
      end
    end
  end
end
