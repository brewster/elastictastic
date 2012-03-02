require File.expand_path('../spec_helper', __FILE__)

#
# Here we describe the functionality for constructing queries, which is (sort of)
# what the Search module does. See spec/examples/scope_spec to test running the
# search and dealing with the results
#
describe Elastictastic::Search do
  include Elastictastic::TestHelpers

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

    it 'should not chain destructively' do
      scope = Post.from(20)
      scope.size(10)
      scope.params.should == { 'from' => 20 }
    end
  end

  describe '#[]' do
    it 'should run #first query with an integer argument' do
      stub_es_search('default', 'post', 'hits' => {
        'total' => '2',
        'hits' => [generate_es_hit('post', :id => '1')]
      })
      Post.all[4].id.should == '1'
      last_request_json['from'].should == 4
      last_request_json['size'].should == 1
    end

    it 'should add from/size to scope with a range argument' do
      params = Post.all[2..4].params
      params['from'].should == 2
      params['size'].should == 3
    end

    it 'should add from/size to scope with an end-excluded range argument' do
      params = Post.all[2...4].params
      params['from'].should == 2
      params['size'].should == 2
    end
  end

  describe 'merging' do
    let(:scope) { Post }

    it 'should merge two simple queries into a bool' do
      scope.query { term(:title => 'Pizza') }.query { term(:comments_count => 0) }.params.should == {
        'query' => {
          'bool' => {
            'must' => [
              { 'term' => { 'title' => 'Pizza' }},
              { 'term' => { 'comments_count' => 0 }}
            ]
          }
        }
      }
    end

    it 'should merge three simple queries into a bool' do
      scope = self.scope.query { term(:title => 'pizza') }
      scope = scope.query { term(:comments_count => 1) }
      scope = scope.query { term(:tags => 'delicious') }
      scope.params.should == {
        'query' => {
          'bool' => {
            'must' => [
              { 'term' => { 'title' => 'pizza' }},
              { 'term' => { 'comments_count' => 1 }},
              { 'term' => { 'tags' => 'delicious' }}
            ]
          }
        }
      }
    end

    it 'should merge a new query into an existing boolean query' do
      scope = self.scope.query { bool { must({ 'term' => { 'title' => 'pizza' }}, { 'term' => { 'comments_count' => 1 }}) }}
      scope = scope.query { term(:tags => 'delicious') }
      scope.params.should == {
        'query' => {
          'bool' => {
            'must' => [
              { 'term' => { 'title' => 'pizza' }},
              { 'term' => { 'comments_count' => 1 }},
              { 'term' => { 'tags' => 'delicious' }}
            ]
          }
        }
      }
    end

    it 'should merge a new query into an existing filtered query' do
      scope = self.scope.query do
        filtered do
          query { term('title' => 'pizza') }
          filter { term('comments_count' => 1) }
        end
      end
      scope = scope.query { term('tags' => 'delicious') }
      scope.params['query'].should == {
        'filtered' => {
          'query' => { 'bool' => { 'must' => [{ 'term' => { 'title' => 'pizza' }}, { 'term' => { 'tags' => 'delicious' }}] }},
          'filter' => { 'term' => { 'comments_count' => 1 }}
        }
      }
    end

    it 'should merge two filtered queries' do
      scope = self.scope.query do
        filtered do
          query { term('title' => 'pizza') }
          filter { term('comments_count' => 1) }
        end
      end
      scope = scope.query do
        filtered do
          query { term('title' => 'pepperoni') }
          filter { term('tags' => 'delicious') }
        end
      end
      scope.params.should == {
        'query' => {
          'filtered' => {
            'query' => { 'bool' => { 'must' => [
              { 'term' => { 'title' => 'pizza' }},
              { 'term' => { 'title' => 'pepperoni' }}
            ]}},
            'filter' => { 'and' => [
              { 'term' => { 'comments_count' => 1 }},
              { 'term' => { 'tags' => 'delicious' }}
            ]}
          }
        }
      }
    end

    it 'should merge a regular query with a constant-score filter query' do
      scope = self.scope.query('term' => { 'title' => 'pizza' })
      scope = scope.query { constant_score { filter { term('tags' => 'delicious') }}}
      scope.params.should == {
        'query' => {
          'filtered' => {
            'query' => { 'term' => { 'title' => 'pizza' }},
            'filter' => { 'term' => { 'tags' => 'delicious' }}
          }
        }
      }
    end

    it 'should merge two constant-score filter queries' do
      scope = self.scope.query { constant_score { filter { term('tags' => 'delicious') }}}
      scope = scope.query { constant_score { filter { term('comments_count' => 0) }}}
      scope.params.should == {
        'query' => {
          'constant_score' => {
            'filter' => {
              'and' => [
                { 'term' => { 'tags' => 'delicious' }},
                { 'term' => { 'comments_count' => 0 }}
              ]
            }
          }
        }
      }
    end

    it 'should merge a constant-score filter query into a constant-score conjunction query' do
      scope = self.scope.query { constant_score { filter('and' => [{ 'term' => { 'title' => 'pizza' }}, { 'term' => { 'tags' => 'delicious' }}]) }}
      scope = scope.query { constant_score { filter { term('comments_count' => 0) }}}
      scope.params.should == {
        'query' => {
          'constant_score' => {
            'filter' => {
              'and' => [
                { 'term' => { 'title' => 'pizza' }},
                { 'term' => { 'tags' => 'delicious' }},
                { 'term' => { 'comments_count' => 0 }}
              ]
            }
          }
        }
      }
    end

    it 'should merge two filters' do
      scope = self.scope.filter('term' => { 'comments_count' => 0 })
      scope = scope.filter('term' => { 'tags' => 'delicious' })
      scope.params.should == {
        'filter' => { 'and' => [
          { 'term' => { 'comments_count' => 0 }},
          { 'term' => { 'tags' => 'delicious' }}
        ]}
      }
    end

    it 'should merge filter into conjunction' do
      scope = self.scope.filter('and' => [{ 'term' => { 'title' => 'pizza' }}, { 'term' => { 'comments_count' => 0 }}])
      scope = scope.filter('term' => { 'tags' => 'delicious' })
      scope.params.should == {
        'filter' => { 'and' => [
          { 'term' => { 'title' => 'pizza' }},
          { 'term' => { 'comments_count' => 0 }},
          { 'term' => { 'tags' => 'delicious' }}
        ]}
      }
    end
    
    it 'should override from when chaining' do
      scope.from(10).from(20).params.should == { 'from' => 20 }
    end

    it 'should not override from when not given' do
      scope.from(10).size(10).params.should == { 'from' => 10, 'size' => 10 }
    end

    it 'should override size when chaining' do
      scope.size(10).size(15).params.should == { 'size' => 15 }
    end

    it 'should concatenate chained sorts' do
      scope.sort('title' => 'asc').sort('comments_count' => 'desc').params.should == {
        'sort' => [{ 'title' => 'asc' }, { 'comments_count' => 'desc' }]
      }
    end

    it 'should concatenate chained sort onto multiple sorts' do
      scope.sort({ 'title' => 'asc' }, { 'comments_count' => 'desc' }).sort('created_at' => 'desc').params.should == {
        'sort' => [{ 'title' => 'asc' }, { 'comments_count' => 'desc' }, { 'created_at' => 'desc' }]
      }
    end

    it 'should merge highlight fields' do
      scope.highlight { fields('title' => {}) }.highlight { fields('tags' => {}) }.params.should == {
        'highlight' => { 'fields' => { 'title' => {}, 'tags' => {} }}
      }
    end

    it 'should move global highlight settings into fields when merging' do
      scope = self.scope.highlight do
        fields('title' => {})
        number_of_fragments(0)
      end
      scope = scope.highlight do
        fields('tags' => {})
        number_of_fragments(1)
      end
      scope.params.should == {
        'highlight' => {
          'fields' => {
            'title' => { 'number_of_fragments' => 0 },
            'tags' => { 'number_of_fragments' => 1 }
          }
        }
      }
    end

    it 'should not override field-specific highlight settings when moving global settings' do
      scope = self.scope.highlight do
        fields(:title => { :number_of_fragments => 0 }, :tags => {})
        number_of_fragments 1
      end
      scope = scope.highlight do
        fields('comments.body' => {})
        number_of_fragments 2
      end
      scope.params.should == {
        'highlight' => {
          'fields' => {
            'title' => { 'number_of_fragments' => 0 },
            'tags' => { 'number_of_fragments' => 1 },
            'comments.body' => { 'number_of_fragments' => 2 }
          }
        }
      }
    end

    it 'should concatenate fields' do
      scope.fields('title').fields('tags').params.should == {
        'fields' => %w(title tags)
      }
    end

    it 'should concatenate onto arrays of fields' do
      scope.fields('title', 'comments.body').fields('tags').params.should == {
        'fields' => %w(title comments.body tags)
      }
    end

    it 'should merge script fields' do
      scope.script_fields(:test1 => { 'script' => '1' }).script_fields(:test2 => { 'script' => '2' }).params.should == {
        'script_fields' => { 'test1' => { 'script' => '1' }, 'test2' => { 'script' => '2' }}
      }
    end

    it 'should overwrite chained preference' do
      scope.preference('_local').preference('_primary').params.should ==
        { 'preference' => '_primary' }
    end

    it 'should merge facets' do
      scope = self.scope.facets(:title => { :terms => { :field => 'title' }})
      scope = scope.facets(:tags => { :terms => { :field => 'tags' }})
      scope.params.should == {
        'facets' => {
          'title' => { 'terms' => { 'field' => 'title' }},
          'tags' => { 'terms' => { 'field' => 'tags' }}
        }
      }
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

  describe 'class methods directly on type-in-index' do
    let(:named_scope) { Post.in_index('my_index').search_keywords('hey guy') }

    it 'should delegate to class singleton when called on type_in_index' do
      named_scope.params['query'].should == {
        'query_string' => { 'query' => 'hey guy', 'fields' => %w(title body) }
      }
    end

    it 'should use proper index in scope' do
      named_scope.index.name.should == 'my_index'
    end
  end
end
