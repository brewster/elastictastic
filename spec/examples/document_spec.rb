require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Document do
  include Elastictastic::TestHelpers

  let(:last_request) { FakeWeb.last_request }
  let(:last_request_body) { Elastictastic.json_decode(last_request.body) }

  describe '#save' do
    context 'new object' do
      let!(:id) { stub_es_create('default', 'post') }
      let(:post) { Post.new }

      before do
        post.title = 'Hot Pasta'
        post.save
      end

      it 'should send POST request' do
        last_request.method.should == 'POST'
      end

      it 'should send to index/type path' do
        last_request.path.should == '/default/post'
      end

      it 'should send document in the body' do
        last_request.body.should == Elastictastic.json_encode(post.elasticsearch_doc)
      end

      it 'should populate ID of model object' do
        post.id.should == id
      end

      it 'should populate version' do
        post.version.should == 1
      end

      it 'should mark object as persisted' do
        post.should be_persisted
      end
    end # context 'new object'

    context 'new object with routing' do
      let!(:id) { stub_es_create('default', 'photo') }
      let(:photo) { Photo.new(:post_id => '123') }

      before do
        photo.save
      end

      it 'should send routing param' do
        last_request_uri.query.split('&').should include('routing=123')
      end
    end

    context 'new object with ID' do
      let(:post) { Post.new.tap { |post| post.id = '123' }}

      context 'with unique id' do
        before do
          stub_es_create('default', 'post', post.id)
          post.save
        end

        it 'should populate version' do
          post.version.should == 1
        end

        it 'should send PUT request' do
          last_request.method.should == 'PUT'
        end

        it 'should send request to _create verb for document resource' do
          last_request.path.should == "/default/post/123/_create"
        end

        it 'should send document in body' do
          last_request.body.should == Elastictastic.json_encode(post.elasticsearch_doc)
        end
      end # context 'with unique ID'

      context 'with duplicate ID' do
        before do
          stub_request_json(
            :put,
            match_es_resource('default', 'post', '123', '_create'),
            'error' => 'DocumentAlreadyExistsEngineException[[post][2] [post][1]]: document already exists',
            'status' => 409
          )
        end

        let(:save) { lambda { post.save }}

        it 'should raise DocumentAlreadyExistsEngineException' do
          expect(&save).to raise_error(Elastictastic::ServerError::DocumentAlreadyExistsEngineException)
        end

        it 'should inject the error message into the exception' do
          expect(&save).to raise_error { |error|
            error.message.should == '[[post][2] [post][1]]: document already exists'
          }
        end

        it 'should inject the status into the exception' do
          expect(&save).to raise_error { |error|
            error.status.should == 409
          }
        end
      end # context 'with duplicate ID'
    end # context 'new object with ID'

    context 'new object with ID with routing' do
      let(:photo) { Photo.new(:id => 'abc', :post_id => '123') }

      it 'should include routing param when saving' do
        stub_es_create('default', 'photo', 'abc')
        photo.save
        last_request_uri.query.split('&').should include('routing=123')
      end
    end

    shared_examples_for 'persisted object' do
      describe 'identity attributes' do
        it 'should not allow setting of ID' do
          lambda { post.id = 'bogus' }.should raise_error(Elastictastic::IllegalModificationError)
        end
      end # describe 'identity attributes'

      describe '#save' do
        before do
          stub_es_update('default', 'post', post.id)
          post.title = 'Fun Factories for Fickle Ferrets'
          post.save
        end

        it 'should send PUT request' do
          last_request.method.should == 'PUT'
        end

        it "should send to document's resource path with version" do
          last_request.path.should == "/default/post/#{post.id}?version=1"
        end

        it "should send document's body in request" do
          last_request.body.should == Elastictastic.json_encode(post.elasticsearch_doc)
        end

        it 'should populate new version' do
          post.version.should == 2
        end
      end # describe '#save'
    end # shared_examples_for 'persisted object'

    context 'object after save' do
      let(:post) do
        stub_es_create('default', 'post')
        Post.new.tap { |post| post.save }
      end

      it_should_behave_like 'persisted object'
    end # context 'object after save'

    context 'existing persisted object' do
      let(:post) do
        Post.new.tap do |post|
          post.id = '123'
          post.version = 1
          post.persisted!
        end
      end

      it_should_behave_like 'persisted object'
    end # context 'existing persisted object'

    context 'persisted object with routing' do
      let(:photo) do
        Photo.new.tap do |photo|
          photo.id = 'abc'
          photo.post_id = '123'
          photo.version = 1
          photo.persisted!
        end
      end

      before do
        stub_es_update('default', 'photo', 'abc')
        photo.save!
      end

      it 'should include routing param' do
        last_request_uri.query.split('&').should include('routing=123')
      end
    end
  end # describe '#save'

  describe '::destroy' do
    context 'with default index and no routing' do
      before do
        stub_es_destroy('default', 'post', '123')
        Post.destroy('123')
      end

      it 'should send DELETE request' do
        last_request.method.should == 'DELETE'
      end

      it 'should send request to document resource path' do
        last_request.path.should == '/default/post/123'
      end
    end # context 'existing persisted object'

    context 'with routing' do
      before do
        stub_es_destroy('default', 'photo', 'abc')
        Photo.routing('123').destroy('abc')
      end

      it 'should include routing param' do
        last_request_uri.query.split('&').should include('routing=123')
      end
    end

    context 'on specified index' do
      before do
        stub_es_destroy('my_index', 'post', '123')
        Post.in_index('my_index').destroy('123')
      end

      it 'should send request to specified index resource' do
        last_request.path.should == '/my_index/post/123'
      end
    end
  end # describe '#destroy'

  describe '#destroy' do
    context 'existing persisted object' do
      let(:post) do
        Post.new.tap do |post|
          post.id = '123'
          post.persisted!
        end
      end

      before do
        stub_es_destroy('default', 'post', '123')
        @result = post.destroy
      end

      it 'should send DELETE request' do
        last_request.method.should == 'DELETE'
      end

      it 'should send request to document resource path' do
        last_request.path.should == '/default/post/123'
      end

      it 'should mark post as non-persisted' do
        post.should_not be_persisted
      end

      it 'should return true' do
        @result.should be_true
      end
    end # context 'existing persisted object'

    context 'persisted object with routing' do
      let(:photo) do
        Photo.new.tap do |photo|
          photo.id = 'abc'
          photo.post_id = '123'
          photo.version = 1
          photo.persisted!
        end
      end

      before do
        stub_es_destroy('default', 'photo', 'abc')
        photo.destroy
      end

      it 'should include routing param' do
        last_request_uri.query.split('&').should include('routing=123')
      end
    end

    context 'transient object' do
      let(:post) { Post.new }

      it 'should raise OperationNotAllowed' do
        expect { post.destroy }.to raise_error(Elastictastic::OperationNotAllowed)
      end
    end # context 'transient object'

    context 'non-existent persisted object' do
      let(:post) do
        Post.new.tap do |post|
          post.id = '123'
          post.persisted!
        end
      end

      before do
        stub_es_destroy(
          'default', 'post', '123',
          'found' => false
        )
        @result = post.destroy
      end

      it 'should return false' do
        @result.should be_false
      end
    end # describe 'non-existent persisted object'
  end # describe '#destroy'

  describe '#reload' do
    context 'with persisted object' do
      let :post do
        Post.new.tap do |post|
          post.id = '1'
          post.title = 'Title'
          post.persisted!
        end
      end

      before do
        stub_es_get('default', 'post', '1', 'title' => 'Title')
        post.title = 'Something'
        post.reload
      end

      it 'should reset changed attributes' do
        post.title.should == 'Title'
      end
    end
  end

  describe '::destroy_all' do
    describe 'with default index' do
      before do
        stub_es_destroy_all('default', 'post')
        Post.destroy_all
      end

      it 'should send DELETE' do
        last_request.method.should == 'DELETE'
      end

      it 'should send to index/type path' do
        last_request.path.should == '/default/post'
      end
    end # describe 'with default index'

    describe 'with specified index' do
      before do
        stub_es_destroy_all('my_index', 'post')
        Post.in_index('my_index').destroy_all
      end

      it 'should send to specified index' do
        last_request.path.should == '/my_index/post'
      end
    end # describe 'with specified index'
  end # describe '::destroy_all'

  describe '::sync_mapping' do
    shared_examples_for 'put mapping' do
      it 'should send PUT request' do
        last_request.method.should == 'PUT'
      end

      it 'should send mapping to ES' do
        last_request.body.should == Elastictastic.json_encode(Post.mapping)
      end
    end # shared_examples_for 'put mapping'

    context 'with default index' do
      before do
        stub_es_put_mapping('default', 'post')
        Post.sync_mapping
      end

      it 'should send to resource path for mapping' do
        last_request.path.should == '/default/post/_mapping'
      end

      it_should_behave_like 'put mapping'
    end # context 'with default index'

    context 'with specified index' do
      before do
        stub_es_put_mapping('my_cool_index', 'post')
        Post.in_index('my_cool_index').sync_mapping
      end

      it 'should send to specified index resource path' do
        last_request.path.should == '/my_cool_index/post/_mapping'
      end

      it_should_behave_like 'put mapping'
    end # context 'with specified index'
  end # describe '::sync_mapping'

  describe '::find' do

    shared_examples_for 'single document lookup' do
      context 'when document is found' do
        before do
          stub_es_get(
            index, 'post', '1',
          )
        end

        it 'should return post instance' do
          post.should be_a(Post)
        end

        it 'should populate version' do
          post.version.should == 1
        end

        it 'should request specified fields if specified' do
          scope.fields('name', 'author.name').find(1)
          last_request.path.should == "/#{index}/post/1?fields=name%2Cauthor.name"
        end

        it 'should return an array if id is passed in single-element array' do
          posts = scope.find([1])
          posts.should be_a(Array)
          posts.first.id.should == '1'
        end
      end

      context 'when document is not found' do
        before do
          stub_es_get(index, 'post', '1', nil)
        end

        it 'should return nil' do
          scope.find(1).should be_nil
        end
      end
    end # shared_examples_for 'single document'

    shared_examples_for 'multi document single index lookup' do

      before do
        stub_es_mget(index, 'post', '1', '2')
        posts
      end

      context 'with no options' do
        let(:posts) { scope.find('1', '2') }

        it 'should send request to index multiget endpoint' do
          last_request.path.should == "/#{index}/post/_mget"
        end

        it 'should ask for IDs' do
          last_request_body.should == {
            'docs' => [{ '_id' => '1'}, { '_id' => '2' }]
          }
        end

        it 'should return documents' do
          posts.map { |post| post.id }.should == %w(1 2)
        end
      end # context 'with no options'

      context 'with fields option provided' do
        let(:posts) { scope.fields('title').find('1', '2') }

        it 'should send fields with each id' do
          last_request_body.should == {
            'docs' => [
              { '_id' => '1', 'fields' => %w(title) },
              { '_id' => '2', 'fields' => %w(title) }
            ]
          }
        end
      end

      context 'with multi-element array passed' do
        let(:posts) { scope.find(%w(1 2)) }

        it 'should request listed elements' do
          last_request_body.should == {
            'docs' => [
              { '_id' => '1' },
              { '_id' => '2' }
            ]
          }
        end
      end
    end # shared_examples_for 'multi document single index lookup'

    context 'with default index' do
      let(:scope) { Post }
      let(:post) { Post.find(1) }
      let(:index) { 'default' }

      it_should_behave_like 'single document lookup'
      it_should_behave_like 'multi document single index lookup'


      context 'when documents are missing' do
        let(:posts) { Post.find('1', '2') }

        before do
          stub_es_mget('default', 'post', '1' => {}, '2' => nil)
        end

        it 'should only return docs that exist' do
          posts.map(&:id).should == ['1']
        end
      end
    end # context 'with default index'

    context 'with specified index' do
      let(:scope) { Post.in_index('my_index') }
      let(:post) { Post.in_index('my_index').find(1) }
      let(:index) { 'my_index' }

      it_should_behave_like 'single document lookup'
      it_should_behave_like 'multi document single index lookup'
    end # context 'with specified index'

    context 'with routing specified' do
      context 'single document lookup' do
        it 'should specify routing' do
          stub_es_get('default', 'photo', 'abc')
          Photo.routing('123').find('abc')
          last_request_uri.query.split('&').should include('routing=123')
        end

        it 'should complain if routing required but not specified' do
          expect { Photo.find('abc') }.
            to raise_error(Elastictastic::MissingParameter)
        end
      end
    end
  end # describe '::find'

  describe '::exists?' do
    it 'should return true if document exists' do
      stub_es_head('my_index', 'post', 1, true)
      Post.in_index('my_index').exists?(1).should be_true
    end

    it 'should return false if document does not exist' do
      stub_es_head('my_index', 'post', 1, false)
      Post.in_index('my_index').exists?(1).should be_false
    end

    it 'should send routing when given' do
      stub_es_head('my_index', 'post', 1, true)
      Post.in_index('my_index').routing('my_route').exists?(1)
      last_request_uri.query.split('&').should include('routing=my_route')
    end
  end

  describe '#elasticsearch_hit=' do
    context 'with full _source' do
      let :post do
        Post.new.tap do |post|
          post.elasticsearch_hit = {
            '_id' => '1',
            '_index' => 'my_index',
            '_version' => 2,
            '_source' => {
              'title' => 'Testy time',
              'tags' => %w(search lucene),
              'author' => { 'name' => 'Mat Brown' },
              'comments' => [
                { 'body' => 'first comment' },
                { 'body' => 'lol' }
              ],
              'created_at' => '2011-09-12T13:27:16.345Z',
              'published_at' => 1315848697123
            }
          }
        end
      end

      it 'should populate id' do
        post.id.should == '1'
      end

      it 'should populate index' do
        post.index.name.should == 'my_index'
      end

      it 'should populate version' do
        post.version.should == 2
      end

      it 'should mark document perisistent' do
        post.should be_persisted
      end

      it 'should populate scalar in document' do
        post.title.should == 'Testy time'
      end

      it 'should populate time from formatted string' do
        post.created_at.should == Time.gm(2011, 9, 12, 13, 27, BigDecimal.new("16.345"))
      end

      it 'should populate time from millis since epoch' do
        post.published_at.should == Time.gm(2011, 9, 12, 17, 31, BigDecimal.new("37.123"))
      end

      it 'should populate array in document' do
        post.tags.should == %w(search lucene)
      end

      it 'should populate embedded field' do
        post.author.name.should == 'Mat Brown'
      end

      it 'should populate array of embedded objects' do
        post.comments.map { |comment| comment.body }.should ==
          ['first comment', 'lol']
      end
    end # context 'with full _source'

    context 'with specified fields' do
      let(:post) do
        Post.new.tap do |post|
          post.elasticsearch_hit = {
            '_id' => '1',
            '_index' => 'my_index',
            '_type' => 'post',
            'fields' => {
              'title' => 'Get efficient',
              '_source.comments_count' => 2,
              '_source.author' => {
                'id' => '1',
                'name' => 'Pontificator',
                'email' => 'pontificator@blogosphere.biz'
              },
              '_source.comments' => [{
                'body' => '#1 fun'
              }, {
                'body' => 'good fortune'
              }]
            }
          }
        end
      end

      it 'should populate scalar from stored field' do
        post.title.should == 'Get efficient'
      end

      it 'should populate scalar from _source' do
        post.comments_count.should == 2
      end

      it 'should populate single-valued embedded object' do
        post.author.name.should == 'Pontificator'
      end

      it 'should populate multi-valued embedded objects' do
        post.comments.map { |comment| comment.body }.should == [
          '#1 fun',
          'good fortune'
        ]
      end
    end

    describe 'with missing values for requested fields' do
      let(:post) do
        Post.new.tap do |post|
          post.elasticsearch_hit = {
            '_id' => '1',
            '_index' => 'my_index',
            'fields' => {
              'title' => nil,
              'author.name' => nil,
              '_source.comments' => nil
            }
          }
        end
      end

      it 'should set scalar from stored field to nil' do
        post.title.should be_nil
      end

      it 'should set embedded field to nil' do
        post.author.should be_nil
      end

      it 'should set object field from source ot nil' do
        post.comments.should be_nil
      end
    end
  end

  describe '#==' do
    it 'should return true if index, id and class of both objects are equal' do
      first_post = Post.new(index: "post", title: "Hello, world!")
      first_post.id = 1
      other_post = Post.new(index: "post", title: "Hello, world!")
      other_post.id = 1

      other_post.should eq first_post
    end

    it 'should fail when classes are not equal' do
      post = Post.new
      post.id = 1
      photo = Photo.new
      photo.id = 1

      photo.should_not eq post
    end
  end
end
