require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::OptimisticLocking do
  include Elastictastic::TestHelpers

  shared_examples_for 'updatable scope' do
    let :post do
      scope.new.tap do |post|
        post.id = '123abc'
        post.version = 1
        post.persisted!
      end
    end

    context 'when version conflict raised from discrete persistence' do
      describe '#save' do
        before do
          stub_request_json(
            :put,
            match_es_resource(index, 'post', '123abc'),
            'error' => "VersionConflictEngineException: [[#{index}][3] [post][abc123]: version conflict, current[2], required[1]]",
            'status' => 409
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
          stub_request_json(
            :get,
            match_es_resource(index, 'post', '123abc'),
            generate_es_hit('post', :id => '123abc', :index => index, :version => 1).merge('exists' => true),
            generate_es_hit('post', :id => '123abc', :index => index, :version => 2, :source => { :title => 'Hey' }).merge('exists' => true)
          )
          stub_request_json(
            :put,
            match_es_resource(index, 'post', '123abc'),
            {
              'error' => "VersionConflictEngineException: [[#{index}][3] [post][abc123]: version conflict, current[2], required[1]]",
              'status' => 409
            },
            generate_es_hit('post', :id => '123abc', :version => 3, :index => index)
          )
          scope.update('123abc') do |post|
            post.comments_count = 3
          end
        end

        it 'should make four requests' do
          FakeWeb.should have(4).requests
        end

        it 'should make final update with modification in update block' do
          last_request_json['comments_count'].should == 3
        end

        it 'should make final update with data from latest version of doc' do
          last_request_json['title'].should == 'Hey'
        end

        it 'should make final update with correct version' do
          last_request_uri.query.split('&').should include('version=2')
        end

        it 'should send final update to correct index' do
          last_request_uri.path.split('/')[1].should == index
        end
      end # describe '::update'
    end # context 'when version conflict raised from discrete persistence'

    context 'when version conflict raised from bulk persistence' do
      describe '#save' do
        before do
          stub_es_bulk(
            'index' => {
              '_index' => index, '_type' => 'post', '_id' => '123abc',
              'error' => "VersionConflictEngineException: [[#{index}][3] [post][abc123]: version conflict, current[2], required[1]]"
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

      describe '::update' do
        before do
          stub_request_json(
            :get,
            match_es_resource(index, 'post', 'abc123'),
            generate_es_hit('post', :id => 'abc123', :index => index, :version => 1),
            generate_es_hit('post', :id => 'abc123', :index => index, :version => 2, :source => { :title => 'Hey' })
          )
          stub_es_bulk(
            'index' => {
              '_index' => index, '_type' => 'post', '_id' => '123abc',
              'error' => "VersionConflictEngineException: [[#{index}][3] [post][abc123]: version conflict, current[2], required[1]]"
            }
          )
          stub_es_update(index, 'post', 'abc123')

          Elastictastic.bulk do
            scope.update('abc123') do |post|
              post.comments_count = 2
            end
          end
        end

        it 'should make 4 requests' do
          FakeWeb.should have(4).requests
        end

        it 'should send data from block in last request' do
          last_request_json['comments_count'].should == 2
        end

        it 'should send data from most recent version in last request' do
          last_request_json['title'].should == 'Hey'
        end

        it 'should send correct version in last request' do
          last_request_uri.query.split('&').should include('version=2')
        end

        it 'should send last request to correct index' do
          last_request_uri.path.split('/')[1].should == index
        end
      end
    end
  end

  describe 'default scope' do
    let(:scope) { Post }
    let(:index) { 'default' }
    it_should_behave_like 'updatable scope'
  end

  describe 'scoped in index' do
    let(:scope) { Post.in_index('my_index') }
    let(:index) { 'my_index' }
    it_should_behave_like 'updatable scope'
  end
end
