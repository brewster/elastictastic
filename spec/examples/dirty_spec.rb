require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Dirty do
  include Elastictastic::TestHelpers

  let(:post) do
    Post.new.tap do |post|
      post.elasticsearch_hit = {
        '_id' => '1',
        '_type' => 'post',
        '_index' => 'default',
        '_source' => source
      }
    end
  end

  before do
    stub_elasticsearch_update('default', 'post', '1')
  end

  context 'top-level attribute' do
    let(:source) { { 'title' => 'first title' } }

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
        post.changes[:title].should == ['first title', 'hey guy']
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
  end

  context 'single nested document' do
    let(:source) { { 'author' => { 'name' => 'Mat Brown' }} }

    context 'with nothing changed' do
      it 'should not be changed' do
        post.should_not be_changed
      end
    end

    context 'with nested document attribute changed' do
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

      it 'should not be changed after save' do
        post.save
        post.should_not be_changed
      end

      it 'should not have changed nested document after save' do
        post.save
        post.author.should_not be_changed
      end
    end

    context 'with nested document replaced' do
      before do
        post.author = Author.new(:name => 'Barack Obama')
      end

      it 'should be changed' do
        post.should be_changed
      end

      it 'should expose changes' do
        post.changes['author'].map { |author| author.name }.should ==
          ['Mat Brown', 'Barack Obama']
      end
    end
  end

  context 'nested document collection' do
    let(:source) { { 'comments' => [{ 'body' => 'I like pizza' }] } }

    let(:mapped_changes) do
      post.changes['comments'].map do |change|
        change.map { |comment| comment.body }
      end
    end

    context 'with nothing changed' do
      it 'should not be changed' do
        post.should_not be_changed
      end
    end

    context 'when document changed' do
      before do
        post.comments.first.body = 'I like lasagne'
      end

      it 'should be changed' do
        post.should be_changed
      end

      it 'should expose changed document' do
        mapped_changes.should == [['I like pizza'], ['I like lasagne']]
      end

      it 'should not be changed after save' do
        post.save
        post.should_not be_changed
      end

      it 'should not have changed nested document after save' do
        post.save
        post.comments.first.should_not be_changed
      end
    end

    context 'when document added' do
      before do
        post.comments << Comment.new(:body => 'Lasagne is better')
      end

      it 'should be changed' do
        post.should be_changed
      end

      it 'should expose new document' do
        mapped_changes.should == [
          ['I like pizza'],
          ['I like pizza', 'Lasagne is better']
        ]
      end

      it 'should not be changed after save' do
        post.save
        post.should_not be_changed
      end

      it 'should not have changed nested documents after save' do
        post.save
        post.comments.each { |comment| comment.should_not be_changed }
      end
    end

    context 'when document removed' do
      before do
        post.comments.delete(post.comments.first)
      end

      it 'should be changed' do
        post.should be_changed
      end

      it 'should show changes' do
        mapped_changes.should == [['I like pizza'], []]
      end

      it 'should not be changed after save' do
        post.save
        post.should_not be_changed
      end
    end

    context 'with collection replaced' do
      before do
        post.comments = [Comment.new(:body => 'I like lasagne')]
      end

      it 'should be changed' do
        post.should be_changed
      end

      it 'should expose changes' do
        mapped_changes.should == [['I like pizza'], ['I like lasagne']]
      end

      it 'should not be changed after save' do
        post.save
        post.should_not be_changed
      end
    end
  end
end
