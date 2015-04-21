require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::ParentChild do
  include Elastictastic::TestHelpers

  describe 'mappings' do
    it 'should put _parent in mapping' do
      Post.mapping['post']['_parent'].should == { 'type' => 'blog' }
    end
  end

  describe 'child instance' do
    let(:post) { blog.posts.new }
    let(:blog) do
      stub_es_create('default', 'blog')
      Blog.new.tap { |blog| blog.save }
    end

    it 'should set parent' do
      blog.posts.new.blog.should == blog
    end

    it 'should set parent when creating via class method' do
      blog.posts.from_hash('title' => 'hey').blog.should == blog
    end

    describe 'when retrieved directly' do
      let(:post) { Post.in_index('my_index').fields('_source', '_parent').first }

      before do
        stub_es_search(
          'my_index', 'post',
          'hits' => {
            'total' => 1,
            'hits' => [{
              '_id' => '2',
              '_type' => 'post',
              '_index' => 'my_index',
              '_source' => {},
              'fields' => { '_parent' => '1' }
            }]
          }
        )

        stub_es_get(
          'my_index', 'blog', '1',
          { 'name' => 'Awesome Blog' }
        )
      end

      it 'should retrieve parent via GET' do
        post.blog.name.should == 'Awesome Blog'
      end

      it 'should lookup in correct index' do
        post.blog
        FakeWeb.last_request.path.split('?').first.should == '/my_index/blog/1'
      end
    end

    describe 'discrete persistence' do
      it 'should pass parent param on create' do
        stub_es_create('default', 'post')
        post.save
        URI.parse(FakeWeb.last_request.path).query.should == "parent=#{blog.id}"
      end

      it 'should pass parent param on update' do
        stub_es_create('default', 'post')
        post.save
        stub_es_update('default', 'post', post.id)
        post.save
        URI.parse(FakeWeb.last_request.path).query.split('&').should include("parent=#{blog.id}")
      end

      it 'should pass parent on delete' do
        stub_es_create('default', 'post')
        post = blog.posts.new
        post.save
        stub_es_destroy('default', 'post', post.id)
        post.destroy
        URI.parse(FakeWeb.last_request.path).query.split('&').should include("parent=#{blog.id}")
      end

      it 'should pass parent on ::delete' do
        stub_es_destroy('default', 'post', '123')
        blog.posts.destroy('123')
        URI.parse(FakeWeb.last_request.path).query.split('&').should include("parent=#{blog.id}")
      end
    end

    describe 'bulk persistence' do
      let(:bulk_requests) do
        FakeWeb.last_request.body.split("\n").map do |line|
          Elastictastic.json_decode(line)
        end
      end

      before do
        stub_es_bulk
      end

      it 'should pass parent param on create' do
        post = blog.posts.new
        Elastictastic.bulk { post.save }
        bulk_requests.first.should == {
          'create' => {
            '_index' => 'default', '_type' => 'post', 'parent' => blog.id
          }
        }
      end

      it 'should pass parent param on update' do
        post = blog.posts.new
        post.id = '1'
        post.persisted!
        post.stub(:changed?) { true }
        Elastictastic.bulk { post.save }
        bulk_requests.first.should == {
          'index' => {
            '_index' => 'default',
            '_type' => 'post',
            '_id' => '1',
            'parent' => blog.id
          }
        }
      end

      it 'should pass parent param on delete' do
        post = blog.posts.new
        post.id = '1'
        post.persisted!
        Elastictastic.bulk { post.destroy }
        bulk_requests.first.should == {
          'delete' => {
            '_index' => 'default',
            '_type' => 'post',
            '_id' => '1',
            'parent' => blog.id
          }
        }
      end
    end

    it 'should set index' do
      stub_es_create('my_index', 'blog')
      blog = Blog.in_index('my_index').new
      blog.save
      post = blog.posts.new
      post.index.name.should == 'my_index'
    end
  end

  describe 'collection proxies' do
    let(:blog) do
      stub_es_create('my_index', 'blog')
      Blog.in_index('my_index').new.tap { |blog| blog.save }
    end
    let(:posts) { blog.posts }

    it 'should by default scope query to the parent' do
      posts.params.should == { 'query' => { 'constant_score' => { 'filter' => { 'term' => { '_parent' => blog.id }}}}}
    end

    it 'should filter existing query' do
      posts.query { query_string(:query => 'bacon') }.params['query'].should ==
        {
          'filtered' => {
            'query' => { 'query_string' => { 'query' => 'bacon' }},
            'filter' => { 'term' => { '_parent' => blog.id }}
          }
        }
    end

    it 'should retain other parts of scope' do
      scope = posts.size(10)
      scope.params['size'].should == 10
    end

    it 'should search correct index' do
      stub_es_scan('my_index', 'post', 100, { '_id' => '1' })
      posts.to_a.first.id.should == '1'
    end

    it 'should set routing to parent ID on get' do
      stub_es_get('my_index', 'post', 1)
      blog.posts.find(1)
      URI.parse(FakeWeb.last_request.path).query.should == "routing=#{blog.id}"
    end

    it 'should set routing to parent ID on multiget' do
      stub_es_mget('my_index', 'post')
      blog.posts.find(1, 2)
      Elastictastic.json_decode(FakeWeb.last_request.body).should == {
        'docs' => [
          { '_id' => 1, 'routing' => blog.id },
          { '_id' => 2, 'routing' => blog.id }
        ]
      }
    end

    it 'should save transient instances when parent is saved' do
      post = posts.new
      stub_es_update('my_index', 'blog', blog.id)
      stub_es_create('my_index', 'post')
      blog.save
      post.should be_persisted
    end

    it 'should not attempt to save transient instances that are pending for save in a bulk block' do
      stub_es_bulk(
        { 'create' => { '_index' => 'my_index', '_type' => 'post', '_id' => '123', '_version' => 1, 'ok' => true }},
        { 'index' => { '_index' => 'my_index', '_type' => 'blog', '_id' => blog.id, '_version' => 2, 'ok' => true }}
      )
      post = blog.posts.new
      post.stub(:changed?) { true }
      blog.stub(:changed?) { true }
      Elastictastic.bulk do
        post.save
        blog.save
      end
      request_statements =
        FakeWeb.last_request.body.each_line.map { |line| Elastictastic.json_decode(line) }
      request_statements.length.should == 4
    end

    it 'should not save transient instances again' do
      post = posts.new
      stub_es_update('my_index', 'blog', blog.id)
      stub_es_create('my_index', 'post')
      blog.save
      FakeWeb.clean_registry
      stub_es_update('my_index', 'blog', blog.id)
      expect { blog.save }.to_not raise_error
    end

    it 'should populate parent when finding one' do
      stub_es_get('my_index', 'post', '1')
      blog.posts.find('1').blog.should == blog
    end

    it 'should populate parent when finding many' do
      stub_es_mget('my_index', 'post', '1', '2')
      blog.posts.find('1', '2').each do |post|
        post.blog.should == blog
      end
    end

    it 'should populate parent when retrieving first' do
      stub_es_search(
        'my_index', 'post',
        'total' => 1,
        'hits' => { 'hits' => [{ '_id' => '2', 'index' => 'my_index', '_type' => 'post' }]}
      )
      blog.posts.first.blog.id.should == blog.id
    end

    it 'should populate parent when iterating over cursor' do
      stub_es_scan(
        'my_index', 'post', 100,
        '_id' => '1'
      )
      blog.posts.to_a.first.blog.should == blog
    end

    it 'should populate parent when paginating' do
      stub_es_search(
        'my_index', 'post',
        'hits' => {
          'total' => 1,
          'hits' => [{ '_id' => '1', '_type' => 'post', '_index' => 'my_index' }]
        }
      )
      blog.posts.from(0).to_a.first.blog.should == blog
    end

    it 'should iterate over transient instances along with retrieved results' do
      stub_es_scan('my_index', 'post', 100, '_id' => '1')
      post = blog.posts.new
      posts = blog.posts.to_a
      posts[0].id.should == '1'
      posts[1].should == post
    end

    it 'should iterate over only transient instances if parent is transient' do
      blog = Blog.new
      post = blog.posts.new
      blog.posts.to_a.should == [post]
    end

    it 'should return transient instance as #first if no persisted results' do
      stub_es_search(
        'my_index', 'post', 'hits' => { 'total' => 0, 'hits' => [] })
      post = blog.posts.new
      blog.posts.first.should == post
    end

    describe '#<<' do
      let(:post) { Post.new }

      before do
        blog.posts << post
      end

      it 'should set parent of child object' do
        post.blog.should == blog
      end

      it 'should not allow setting of a different parent' do
        blog2 = Blog.new
        expect { blog2.posts << post }.to raise_error(
          Elastictastic::IllegalModificationError)
      end

      it 'should not allow setting of parent on already-persisted object' do
        post = Post.new
        post.persisted!
        expect { blog.posts << post }.to raise_error(
          Elastictastic::IllegalModificationError)
      end
    end
  end

  describe 'searching children directly' do
    before do
      stub_es_search(
        'default', 'post',
        'hits' => {
          'hits' => [
            {
              '_id' => '1', '_index' => 'default', '_type' => 'post',
              '_source' => { 'title' => 'hey' },
              'fields' => { '_parent' => '3' }
            }
          ]
        }
      )
    end

    let(:post) { Post.first }

    it 'should provide access to parent' do
      stub_es_get('default', 'blog', '3')
      post.blog.id.should == '3'
    end

    it 'should populate other fields from source' do
      post.title.should == 'hey'
    end

    it 'should save post without dereferencing parent' do
      stub_es_update('default', 'post', post.id)
      post.stub(:changed?) { true }
      post.save
      URI.parse(FakeWeb.last_request.path).query.should == 'parent=3'
    end
  end
end
