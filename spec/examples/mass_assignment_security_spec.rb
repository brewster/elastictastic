require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::MassAssignmentSecurity do
  let(:post) { Post.new(:title => 'hey guy', :comments_count => 3) }

  it 'should allow allowed attributes' do
    post.title.should == 'hey guy'
  end

  it 'should not allow forbidden attributes' do
    post.comments_count.should be_nil
  end
end
