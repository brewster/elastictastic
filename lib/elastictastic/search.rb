module Elastictastic
  module Search
    SEARCH_KEYS = %w(query filter from size sort highlight fields script_fields
                     preference facets)

    SEARCH_KEYS.each do |search_key|
      module_eval <<-RUBY
        def #{search_key}(*values)
          values = values.first if values.length == 1
          scoped(#{search_key.inspect} => values)
        end
      RUBY
    end
  end
end
