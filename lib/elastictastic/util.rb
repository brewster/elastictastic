require 'open-uri'

module Elastictastic
  module Util
    extend self

    def urlencode(string)
      URI::encode(string.to_s).gsub('/', '%2F')
    end

    def deep_stringify(hash)
      {}.tap do |stringified|
        hash.each_pair do |key, value|
          stringified[key.to_s] = Hash === value ? deep_stringify(value) : value
        end
      end
    end

    def deep_merge(l, r)
      if l.nil? then r
      elsif r.nil? then l
      elsif Hash === l && Hash === r
        {}.tap do |merged|
          (l.keys | r.keys).each do |key|
            merged[key] = deep_merge(l[key], r[key])
          end
        end
      elsif Array === l && Array === r then l + r
      elsif Array === l then l + [r]
      elsif Array === r then [l] + r
      else [l, r]
      end
    end

    def ensure_array(object)
      case object
      when nil then []
      when Array then object
      else [object]
      end
    end

    def call_or_each(object, &block)
      if Array === object then object.each(&block)
      else
        block.call(object)
        object
      end
    end

    def call_or_map(object, &block)
      if Array === object then object.map(&block)
      else block.call(object)
      end
    end

    def unflatten_hash(hash)
      {}.tap do |unflattened|
        hash.each_pair do |key, value|
          namespace = key.split('.')
          field_name = namespace.pop
          namespace.inject(unflattened) do |current, component|
            current[component] ||= {}
          end[field_name] = value
        end
      end
    end
  end
end
