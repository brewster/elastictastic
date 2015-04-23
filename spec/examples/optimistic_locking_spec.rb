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

    let(:post_changed?) { true }

    before do
      post.stub(:changed?) { post_changed? }
    end

    context 'when save is cancelled' do
      before do
        stub_request_json(
          :get,
          match_es_resource(index, 'post', '123abc'),
          generate_es_hit('post', :id => '123abc', :index => index, :version => 1).merge('found' => true),
          generate_es_hit('post', :id => '123abc', :index => index, :version => 2, :source => { :title => 'Hey' }).merge('found' => true)
        )
      end

      describe '::update' do
        before do
          scope.update('123abc') do
            raise Elastictastic::CancelSave
          end
        end

        it 'should have 1 request for fetch' do
          FakeWeb.should have(1).requests # 1 for fetch
        end
      end

      describe '::create_or_update' do
        before do
          scope.create_or_update('123abc') do
            raise Elastictastic::CancelSave
          end
        end

        it 'should make no requests' do
          FakeWeb.should have(0).requests
        end
      end
    end

    context 'when version conflict raised from discrete persistence' do
      describe '#save' do
        before do
          stub_request_json(
            :put,
            match_es_resource(index, 'post', '123abc'),
            version_conflict
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
            generate_es_hit('post', :id => '123abc', :index => index, :version => 2, :source => { :title => 'Hey' }).merge('found' => true)
          )
          stub_request_json(
            :put,
            match_es_resource(index, 'post', '123abc'),
            version_conflict,
            generate_es_hit('post', :id => '123abc', :version => 3, :index => index)
          )
          scope.update('123abc') do |post|
            post.comments_count = 3
          end
        end

        it 'should make four requests' do
          FakeWeb.should have(4).requests
        end

        it 'should add preference=_primary to get request' do
          URI.parse(FakeWeb.requests.first.path).query.split('&').
            should include('preference=_primary_first')
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

      describe '::update with multiple arguments' do
        let(:last_update_request) do
          FakeWeb.requests.reverse.find { |req| req.method == 'PUT' }
        end

        before do
          stub_es_mget(
            index,
            'post',
            '1' => {},
            '2' => {}
          )
          stub_es_get(index, 'post', '2', { :title => 'Hey' }, 2)
          stub_es_update(index, 'post', '1')
          stub_request_json(
            :put,
            match_es_resource(index, 'post', '2'),
            version_conflict,
            generate_es_hit('post', :id => '2', :index => index, :version => 3)
          )
          scope.update('1', '2') do |post|
            post.comments_count = 2
          end
        end

        it 'should retry unsuccessful updates' do
          FakeWeb.should have(5).requests # mget, update '1', update '2' (fail), get '2', update '2'
        end

        it 'should re-perform update on failed document' do
          URI.parse(last_update_request.path).path.should == "/#{index}/post/2"
        end

        it 'should send data from latest version in persistence' do
          Elastictastic.json_decode(last_update_request.body)['title'].should == 'Hey'
        end

        it 'should send data from update block' do
          Elastictastic.json_decode(last_update_request.body)['comments_count'].should == 2
        end

        it 'should update with latest version' do
          URI.parse(last_update_request.path).query.split('&').should include('version=2')
        end
      end # describe '::update with multiple requests'

      describe '::update_each' do
        let(:last_update_request) do
          FakeWeb.requests.reverse.find { |req| req.method == 'PUT' }
        end

        before do
          stub_es_scan(
            index, 'post', 100,
            generate_es_hit('post', :index => index, :id => '1'),
            generate_es_hit('post', :index => index, :id => '2')
          )
          stub_es_get(index, 'post', '2', { :title => 'Hey' }, 2)
          stub_es_update(index, 'post', '1')
          stub_request_json(
            :put,
            match_es_resource(index, 'post', '2'),
            version_conflict,
            generate_es_hit('post', :id => '2', :index => index, :version => 3)
          )
          scope.update_each do |post|
            post.comments_count = 2
          end
        end

        it 'should retry unsuccessful updates' do
          FakeWeb.should have(7).requests # initiate scan, 2 cursors, update '1', update '2' (fail), get '2', update '2'
        end

        it 'should re-perform update on failed document' do
          URI.parse(last_update_request.path).path.should == "/#{index}/post/2"
        end

        it 'should send data from latest version in persistence' do
          Elastictastic.json_decode(last_update_request.body)['title'].should == 'Hey'
        end

        it 'should send data from update block' do
          Elastictastic.json_decode(last_update_request.body)['comments_count'].should == 2
        end

        it 'should update with latest version' do
          URI.parse(last_update_request.path).query.split('&').should include('version=2')
        end
      end # describe '::update_each'
    end # context 'when version conflict raised from discrete persistence'

    context 'when version conflict raised from bulk persistence' do
      describe '#save' do
        before do
          stub_es_bulk(
            'index' => {
              '_index' => index, '_type' => 'post', '_id' => '123abc',
              'error' => version_conflict['error']
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
              'error' => version_conflict['error']
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
      end # describe '::update'

      describe '::update_each' do
        before do
          stub_es_scan(
            index, 'post', 100,
            generate_es_hit('post', :index => index, :id => '1'),
            generate_es_hit('post', :index => index, :id => '2')
          )
          stub_request_json(
            :post,
            match_es_path('/_bulk'),
            'items' => [
              { 'index' => generate_es_hit('post', :index => index, :id => '1').except('_source').merge('ok' => true) },
              { 'index' => generate_es_hit('post', :index => index, :id => '2').except('_source').merge(version_conflict.slice('error')) }
            ]
          )
          stub_es_get(index, 'post', '2', { 'title' => 'Hey' }, 2)
          stub_es_update(index, 'post', '2', 3)
          Elastictastic.bulk do 
            scope.update_each { |post| post.comments_count = 2 }
          end
        end

        it 'should retry failed update' do
          FakeWeb.should have(6).requests # start scan, 2 cursor reads, bulk update, reload '2', update '2'
        end

        it 'should update failed document' do
          last_request_uri.path.should == "/#{index}/post/2"
        end

        it 'should update conflicted document with reloaded data' do
          last_request_json['title'].should == 'Hey'
        end

        it 'should update conflicted document with data from block' do
          last_request_json['comments_count'].should == 2
        end

        it 'should update conflicted document with proper version' do
          last_request_uri.query.split('&').should include('version=2')
        end
      end
    end # context 'when version conflict raised from bulk persistence'
  end # shared_examples_for 'updatable scope'

  describe 'default scope' do
    let(:scope) { Post }
    let(:index) { 'default' }
    let :version_conflict do
      {
        'error' => "VersionConflictEngineException: [[#{index}][3] [post][abc123]: version conflict, current[2], required[1]]",
        'status' => 409
      }
    end
    it_should_behave_like 'updatable scope'
  end

  describe 'scoped in index' do
    let(:scope) { Post.in_index('my_index') }
    let(:index) { 'my_index' }
    let :version_conflict do
      {
        'error' => "VersionConflictEngineException: [[#{index}][3] [post][abc123]: version conflict, current[2], required[1]]",
        'status' => 409
      }
    end
    it_should_behave_like 'updatable scope'
  end

  describe 'default scope with nested exception' do
    let(:scope) { Post }
    let(:index) { 'default' }
    let(:version_conflict) do
      {
        'error' => "RemoteTransportException: [[server][inet[/ip]][/index]]; nested: VersionConflictEngineException[[#{index}][0] [[post][abc123]: version conflict, current [2], required [1]]",
        'status' => 409
      }
    end
    it_should_behave_like 'updatable scope'
  end

  describe 'scoped in index with nested exception' do
    let(:scope) { Post.in_index('my_index') }
    let(:index) { 'my_index' }
    let(:version_conflict) do
      {
        'error' => "RemoteTransportException: [[server][inet[/ip]][/index]]; nested: VersionConflictEngineException[[#{index}][0] [[post][abc123]: version conflict, current [2], required [1]]",
        'status' => 409
      }
    end
    it_should_behave_like 'updatable scope'
  end

  context '::update called on nonexistent document' do
    before do
      stub_es_get('default', 'post', '1', nil)
    end

    it 'should not do anything' do
      expect { Post.update('1') { |post| post.title = 'bogus' }}.to_not raise_error
    end
  end

  describe '::create_or_update' do
    let :already_exists do
      {
        'error' => 'DocumentAlreadyExistsEngineException: [[my_index][2] [post][1]: document already exists]',
        'status' => 409
      }
    end

    let :version_conflict do
      {
        'error' => "VersionConflictEngineException: [[my_index][3] [post][1]: version conflict, current[2], required[1]]",
        'status' => 409
      }
    end

    context 'with discrete persistence' do
      context "when document doesn't already exist" do
        before do
          stub_es_create('my_index', 'post', '1')
          Post.in_index('my_index').create_or_update('1') { |post| post.title = 'hey' }
        end

        it 'should post to create endpoint' do
          last_request.path.should == '/my_index/post/1/_create'
        end

        it 'should yield before saving' do
          last_request_json['title'].should == 'hey'
        end
      end

      context "when document already exists" do
        before do
          stub_request_json(
            :put,
            match_es_path('/my_index/post/1/_create'),
            already_exists
          )
          stub_es_get('my_index', 'post', '1', :comments_count => 2)
          stub_es_update('my_index', 'post', '1')
          Post.in_index('my_index').create_or_update('1') { |post| post.title = 'hey' }
        end

        it 'should re-update data with correct version' do
          last_request.path.should == '/my_index/post/1?version=1'
        end

        it 'should include data from storage' do
          last_request_json['comments_count'].should == 2
        end

        it 'should include updated data from block' do
          last_request_json['title'].should == 'hey'
        end
      end

      context "with multiple arguments some of which exist" do
        before do
          stub_es_create('my_index', 'post', '1')
          stub_request_json(
            :put,
            match_es_path('/my_index/post/2/_create'),
            already_exists
          )
          stub_es_get('my_index', 'post', '2', :comments_count => 2)
          stub_es_update('my_index', 'post', '2')
          Post.in_index('my_index').create_or_update('1', '2') do |post|
            post.title = "hey #{post.id}"
          end
        end

        it 'should post to create endpoint for both documents' do
          FakeWeb.requests.
            should be_any { |request| request.path == '/my_index/post/1/_create' }
          FakeWeb.requests.
            should be_any { |request| request.path == '/my_index/post/2/_create' }
        end

        it 'should not send update request for successful create' do
          FakeWeb.requests.
            should_not be_any { |request| request.path == '/my_index/post/1?version=1' }
        end

        it 'should re-update existing data with correct version' do
          last_request.path.should == '/my_index/post/2?version=1'
        end

        it 'should include data from storage' do
          last_request_json['comments_count'].should == 2
        end

        it 'should include updated data from block' do
          last_request_json['title'].should == 'hey 2'
        end
      end
    end

    context 'with bulk persistence' do
      context 'when document already exists' do
        before do
          stub_es_bulk(
            'create' => {
              '_index' => 'my_index', '_type' => 'post', '_id' => '1',
              'error' => already_exists['error']
            }
          )
          stub_es_get('my_index', 'post', '1', 'comments_count' => 2)
          stub_es_update('my_index', 'post', '1')
          Elastictastic.bulk { Post.in_index('my_index').create_or_update('1') { |post| post.title = 'hey' } }
        end

        it 'should send update' do
          last_request.path.should == '/my_index/post/1?version=1'
        end

        it 'should send data from existing document' do
          last_request_json['comments_count'].should == 2
        end

        it 'should send data from block' do
          last_request_json['title'].should == 'hey'
        end
      end
    end
  end

  describe '::update_or_create' do
    let(:scope) { Post }

    before do
      stub_es_mget(
        'default', 'post',
        '1' => {title: 'Post 1'},
        '2' => nil
      )
      stub_es_update('default', 'post', '1')
      stub_es_create('default', 'post', '2')
      scope.update_or_create('1', '2') do |post|
        post.comments_count = 1
      end
    end

    let :create_request do
      FakeWeb.requests.
        find { |request| request.path == "/default/post/2/_create" }
    end

    let :update_request do
      FakeWeb.requests.
        find { |request| request.path =~ %r(^/default/post/1\??) }
    end

    it 'should not send any extraneous requests' do
      FakeWeb.should have(3).requests # multiget, create, update
    end

    it 'should send create request for nonexistent document' do
      create_request.should be
    end

    it 'should send update request for existent document' do
      update_request.should be
    end
  end

end
