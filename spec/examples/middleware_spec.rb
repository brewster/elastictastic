require File.expand_path('../spec_helper', __FILE__)
require 'stringio'

describe Elastictastic::Middleware::LogRequests do
  include Elastictastic::TestHelpers

  let(:io) { StringIO.new }
  let(:logger) { Logger.new(io) }
  let(:config) do
    Elastictastic::Configuration.new.tap do |config|
      config.logger = logger
    end
  end
  let(:client) { Elastictastic::Client.new(config) }

  before do
    now = Time.now
    Time.stub(:now).and_return(now, now + 0.003)
  end

  it 'should log get requests to logger' do
    FakeWeb.register_uri(:get, "http://localhost:9200/default/post/1", :body => '{}')
    client.get('default', 'post', '1')
    io.string.should == "ElasticSearch GET (3ms) /default/post/1\n"
  end

  it 'should log body of POST requests to logger' do
    stub_es_create('default', 'post')
    client.create('default', 'post', nil, {})
    io.string.should == "ElasticSearch POST (3ms) /default/post {}\n"
  end

  context "error is raied" do

    let(:query_hash) do
      {
          "query" => {
            "match_all" => {}
        }
      }
    end

    let(:error_hash) do
      {
        "error" => "SearchPhaseExecutionException[Failed to execute phase [query]...",
        "status" => 400
      }
    end

    before do
      FakeWeb.register_uri(:post, "http://localhost:9200/default/post/_search?", :body => error_hash.to_json)
    end

    subject do
      client.search("default", "post", query_hash)
    end

    it 'should generate error from ElasticSearch response body' do
      expect { subject }.to raise_error { |error|
        error.should be_a(Elastictastic::ServerError::SearchPhaseExecutionException)
      }
    end

    it 'should attach response status' do
      expect { subject }.to raise_error { |error|
        error.status.should eq(400)
      }
    end

    it 'should attach request path' do
      expect { subject }.to raise_error { |error|
        error.request_path.should eq("/default/post/_search?")
      }
    end

    it 'should attach request body' do
      expect { subject }.to raise_error { |error|
        error.request_body.should eq(query_hash)
      }
    end
  end
end
