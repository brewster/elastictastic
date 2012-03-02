require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Rotor do
  let(:client) { Elastictastic::Client.new(config) }
  let(:last_request) { FakeWeb.last_request }

  context 'without backoff' do
    let(:config) do
      Elastictastic::Configuration.new.tap do |config|
        config.hosts = ['http://es1.local', 'http://es2.local']
      end
    end

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
  end

  context 'with backoff' do
    let(:config) do
      Elastictastic::Configuration.new.tap do |config|
        config.hosts = ['http://es1.local', 'http://es2.local']
        config.backoff_threshold = 2
        config.backoff_start = 1
        config.backoff_max = 4
      end
    end
    let!(:time) { Time.now.tap { |time| Time.stub(:now).and_return(time) }}

    before do
      host_status(1 => false, 2 => true)
    end

    it 'should retry immediately before reaching initial failure count' do
      client.get('default', 'post', '1')
      expect { client.get('default', 'post', '1') }.to change(FakeWeb.requests, :length).by(2)
    end

    it 'should back off after initial failure count reached' do
      2.times { client.get('default', 'post', '1') }
      expect { client.get('default', 'post', '1') }.to change(FakeWeb.requests, :length).by(1)
    end

    it 'should retry after initial backoff period elapses' do
      3.times { client.get('default', 'post', '1') }
      Time.stub(:now).and_return(time + 1)
      expect { client.get('default', 'post', '1') }.to change(FakeWeb.requests, :length).by(2)
    end

    it 'should double backoff after another failure' do
      3.times { client.get('default', 'post', '1') }
      Time.stub(:now).and_return(time + 1)
      client.get('default', 'post', '1')
      Time.stub(:now).and_return(time + 2)
      expect { client.get('default', 'post', '1') }.to change(FakeWeb.requests, :length).by(1)
    end

    it 'should cap backoff interval at backoff_max' do
      2.times { client.get('default', 'post', '1') } # first backoff - 1 second
      Time.stub(:now).and_return(time + 1)
      client.get('default', 'post', '1') # second backoff - 2 seconds
      Time.stub(:now).and_return(time + 3)
      client.get('default', 'post', '1') # third backoff - 4 seconds
      Time.stub(:now).and_return(time + 7)
      client.get('default', 'post', '1') # fourth backoff - 4 seconds again
      Time.stub(:now).and_return(time + 11)
      expect { client.get('default', 'post', '1') }.to change(FakeWeb.requests, :length).by(2)
    end

    it 'should reset backoff after a successful request' do
      2.times { client.get('default', 'post', '1') } # initial backoff - 1 second
      host_status(1 => true, 2 => true)
      Time.stub(:now).and_return(time + 1)
      2.times { client.get('default', 'post', '1') } # first one will go to es2 because of rotation. second one has success so es1 should reset
      host_status(1 => false, 2 => true)
      client.get('default', 'post', '1') # should be willing to immediately retry
      host_status(1 => true, 2 => false)
      expect { client.get('default', 'post', '1') }.to_not raise_error # only will succeed if it retries #1
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
