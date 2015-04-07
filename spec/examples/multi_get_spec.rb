require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::MultiGet do
  include Elastictastic::TestHelpers

  let(:last_request_body) { Elastictastic.json_decode(last_request.body) }

  before do
    stub_es_mget(
      nil,
      nil,
      ['1', 'post', 'default'], ['2', 'post', 'my_index'], ['3', 'post', 'my_index'],
      ['4', 'post', 'my_index'] => nil
    )
  end

  describe 'with no options' do
    let!(:posts) do
      Elastictastic.multi_get do |mget|
        mget.add(Post, 1)
        mget.add(Post.in_index('my_index'), 2, 3, 4)
      end
    end

    it 'should send request to base path' do
      last_request.path.should == '/_mget'
    end

    it 'should request ids with type and index' do
      last_request_body.should == {
        'docs' => [{
        '_id' => '1',
        '_type' => 'post',
        '_index' => 'default'
      }, {
        '_id' => '2',
        '_type' => 'post',
        '_index' => 'my_index'
      }, {
        '_id' => '3',
        '_type' => 'post',
        '_index' => 'my_index'
      }, {
        '_id' => '4',
        '_type' => 'post',
        '_index' => 'my_index'
      }]
      }
    end

    it 'should return existing docs with IDs' do
      posts.map(&:id).should == %w(1 2 3)
    end

    it 'should set proper indices' do
      posts.map { |post| post.index.name }.should ==
        %w(default my_index my_index)
    end
  end # context 'with no options' 

  context 'with fields specified' do
    let!(:posts) do
      Elastictastic.multi_get do |mget|
        mget.add(Post.fields('title'), '1')
        mget.add(Post.in_index('my_index').fields('title'), '2', '3')
      end
    end

    it 'should inject fields into each identifier' do
      last_request_body.should == {
        'docs' => [{
        '_id' => '1',
        '_type' => 'post',
        '_index' => 'default',
        'fields' => %w(title)
      }, {
        '_id' => '2',
        '_type' => 'post',
        '_index' => 'my_index',
        'fields' => %w(title)
      }, {
        '_id' => '3',
        '_type' => 'post',
        '_index' => 'my_index',
        'fields' => %w(title)
      }]
      }
    end
  end

  context 'with routing specified' do
    let!(:posts) do
      Elastictastic.multi_get do |mget|
        mget.add(Post.routing('foo'), '1')
        mget.add(Post.in_index('my_index').routing('bar'), '2', '3')
      end
    end

    it 'should inject fields into each identifier' do
      last_request_body.should == {
        'docs' => [{
        '_id' => '1',
        '_type' => 'post',
        '_index' => 'default',
        'routing' => 'foo'
      }, {
        '_id' => '2',
        '_type' => 'post',
        '_index' => 'my_index',
        'routing' => 'bar'
      }, {
        '_id' => '3',
        '_type' => 'post',
        '_index' => 'my_index',
        'routing' => 'bar'
      }]
      }
    end
  end

  context 'with preference specified' do
    let!(:posts) do
      Elastictastic.multi_get do |mget|
        mget.add(Post.preference('_primary'), '1')
        mget.add(Post.in_index('my_index').preference('_primary'), '2', '3')
      end
    end

    it 'should inject fields into each identifier' do
      last_request_body.should == {
          'docs' => [{
                         '_id' => '1',
                         '_type' => 'post',
                         '_index' => 'default',
                         'preference' => '_primary'
                     }, {
                         '_id' => '2',
                         '_type' => 'post',
                         '_index' => 'my_index',
                         'preference' => '_primary'
                     }, {
                         '_id' => '3',
                         '_type' => 'post',
                         '_index' => 'my_index',
                         'preference' => '_primary'
                     }]
      }
    end
  end

  context 'with no docspecs given' do
    it 'should gracefully return nothing' do
      FakeWeb.clean_registry
      Elastictastic.multi_get {}.to_a.should == []
    end
  end
end
