require 'fakeweb'

module Elastictastic
  module TestHelpers
    ALPHANUM = ('0'..'9').to_a + ('A'..'Z').to_a + ('a'..'z').to_a

    def stub_elasticsearch_create(index, type, *args)
      options = args.extract_options!
      id = args.pop
      if id.nil?
        id = ''
        22.times { id << ALPHANUM[rand(ALPHANUM.length)] }
        path = "/#{index}/#{type}"
        method = :post
      else
        path = "/#{index}/#{type}/#{id}/_create"
        method = :put
      end

      FakeWeb.register_uri(
        method,
        TestHelpers.uri_for_path(path),
        options.reverse_merge(:body => {
          'ok' => 'true',
          '_index' => index,
          '_type' => type,
          '_id' => id
        }.to_json)
      )
      id
    end

    def stub_elasticsearch_update(index, type, id)
      FakeWeb.register_uri(
        :put,
        TestHelpers.uri_for_path("/#{index}/#{type}/#{id}"),
        :body => {
          'ok' => 'true',
          '_index' => index,
          '_type' => type,
          '_id' => id
        }.to_json
      )
    end

    def stub_elasticsearch_get(index, type, id)
      FakeWeb.register_uri(
        :get,
        TestHelpers.uri_for_path("/#{index}/#{type}/#{id}")
      )
    end

    def stub_elasticsearch_destroy(index, type, id, options = {})
      FakeWeb.register_uri(
        :delete,
        TestHelpers.uri_for_path("/#{index}/#{type}/#{id}"),
        options.reverse_merge(:body => {
          'ok' => true,
          'found' => true,
          '_index' => 'test',
          '_type' => 'test',
          '_id' => id,
          '_version' => 1
        }.to_json)
      )
    end

    def stub_elasticsearch_destroy_all(index, type)
      FakeWeb.register_uri(
        :delete,
        TestHelpers.uri_for_path("/#{index}/#{type}"),
        :body => { 'ok' => true }.to_json
      )
    end

    def self.uri_for_path(path)
      URI::HTTP.build(
        :host => Elastictastic.config.host,
        :port => Elastictastic.config.port,
        :path => path
      )
    end
  end
end
