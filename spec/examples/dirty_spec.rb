require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Dirty do
  include Elastictastic::TestHelpers

  let(:post) { Post.new }

  before do
    stub_elasticsearch_create('default', 'post')
  end

  context 'with no attribute changed' do
    it 'should not be changed' do
      post.should_not be_changed
    end

    it 'should not have any changes' do
      post.changes.should be_empty
    end

    it 'should not have the title attribute changed' do
      post.should_not be_title_changed
    end
  end

  context 'with title attribute changed' do
    before do
      post.title = 'hey guy'
    end

    it 'should be changed' do
      post.should be_changed
    end

    it 'should expose change' do
      post.changes[:title].should == [nil, 'hey guy']
    end

    it 'should have the title attribute changed' do
      post.should be_title_changed
    end
  end

  context 'after change and save' do
    before do
      post.title = 'hey guy'
      post.save
    end

    it 'should not be changed' do
      post.should_not be_changed
    end

    it 'should not have any changes' do
      post.changes.should be_empty
    end

    it 'should not have the title attribute changed' do
      post.should_not be_title_changed
    end
  end

  context 'nested attributes' do
    let(:post) do
      Post.new.tap do |post|
        post.elasticsearch_hit = {
          '_id' => '1',
          '_type' => 'post',
          '_index' => 'default',
          '_source' => { 'author' => { 'name' => 'Mat Brown' }}
        }
      end
    end

    before do
      post.author.name = 'Barack Obama'
    end

    it 'should be changed' do
      post.should be_changed
    end

    it 'should mark association as changed' do
      post.changed.should == %w(author)
    end

    it 'should return *_changed? for the association' do
      post.should be_author_changed
    end

    it 'should have change' do
      change = post.changes['author']
      change.map { |author| author.name }.should == ['Mat Brown', 'Barack Obama']
    end
  end
end
