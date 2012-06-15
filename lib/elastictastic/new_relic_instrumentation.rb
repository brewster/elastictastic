begin
  require 'new_relic/agent/method_tracer'
rescue LoadError => e
  raise LoadError, "Can't use NewRelic instrumentation without NewRelic gem"
end

module Elastictastic
  module NewRelicInstrumentation
    extend ActiveSupport::Concern

    included do
      include NewRelic::Agent::MethodTracer

      add_method_tracer :create, 'Database/ElasticSearch/create'
      add_method_tracer :delete, 'Database/ElasticSearch/delete'
      add_method_tracer :get, 'Database/ElasticSearch/get'
      add_method_tracer :mget, 'Database/ElasticSearch/mget'
      add_method_tracer :put_mapping, 'Database/ElasticSearch/put_mapping'
      add_method_tracer :scroll, 'Database/ElasticSearch/scroll'
      add_method_tracer :search, 'Database/ElasticSearch/search'
      add_method_tracer :update, 'Database/ElasticSearch/update'
    end
  end
end

Elastictastic::Client.module_eval { include Elastictastic::NewRelicInstrumentation }
