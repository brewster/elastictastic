module Elastictastic
  module Search
    SEARCH_KEYS = %w(query filter from size sort highlight fields script_fields
                     preference facets)

    SEARCH_KEYS.each do |search_key|
      module_eval <<-RUBY
        def #{search_key}(*values, &block)
          values << ScopeBuilder.build(&block) if block

          case values.length
          when 0 then raise ArgumentError, "wrong number of arguments (0 for 1)"
          when 1 then value = values.first
          else value = values
          end

          scoped(#{search_key.inspect} => value)
        end
      RUBY
    end

    def all
      scoped({})
    end
  end
end
