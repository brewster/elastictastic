require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Validations do
  include Elastictastic::TestHelpers

  let(:post) { Post.new(:title => 'INVALID') }

  describe 'with invalid data' do
    it 'should not be valid' do
      post.should_not be_valid
    end

    it 'should not persist to ElasticSearch on save' do
      expect { post.save }.to_not raise_error(FakeWeb::NetConnectNotAllowedError)
    end

    it 'should return false for save' do
      post.save.should be_false
    end

    it 'should raise Elastictastic::RecordInvalid for save!' do
      expect { post.save! }.to raise_error(Elastictastic::RecordInvalid)
    end

    it 'should save successfully if validations disabled' do
      stub_es_create('default', 'post')
      post.save(:validate => false)
      FakeWeb.last_request.path.should == '/default/post'
    end
  end

  describe 'with valid data' do
    let(:post) { Post.new }

    before { stub_es_create('default', 'post') }

    it 'should be valid' do
      post.should be_valid
    end

    it 'should persist to ElasticSearch on save' do
      post.save
      FakeWeb.last_request.should be
    end

    it 'should return true from save' do
      post.save.should be_true
    end

    it 'should persist to ElasticSearch without error on save!' do
      post.save!
      FakeWeb.last_request.should be
    end
  end

  context 'with invalid nested document' do
    let(:post) do
      Post.new.tap do |post|
        post.author = Author.new(:name => 'INVALID')
      end
    end

    it 'should not be valid' do
      post.should_not be_valid
    end

    it 'should have an error for author' do
      post.errors['author'].should be
    end
  end
end
