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
end

describe Elastictastic::Middleware::Rotor do
  let(:config) do
    Elastictastic::Configuration.new.tap do |config|
      config.hosts = ['http://es1.local', 'http://es2.local']
    end
  end
  let(:client) { Elastictastic::Client.new(config) }
  let(:last_request) { FakeWeb.last_request }

  it 'should alternate requests between hosts' do
    expect do
      2.times do
        1.upto 2 do |i|
          host_status(i => true)
          client.get('default', 'post', '1')
        end
      end
    end.not_to raise_error # We can't check the hostname of last_request in Fakeweb
  end

  context 'if one host fails' do
    let!(:now) { Time.now.tap { |now| Time.stub(:now).and_return(now) }}

    before do
      host_status(1 => false, 2 => true)
    end

    it 'should try the next host' do
      client.get('default', 'post', '1').should == { 'success' => true }
    end
  end

  context 'if all hosts fail' do
    let!(:now) { Time.now.tap { |now| Time.stub(:now).and_return(now) }}

    before do
      host_status(1 => false, 2 => false)
    end

    it 'should raise error if no hosts respond' do
      expect { client.get('default', 'post', '1') }.to(raise_error Elastictastic::NoServerAvailable)
    end
  end

  private

  def host_status(statuses)
    FakeWeb.clean_registry
    statuses.each_pair do |i, healthy|
      url = "http://es#{i}.local/default/post/1"
      if healthy
        options = { :body => '{"success":true}' }
      else
        options = { :exception => Errno::ECONNREFUSED }
      end
      FakeWeb.register_uri(:get, url, options)
    end
  end
end
