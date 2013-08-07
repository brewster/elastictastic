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
    io.string.should include "ElasticSearch GET (3ms) /default/post/1\n"
  end

  it 'should log body of POST requests to logger' do
    stub_es_create('default', 'post')
    client.create('default', 'post', nil, {})
    io.string.should include "ElasticSearch POST (3ms) /default/post {}\n"
  end
end
