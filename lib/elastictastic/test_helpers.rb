begin
  require 'fakeweb'
rescue LoadError => e
  raise LoadError, "Elastictastic::TestHelpers requires the 'fakeweb' gem."
end

module Elastictastic
  module TestHelpers
    ALPHANUM = ('0'..'9').to_a + ('A'..'Z').to_a + ('a'..'z').to_a

    def stub_es_create(index, type, id = nil)
      if id.nil?
        id = generate_es_id
        components = [index, type]
        method = :post
      else
        components = [index, type, id, '_create']
        method = :put
      end

      stub_request_json(
        method,
        match_es_resource(components),
        generate_es_hit(type, :id => id, :index => index).merge('ok' => 'true')
      )
      id
    end

    def stub_es_update(index, type, id, version = 2)
      stub_request_json(
        :put,
        match_es_resource(index, type, id),
        generate_es_hit(type, :index => index, :id => id, :version => version)
      )
    end

    def stub_es_head(index, type, id, exists)
      stub_request(
        :head,
        match_es_resource(index, type, id),
        :status => (exists ? 200 : 404),
        :body => nil
      )
    end

    def stub_es_get(index, type, id, doc = {}, version = 1)
      stub_request_json(
        :get,
        match_es_resource(index, type, id),
        generate_es_hit(
          type,
          :index => index,
          :id => id,
          :version => version,
          :source => doc
        ).merge('exists' => !doc.nil?)
      )
    end

    def stub_es_mget(index, type, *ids)
      given_ids_with_docs = ids.extract_options!
      ids_with_docs = {}
      ids.each { |id| ids_with_docs[id] = {} }
      ids_with_docs.merge!(given_ids_with_docs)
      path = index ? "/#{index}/#{type}/_mget" : "/_mget"
      docs = ids_with_docs.each_pair.map do |id, doc|
        id, type, index = *id if Array === id
        generate_es_hit(
          type, :index => index, :id => id, :source => doc
        ).merge('exists' => !!doc)
      end

      stub_request_json(
        :post,
        match_es_path(path),
        'docs' => docs
      )
    end

    def stub_es_destroy(index, type, id, options = {})
      stub_request_json(
        :delete,
        match_es_resource(index, type, id),
        generate_es_hit(
          type, :index => index, :id => id
        ).merge('ok' => true, 'found' => true).merge(options)
      )
    end

    def stub_es_destroy_all(index, type)
      stub_request_json(
        :delete,
        match_es_resource(index, type),
        'ok' => true
      )
    end

    def stub_es_bulk(*responses)
      stub_request_json(
        :post,
        match_es_path('/_bulk'),
        'took' => 1, 'items' => responses
      )
    end

    def stub_es_put_mapping(index, type)
      stub_request_json(
        :put,
        match_es_resource(index, '_mapping', type),
        'ok' => true, 'acknowledged' => true
      )
    end

    def stub_es_search(index, type, data)
      if Array === data
        response = data.map do |datum|
          { :body => Elastictastic.json_encode(datum) }
        end
      else
        response = { :body =>  Elastictastic.json_encode(data) }
      end

      stub_request(
        :post,
        match_es_resource(index, type, '_search'),
        response
      )
    end

    def stub_es_msearch(*hits_collections)
      responses = hits_collections.map do |collection|
        { 'hits' => { 'hits' => collection, 'total' => collection.length }}
      end
      stub_request_json(
        :post,
        match_es_path('/_msearch'),
        'responses' => responses
      )
    end

    def stub_es_msearch_count(*counts)
      responses = counts.map do |count|
        { 'hits' => { 'hits' => [], 'total' => count }}
      end
      stub_request_json(
        :post,
        match_es_path('/_msearch'),
        'responses' => responses
      )
    end

    def stub_es_scan(index, type, batch_size, *hits)
      scroll_ids = Array.new(batch_size + 1) { rand(10**100).to_s(36) }
      stub_request_json(
        :post,
        match_es_resource(index, type, '_search'),
        '_scroll_id' => scroll_ids.first,
        'hits' => { 'total' => hits.length, 'hits' => [] }
      )

      batches = hits.each_slice(batch_size).each_with_index.map do |hit_batch, i|
        {
          :body => Elastictastic.json_encode(
            '_scroll_id' => scroll_ids[i+1], 'hits' => { 'hits' => hit_batch }
          )
        }
      end
      batches << { :body => Elastictastic.json_encode('hits' => { 'hits' => [] }) }
      stub_request(:post, match_es_path('/_search/scroll'), batches)
      scroll_ids
    end

    def self.match_es_path(path)
      /^#{Regexp.escape(Elastictastic.config.hosts.first)}#{Regexp.escape(path)}(\?.*)?$/
    end

    def self.match_es_resource(*components)
      match_es_path("/#{components.flatten.join('/')}")
    end

    def match_es_path(path)
      TestHelpers.match_es_path(path)
    end

    def match_es_resource(*components)
      TestHelpers.match_es_resource(*components)
    end

    def stub_request_json(method, uri, *responses)
      json_responses = responses.map { |response| { :body => Elastictastic.json_encode(response) }}
      json_responses = json_responses.first if json_responses.length == 1
      stub_request(method, uri, json_responses)
    end

    def stub_request(method, url, options = {})
      FakeWeb.register_uri(method, url, options)
    end

    def last_request
      FakeWeb.last_request
    end

    def last_request_json
      Elastictastic.json_decode(last_request.body)
    end

    def last_request_uri
      URI.parse(last_request.path)
    end

    def generate_es_id
      ''.tap do |id|
        22.times { id << ALPHANUM[rand(ALPHANUM.length)] }
      end
    end

    def generate_es_hit(type, options = {})
      {
        '_id' => options[:id] || generate_es_id,
        '_type' => type,
        '_index' => options[:index] || Elastictastic.config.default_index,
        '_version' => options[:version] || 1,
        '_source' => options.key?(:source) ? options[:source] : {}
      }
    end
  end
end
