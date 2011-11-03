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

      add_method_tracer :create, 'ElasticSearch/#{args[1].classify}#create'
      add_method_tracer :delete, 'ElasticSearch/#{args[1].classify + "#" if args[1]}/delete'
      add_method_tracer :get, 'ElasticSearch/#{args[1].classify}#get'
      add_method_tracer :mget, 'ElasticSearch/mget'
      add_method_tracer :put_mapping, 'ElasticSearch/#{args[1].classify}#put_mapping'
      add_method_tracer :scroll, 'ElasticSearch/scroll'
      add_method_tracer :search, 'ElasticSearch/#{args[1].classify}#search'
      add_method_tracer :update, 'ElasticSearch/#{args[1].classify}#update'
    end
  end
end

Elastictastic::Client.module_eval { include Elastictastic::NewRelicInstrumentation }
