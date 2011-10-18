module Elastictastic
  class Search
    KEYS = %w(query filter from size sort highlight fields script_fields
              preference facets)

    attr_reader :params
    delegate :[], :to => :params

    def initialize(params = {})
      @params = Util.deep_stringify(params)
    end

    def merge(merge_params)
      dup_params = Marshal.load(Marshal.dump(merge_params))
      Search.new(Util.deep_merge(@params, dup_params))
    end
  end
end
