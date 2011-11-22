require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::OptimisticLocking do
  include Elastictastic::TestHelpers

  let :post do
    Post.new.tap do |post|
      post.id = '123abc'
      post.version = 1
      post.persisted!
    end
  end

  context 'when version conflict raised from discrete persistence' do
    describe '#save' do
      before do
        FakeWeb.register_uri(
          :put,
          Elastictastic::TestHelpers.uri_for_path('/default/post/123abc?version=1'),
          :body => {
            'error' => 'VersionConflictEngineException: [[default][3] [post][abc123]: version conflict, current[2], required[1]]',
            'status' => 409
          }.to_json
        )
      end

      it 'should raise VersionConflict' do
        expect { post.save }.to raise_error(Elastictastic::ServerError::VersionConflictEngineException)
      end

      it 'should yield VersionConflict when called with block' do
        ex = nil
        post.save { |e| ex = e }
        ex.should be_a(Elastictastic::ServerError::VersionConflictEngineException)
      end
    end # describe '#save'

    describe '::update' do
      before do
        stub_elasticsearch_get('default', 'post', '123abc')
        stub_elasticsearch_update('default', 'post', '123abc', 2)
      end
    end # describe '::update'
  end # context 'when version conflict raised from discrete persistence'

  context 'when version conflict raised from bulk persistence' do
    before do
      stub_elasticsearch_bulk(
        'index' => {
          '_index' => 'default', '_type' => 'post', '_id' => '123abc',
          'error' => 'VersionConflictEngineException: [[default][3] [post][abc123]: version conflict, current[2], required[1]]'
        }
      )
    end

    it 'should raise error' do
      expect { Elastictastic.bulk { post.save }}.to raise_error(Elastictastic::ServerError::VersionConflictEngineException)
    end

    it 'should yield an error when called with block' do
      ex = nil
      Elastictastic.bulk { post.save { |e| ex = e }}
      ex.should be_a(Elastictastic::ServerError::VersionConflictEngineException)
    end
  end
end
