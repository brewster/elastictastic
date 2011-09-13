require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::BulkPersistenceStrategy do
  include Elastictastic::TestHelpers

  let(:last_request) { FakeWeb.last_request }
  let(:bulk_requests) do
    last_request.body.split("\n").map do |request|
      JSON.parse(request)
    end
  end

  describe 'create without ID' do
    let(:post) { Post.new }

    before do
      stub_elasticsearch_bulk(
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
        post.to_elasticsearch_doc
      ]
    end

    it 'should set ID' do
      post.id.should == '123'
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
        stub_elasticsearch_bulk(
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
  end

  describe 'creating multiple' do
    let(:posts) { Array.new(2) { Post.new }}

    before do
      stub_elasticsearch_bulk(
        { 'create' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 1, 'ok' => true }},
        { 'create' => { '_index' => 'default', '_type' => 'post', '_id' => '124', '_version' => 1, 'ok' => true }}
      )
      Elastictastic.bulk { posts.each { |post| post.save }}
    end

    it 'should send both create operations' do
      bulk_requests.should == posts.map do |post|
        [
          { 'create' => { '_index' => 'default', '_type' => 'post' }},
          post.to_elasticsearch_doc
        ]
      end.flatten
    end

    it 'should set IDs' do
      posts.map { |post| post.id }.should == %w(123 124)
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
      stub_elasticsearch_bulk(
        'create' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 1, 'ok' => true }
      )
      Elastictastic.bulk { post.save }
    end

    it 'should send ID in request to create' do
      bulk_requests.should == [
        { 'create' => { '_index' => 'default', '_type' => 'post', '_id' => '123' }},
        post.to_elasticsearch_doc
      ]
    end

    it 'should set object persistent' do
      post.should be_persisted
    end

    it 'should retain ID' do
      post.id.should == '123'
    end
  end

  describe 'destroy' do
    let(:post) do
      Post.new.tap do |post|
        post.id = '123'
        post.title = 'bulky'
        post.persisted!
      end
    end

    before do
      stub_elasticsearch_bulk(
        'destroy' => { '_index' => 'default', '_type' => 'post', '_id' => '123', '_version' => 1, 'ok' => true }
      )
      Elastictastic.bulk { post.destroy }
    end

    it 'should send destroy' do
      bulk_requests.should == [
        { 'delete' => { '_index' => 'default', '_type' => 'post', '_id' => '123' }}
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
      stub_elasticsearch_create('default', 'post')
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

  describe 'raising CancelBulkOperation' do
    let :error_proc do
      lambda do
        Elastictastic.bulk do
          Post.new.save
          raise Elastictastic::CancelBulkOperation
        end
      end
    end

    it 'should not propagate error' do
      expect(&error_proc).not_to raise_error
    end

    it_should_behave_like 'block with error'
  end
end
