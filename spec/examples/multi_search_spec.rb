require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::MultiSearch do
  include Elastictastic::TestHelpers

  let(:request_components) do
    [].tap do |components|
      FakeWeb.last_request.body.each_line do |line|
        components << Elastictastic.json_decode(line) unless line.strip.empty?
      end
    end
  end

  describe '::query' do
    let(:scopes) do
      [
        Post.query(:query_string => { :query => 'pizza' }).size(10),
        Blog.in_index('my_index').query(:term => { 'name' => 'Pasta' }).size(10)
      ]
    end

    before do
      stub_es_msearch(
        Array.new(3) { |i| generate_es_hit('post', :source => { 'title' => "post #{i}" }) },
        Array.new(5) { |i| generate_es_hit('blog', :source => { 'name' => "blog #{i}" }) }
      )
      Elastictastic::MultiSearch.query(scopes)
    end

    it 'should send correct type, index, and search_type' do
      request_components[0].should == { 'index' => 'default', 'type' => 'post', 'search_type' => 'query_then_fetch' }
      request_components[2].should == { 'index' => 'my_index', 'type' => 'blog', 'search_type' => 'query_then_fetch' }
    end

    it 'should send correct scope params' do
      request_components[1].should == scopes[0].params
      request_components[3].should == scopes[1].params
    end

    it 'should populate scopes with results' do
      scopes.first.each_with_index { |post, i| post.title.should == "post #{i}" }
    end
  end

  describe '::count' do
    let(:scopes) do
      [
        Post.query(:query_string => { :query => 'pizza' }).size(10),
        Blog.in_index('my_index').query(:term => { 'name' => 'Pasta' })
      ]
    end

    before do
      stub_es_msearch_count(3, 5)
      Elastictastic::MultiSearch.count(scopes)
    end

    it 'should send count search_type' do
      request_components[0]['search_type'].should == 'count'
      request_components[2]['search_type'].should == 'count'
    end

    it 'should populate counts' do
      scopes.map { |scope| scope.count }.should == [3, 5]
    end

    it 'should not populate results' do
      expect { scopes.first.to_a }.
        to raise_error(FakeWeb::NetConnectNotAllowedError)
    end
  end

  context 'with unbounded scopes' do
    let(:scopes) do
      [Post.query(:query_string => { :query => 'pizza' })]
    end

    it 'should throw an exception' do
      expect { Elastictastic::MultiSearch.query(scopes) }.
        to raise_error(ArgumentError)
    end
  end

  context 'with error in response' do
    let(:scopes) do
      [Post.query(:bogus => {}).size(10)]
    end

    before do
      stub_request_json(
        :post,
        match_es_path('/_msearch'),
        'responses' => [{ 'error' => 'SearchPhaseExecutionException[Failed to execute phase [query], total failure; shardFailures {[8A2fuICBTdiry42KTfa7uQ][contact_documents-1-development-0][4]: SearchParseException[[contact_documents-1-development-0][4]: from[-1],size[-1]: Parse Failure [Failed to parse source [{\"query\":{\"bogus\": {}}}]]]; nested: QueryParsingException[[contact_documents-1-development-0] No query registered for [bogus]]; }{[8A2fuICBTdiry42KTfa7uQ][contact_documents-1-development-0][3]: SearchParseException[[contact_documents-1-development-0][3]: from[-1],size[-1]: Parse Failure [Failed to parse source [{\"query\":{\"bogus\": {}}}]]]; nested: QueryParsingException[[contact_documents-1-development-0] No query registered for [bogus]]; }]'}]
      )
    end

    it 'should raise error' do
      expect { Elastictastic::MultiSearch.query(scopes) }.
        to raise_error(Elastictastic::ServerError::QueryParsingException)
    end
  end
end
