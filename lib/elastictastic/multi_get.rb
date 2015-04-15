module Elastictastic

  class MultiGet

    include Enumerable

    def initialize
      @docspecs = []
      @scopes = []
    end

    def add(scope, *ids)
      scope = scope.all
      params = scope.multi_get_params
      ids.flatten.each do |id|
        @docspecs << params.merge('_id' => id.to_s)
        @scopes << scope
      end
    end

    def each
      return if @docspecs.empty?
      Elastictastic.client.mget(@docspecs)['docs'].zip(@scopes) do |hit, scope|
        yield scope.materialize_hit(hit) if hit['found']
      end
    end

  end

end
