require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::BulkPersistenceStrategy do
  include Elastictastic::TestHelpers

  let(:last_request) { FakeWeb.last_request }
  let(:bulk_requests) do
    last_request.body.split("\n").map do |request|
      Elastictastic.json_decode(request)
    end
  end

  describe 'create without ID' do
    let(:post) { Post.new }

    before do
      stub_es_bulk(
        'create' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 1, 'ok' => true }
      )
      Elastictastic.bulk do
        post.title = 'Bulky'
        post.save
      end
    end

    it 'should send bulk request' do
      last_request.path.should == '/_bulk'
    end

    it 'should send index operation' do
      bulk_requests.should == [
        { 'create' => { '_index' => 'default', '_type' => 'post' }},
        post.elasticsearch_doc
      ]
    end

    it 'should set ID' do
      post.id.should == '123'
    end

    it 'should set version' do
      post.version.should == 1
    end

    it 'should set persisted' do
      post.should be_persisted
    end

    it 'should have final newline' do
      last_request.body[-1].should == "\n"
    end
  end

  describe 'before bulk operation completes' do
    let(:post) { Post.new }

    around do |example|
      Elastictastic.bulk do
        example.run
        # have to do this here because the before/after hooks run inside the
        # around hook
        stub_es_bulk(
          'create' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 1, 'ok' => true }
        )
      end
    end

    it 'should not set ID' do
      post.save
      post.id.should be_nil
    end

    it 'should not set persisted' do
      post.should be_transient
    end

    it 'should not allow you to call save again on transient document' do
      post.save
      expect { post.save }.to raise_error(Elastictastic::OperationNotAllowed)
    end
  end

  describe 'creating multiple' do
    let(:posts) { Array.new(2) { Post.new }}

    before do
      stub_es_bulk(
        { 'create' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 1, 'ok' => true }},
        { 'create' => { '_index' => 'default', '_type' => 'post', '_id' => '124', '_version' => 1, 'ok' => true }}
      )
      Elastictastic.bulk { posts.each { |post| post.save }}
    end

    it 'should send both create operations' do
      bulk_requests.should == posts.map do |post|
        [
          { 'create' => { '_index' => 'default', '_type' => 'post' }},
          post.elasticsearch_doc
        ]
      end.flatten
    end

    it 'should set IDs' do
      posts.map { |post| post.id }.should == %w(123 124)
    end

    it 'should set versions' do
      posts.each { |post| post.version.should == 1 }
    end
  end

  describe 'create with ID set' do
    let(:post) do
      Post.new.tap do |post|
        post.id = '123'
        post.title = 'bulky'
      end
    end

    before do
      stub_es_bulk(
        'create' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 1, 'ok' => true }
      )
      Elastictastic.bulk { post.save }
    end

    it 'should send ID in request to create' do
      bulk_requests.should == [
        { 'create' => { '_index' => 'default', '_type' => 'post', '_id' => '123' }},
        post.elasticsearch_doc
      ]
    end

    it 'should set object persistent' do
      post.should be_persisted
    end

    it 'should retain ID' do
      post.id.should == '123'
    end

    it 'should set version' do
      post.version.should == 1
    end
  end

  describe '#update' do
    let(:post) do
      Post.new.tap do |post|
        post.id = '123'
        post.version = 1
        post.persisted!
      end
    end

    before do
      stub_es_bulk(
        'index' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 2, 'ok' => true }
      )
      Elastictastic.bulk { post.save }
    end

    it 'should send update' do
      bulk_requests.should == [
        { 'index' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 1 }},
        post.elasticsearch_doc
      ]
    end

    it 'should set version' do
      post.version.should == 2
    end
  end

  describe 'destroy' do
    let(:post) do
      Post.new.tap do |post|
        post.id = '123'
        post.title = 'bulky'
        post.version = 1
        post.persisted!
      end
    end

    before do
      stub_es_bulk(
        'delete' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 2, 'ok' => true }
      )
      Elastictastic.bulk { post.destroy }
    end

    it 'should send destroy' do
      bulk_requests.should == [
        { 'delete' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 1 }}
      ]
    end

    it 'should mark record as not persistent' do
      post.should_not be_persisted
    end
  end

  shared_examples_for 'block with error' do
    it 'should not run bulk operation' do
      error_proc.call rescue nil
      last_request.should_not be
    end

    it 'should return to individual persistence strategy' do
      error_proc.call rescue nil
      stub_es_create('default', 'post')
      Post.new.save
      last_request.path.should == '/default/post'
    end
  end

  describe 'with uncaught exception raised' do
    let :error_proc  do
      lambda do
        Elastictastic.bulk do
          Post.new.save
          raise
        end
      end
    end

    it 'should propagate error up' do
      expect(&error_proc).to raise_error(RuntimeError)
    end

    it_should_behave_like 'block with error'
  end

  describe 'with :auto_flush specified' do
    before do
      responses = Array.new(3) do
        { 'create' => generate_es_hit('post').except('_source').merge('ok' => true) }
      end.each_slice(2).map { |slice| { 'items' => slice } }
      stub_request_json(
        :post,
        match_es_path('/_bulk'),
        *responses
      )
      Elastictastic.bulk(:auto_flush => 2) { 3.times { Post.new.save }}
    end

    it 'should perform multiple requests when auto-flush triggered' do
      FakeWeb.should have(2).requests
    end

    it 'should flush after specified number of operations' do
      FakeWeb.requests.first.body.split("\n").should have(4).items
      FakeWeb.requests.last.body.split("\n").should have(2).items
    end
  end

  describe 'multiple operations on the same document' do
    let(:post) do
      Post.new.tap do |post|
        post.id = '1'
        post.version = 1
        post.persisted!
      end
    end

    before do
      stub_es_bulk(
        'delete' => generate_es_hit('post', :version => 2, :id => '1').merge('ok' => true)
      )
      Elastictastic.bulk do
        post.save
        post.destroy
      end
    end

    it 'should only send one operation per document' do
      bulk_requests.length.should == 1
    end

    it 'should send last operation for each document' do
      bulk_requests.last.should ==  { 'delete' => generate_es_hit('post', :id => '1').except('_source') }
    end
  end

  describe 'multiple creates' do
    before do
      stub_es_bulk(
        { 'create' => generate_es_hit('post', :id => '1').merge('ok' => true) },
        { 'create' => generate_es_hit('post', :id => '2').merge('ok' => true) }
      )
      Elastictastic.bulk { 2.times { |i| Post.new(:title => "post #{i}").save }}
    end

    it 'should create all documents' do
      bulk_requests.length.should == 4
    end

    it 'should send correct info for each document' do
      bulk_requests.each_slice(2).map do |commands|
        commands.last['title']
      end.should == ['post 0', 'post 1']
    end
  end

  describe 'updating documents with same ID but different index' do
    let(:posts) do
      %w(default my_index).map do |index|
        Post.in_index(index).new.tap do |post|
          post.id = '1'
          post.persisted!
        end
      end
    end

    before do
      stub_es_bulk(
        { 'index' => generate_es_hit('post', :id => '1').merge('ok' => true) },
        { 'index' => generate_es_hit('post', :index => 'my_index', :id => '1').merge('ok' => true) }
      )
      Elastictastic.bulk { posts.map { |post| post.save }}
    end

    it 'should send updates for both documents' do
      bulk_requests.length.should == 4
    end
  end
end
