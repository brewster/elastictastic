require 'stringio'

module Elastictastic
  class MultiSearch
    def self.query(*scopes)
      new(*scopes).query
    end

    def self.count(*scopes)
      new(*scopes).count
    end

    def initialize(*scopes)
      @scopes = scopes.flatten!
    end

    def query
      validate_scopes_for_query
      msearch('query_then_fetch')
    end

    def count
      msearch('count')
    end

    private

    def msearch(search_type)
      responses = Elastictastic.client.msearch(search_bodies(search_type))['responses']
      responses.each_with_index do |response, i|
        raise ServerError[response['error']] if response['error']
        scope = @scopes[i]
        scope.response = response
      end
    end

    def search_bodies(search_type)
      StringIO.new.tap do |io|
        @scopes.each do |scope|
          io.puts(Elastictastic.json_encode(
            'type' => scope.type,
            'index' => scope.index.to_s,
            'search_type' => search_type
          ))
          io.puts(Elastictastic.json_encode(scope.params))
        end
      end.string
    end

    def validate_scopes_for_query
      @scopes.each do |scope|
        if scope.params['size'].blank?
          raise ArgumentError, "Multi-search scopes must have an explicit size"
        end
      end
    end
  end
end
