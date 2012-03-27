require 'stringio'

module Elastictastic
  class MultiSearch
    Component = Struct.new(:scope, :search_type)

    def self.query(*scopes)
      new.query(*scopes).run
    end

    def self.count(*scopes)
      new.count(*scopes).run
    end

    def initialize
      @components = []
    end

    def query(*scopes)
      components = validate_scopes_for_query(scopes.flatten).map do |scope|
        Component.new(scope, 'query_then_fetch')
      end
      @components.concat(components)
      self
    end

    def count(*scopes)
      components = scopes.flatten.map { |scope| Component.new(scope, 'count') }
      @components.concat(components)
      self
    end

    def run
      responses = Elastictastic.client.msearch(search_bodies)['responses']
      responses.zip(@components) do |response, component|
        raise ServerError[response['error']] if response['error']
        scope, search_type = component.scope, component.search_type
        case search_type
        when 'query_then_fetch' then scope.response = response
        when 'count' then scope.counts = response
        end
      end
      self
    end

    private

    def search_bodies
      StringIO.new.tap do |io|
        @components.each do |component|
          scope, search_type = component.scope, component.search_type
          io.puts(Elastictastic.json_encode(
            'type' => scope.type,
            'index' => scope.index.to_s,
            'search_type' => search_type
          ))
          io.puts(Elastictastic.json_encode(scope.params))
        end
      end.string
    end

    def validate_scopes_for_query(scopes)
      scopes.each do |scope|
        if scope.params['size'].blank?
          raise ArgumentError, "Multi-search scopes must have an explicit size"
        end
      end
    end
  end
end
