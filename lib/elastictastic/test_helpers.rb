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

    def stub_elasticsearch_get(index, type, id, doc = {})
      FakeWeb.register_uri(
        :get,
        TestHelpers.uri_for_path("/#{index}/#{type}/#{id}"),
        :body => {
          'ok' => true,
          '_index' => index,
          '_type' => type,
          '_id' => id,
          '_source' => doc
        }.to_json
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

    def stub_elasticsearch_bulk(*responses)
      FakeWeb.register_uri(
        :post,
        TestHelpers.uri_for_path("/_bulk"),
        :body => { 'took' => 1, 'items' => responses }.to_json
      )
    end

    def stub_elasticsearch_put_mapping(index, type)
      FakeWeb.register_uri(
        :put,
        TestHelpers.uri_for_path("/#{index}/#{type}/_mapping"),
        :body => { 'ok' => true, 'acknowledged' =>  true }.to_json
      )
    end

    def stub_elasticsearch_search(index, type, data)
      if Array === data
        response = data.map do |datum|
          { :body => datum.to_json }
        end
      else
        response = { :body =>  data.to_json }
      end

      uri = TestHelpers.uri_for_path("/#{index}/#{type}/_search").to_s
      FakeWeb.register_uri(
        :post,
        /^#{Regexp.escape(uri)}/,
        response
      )
    end

    def stub_elasticsearch_scan(index, type, batch_size, *hits)
      scan_uri = Regexp.escape(TestHelpers.uri_for_path("/#{index}/#{type}/_search").to_s)
      scroll_ids = Array.new(batch_size + 1) { rand(10**100).to_s(36) }
      FakeWeb.register_uri(
        :post,
        /^#{scan_uri}\?.*search_type=scan/,
        :body => {
          '_scroll_id' => scroll_ids.first,
          'hits' => { 'total' => hits.length, 'hits' => [] }
        }.to_json
      )

      batches = hits.each_slice(batch_size).each_with_index.map do |hit_batch, i|
        { :body => { '_scroll_id' => scroll_ids[i+1], 'hits' => { 'hits' => hit_batch }}.to_json }
      end
      batches << { :body => { 'hits' => { 'hits' => [] }}.to_json }
      scroll_uri = Regexp.escape(TestHelpers.uri_for_path("/_search/scroll").to_s)
      FakeWeb.register_uri(
        :post,
        /^#{scroll_uri}/,
        batches
      )
      scroll_ids
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
