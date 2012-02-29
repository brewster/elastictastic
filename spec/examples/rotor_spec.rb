require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Rotor do
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

    it 'should pass PUT body to retry' do
      client.update('default', 'post', '1', { 'title' => 'pizza' })
      FakeWeb.last_request.body.should == { 'title' => 'pizza' }.to_json
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
      url = %r(^http://es#{i}.local/)
      if healthy
        options = { :body => '{"success":true}' }
      else
        options = { :exception => Errno::ECONNREFUSED }
      end
      FakeWeb.register_uri(:any, url, options)
    end
  end
end
