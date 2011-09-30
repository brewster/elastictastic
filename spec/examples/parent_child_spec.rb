require File.expand_path('../spec_helper', __FILE__)

describe 'parent/child relationships' do
  include Elastictastic::TestHelpers

  describe 'mappings' do
    it 'should put _parent in mapping' do
      Post.mapping['post']['_parent'].should == { 'type' => 'blog' }
    end
  end

  describe 'indexing' do
    let(:post) { Post.new.tap { |post| post.blog = blog }}
    let(:blog) do
      stub_elasticsearch_create('default', 'blog')
      Blog.new.tap { |blog| blog.save }
    end

    it 'should add parent as param' do
      stub_elasticsearch_create('default', 'post')
      post.save
      URI.parse(FakeWeb.last_request.path).query.should == "parent=#{blog.id}"
    end
  end
end
