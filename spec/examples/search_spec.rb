require File.expand_path('../spec_helper', __FILE__)

#
# Here we describe the functionality for constructing queries, which is (sort of)
# what the Search module does. See spec/examples/scope_spec to test running the
# search and dealing with the results
#
describe Elastictastic::Search do
  describe '#to_params' do
    {
      'query' => { 'match_all' => {} },
      'filter' => { 'ids' => { 'values' => 1 }},
      'from' => 10,
      'sort' => { 'created_at' => 'desc' },
      'highlight' => { 'fields' => { 'body' => {}}},
      'fields' => %w(title body),
      'script_fields' => { 'rtitle' => { 'script' => "_source.title.reverse()" }},
      'preference' => '_local',
      'facets' => { 'tags' => { 'terms' => { 'field' => 'tags' }}}
    }.each_pair do |method, value|
      it "should build scope for #{method} param" do
        Post.__send__(method, value).params.should == { method => value }
      end
    end

    it 'should raise ArgumentError if no value passed' do
      expect { Post.query }.to raise_error(ArgumentError)
    end

    it 'should not cast single arg to an array' do
      Post.fields('title').params.should == { 'fields' => 'title' }
    end

    it 'should take multiple args and convert them to an array' do
      Post.fields('title', 'body').params.should ==
        { 'fields' => %w(title body) }
    end

    it 'should chain scopes' do
      Post.from(30).size(15).params.should == { 'from' => 30, 'size' => 15 }
    end

    it 'should merge multiple scalars into an array when chaining' do
      Post.fields('title').fields('body').params.should ==
        { 'fields' => %w(title body) }
    end

    it 'should merge arrays into an array when chaining' do
      Post.fields('title', 'body').fields('created_at', 'tags').params.should == {
        'fields' => %w(title body created_at tags)
      }
    end

    it 'should merge scalar and array when chaning' do
      Post.fields('title', 'body').fields('tags').params.should == {
        'fields' => %w(title body tags)
      }
    end

    it 'should deep-merge hashes when chaining' do
      Post.highlight('fields' => { 'body' => {} }).highlight(
        'fields' => { 'comments.body' => {}}).params.should == { 

        'highlight' => { 'fields' => { 'body' => {}, 'comments.body' => {} }}
      }
    end

    it 'should not chain destructively' do
      scope = Post.from(20)
      scope.size(10)
      scope.params.should == { 'from' => 20 }
    end
  end

  describe 'block builder' do
    it 'should build scopes with a block' do
      Post.sort { title 'asc' }.params.should ==
        { 'sort' => { 'title' => 'asc' }}
    end

    it 'should accept multiple calls within a block' do
      scope = Post.sort do
        title 'asc'
        created_at 'desc'
      end
      scope.params.should ==
        { 'sort' => { 'title' => 'asc', 'created_at' => 'desc' }}
    end

    it 'should turn varargs into array' do
      Post.highlight { fields 'body', 'comments.body' }.params.should ==
        { 'highlight' => { 'fields' => %w(body comments.body) }}
    end

    it 'should accept nested calls within a block' do
      scope = Post.query do
        query_string { query 'test testor' }
      end
      scope.params.should ==
        { 'query' => { 'query_string' => { 'query' => 'test testor' }}}
    end

    it 'should set value to empty object (Hash) if none passed' do
      scope = Post.query { match_all }.params.should ==
        { 'query' => { 'match_all' => {} }}
    end
  end

  describe 'class methods' do
    let(:named_scope) do
      Post.from(10).search_keywords('hey guy')
    end

    it 'should delegate to class singleton' do
      named_scope.params['query'].should == {
        'query_string' => { 'query' => 'hey guy', 'fields' => %w(title body) }
      }
    end

    it 'should retain current scope' do
      named_scope.params['from'].should == 10
    end
  end
end
