require File.expand_path('../spec_helper', __FILE__)

# This spec describes the behavior of Elastictastic when interacting with
# ElasticSearch to perform searches and related lookups. For behavior relating
# to the construction of search scopes, see spec/examples/search_spec
describe Elastictastic::Scope do
  include Elastictastic::TestHelpers

  let(:last_request) { FakeWeb.last_request }
  let(:last_request_body) { JSON.parse(last_request.body) }
  let(:last_request_path) { last_request.path.split('?', 2)[0] }
  let(:last_request_params) { last_request.path.split('?', 2)[1].try(:split, '&') }

  describe '#each' do
    let(:noop) { lambda { |arg| } }

    context 'with query only' do
      let(:scope) { Post.all.fields('title') }
      let(:scan_request) { FakeWeb.requests[0] }
      let(:scroll_requests) { FakeWeb.requests[1..-1] }

      before do
        @scroll_ids = stub_elasticsearch_scan(
          'default', 'post', 2, *make_hits(3)
        )
      end

      it 'should return all contact documents' do
        documents = []
        scope.each { |post| documents << post }
        documents.map { |doc| doc.id }.should == %w(1 2 3)
      end

      describe 'initiating scan search' do
        before { scope.to_a }

        it 'should make request to index/type search endpoint' do
          scan_request.path.split('?').first.should == '/default/post/_search'
        end

        it 'should send query in data for initial search' do
          scan_request.body.should == scope.params.to_json
        end

        it 'should send POST request initially' do
          scan_request.method.should == 'POST'
        end
      end # describe 'initiating scan search'

      context 'with options specified' do
        before { scope.find_each(:batch_size => 20, :ttl => 30, &noop) }

        it 'should make request to index/type search endpoint with batch size and TTL' do
          scan_request.path.split('?').last.split('&').should =~
            %w(search_type=scan scroll=30s size=20)
        end
      end # context 'with options specified'

      describe 'paging through cursor' do
        before { scope.to_a }

        it 'should make request to scan search endpoint' do
          scroll_requests.each { |request| request.path.split('?').first.should == '/_search/scroll' }
        end

        it 'should send id in body' do
          scroll_requests.map { |request| request.body }.should == @scroll_ids
        end

        it 'should include scroll param in each request' do
          scroll_requests.each do |request|
            request.path.split('?')[1].split('&').should include('scroll=60s')
          end
        end
      end # describe 'paging through cursor'
    end # context 'with query only'

    context 'with from/size' do
      let(:scope) { Post.from(10).size(10) }

      before do
        stub_elasticsearch_search(
          'default', 'post', 'hits' => {
            'total' => 2,
            'hits' => make_hits(2)
          }
        )
      end

      it 'should send request to search endpoint' do
        scope.to_a
        last_request_path.should == '/default/post/_search'
      end

      it 'should send query in body' do
        scope.to_a
        last_request_body.should == scope.params
      end

      it 'should perform query_then_fetch search' do
        scope.to_a
        last_request_params.should include('search_type=query_then_fetch')
      end

      it 'should return documents' do
        scope.map { |post| post.title }.should == ['Post 1', 'Post 2']
      end
    end # context 'with from/size'

    context 'with sort but no from/size' do
      let(:scope) { Post.sort(:title => 'asc') }
      let(:requests) { FakeWeb.requests }
      let(:request_bodies) do
        requests.map do |request|
          JSON.parse(request.body)
        end
      end

      before do
        stub_elasticsearch_search(
          'default', 'post',
          make_hits(101).each_slice(100).map { |batch| { 'hits' => { 'hits' => batch, 'total' => 101 }} }
        )
      end

      it 'should send two requests' do
        scope.to_a
        requests.length.should == 2
      end

      it 'should send requests to search endpoint' do
        scope.to_a
        requests.each do |request|
          request.path.split('?').first.should == '/default/post/_search'
        end
      end

      it 'should send from' do
        scope.to_a
        request_bodies.each_with_index do |body, i|
          body['from'].should == i * 100
        end
      end

      it 'should send size' do
        scope.to_a
        request_bodies.each do |body|
          body['size'].should == 100
        end
      end

      it 'should perform query_then_fetch search' do
        scope.to_a
        requests.each do |request|
          request.path.should =~ /[\?&]search_type=query_then_fetch(&|$)/
        end
      end

      it 'should return all results' do
        scope.map { |post| post.id }.should == (1..101).map(&:to_s)
      end
    end # context 'with sort but no from/size'
  end # describe '#each'

  describe '#count' do
    context 'with no operations performed yet' do
      let!(:count) do
        stub_elasticsearch_search('default', 'post', 'hits' => { 'total' => 3 })
        Post.all.count
      end

      it 'should send search_type as count' do
        last_request_params.should include('search_type=count')
      end

      it 'should get count' do
        count.should == 3
      end
    end # context 'with no operations performed yet'

    context 'with scan search performed' do
      let!(:count) do
        stub_elasticsearch_scan(
          'default', 'post', 2, *make_hits(3)
        )
        scope = Post.all
        scope.to_a
        scope.count
      end

      it 'should get count from scan request' do
        count.should == 3
      end

      it 'should not send count request' do
        FakeWeb.should have(4).requests
      end
    end

    context 'with paginated search performed' do
      let!(:count) do
        stub_elasticsearch_search(
          'default', 'post', 'hits' => {
            'hits' => make_hits(3),
            'total' => 3
          }
        )
        scope = Post.size(10)
        scope.to_a
        scope.count
      end

      it 'should get count from query_then_fetch search' do
        count.should == 3
      end

      it 'should not perform extra request' do
        FakeWeb.should have(1).request
      end
    end

    context 'with paginated scan performed' do
      let!(:count) do
        stub_elasticsearch_search(
          'default', 'post', 'hits' => {
            'hits' => make_hits(2),
            'total' => 2
          }
        )
        scope = Post.sort('title' => 'asc')
        scope.to_a
        scope.count
      end

      it 'should return count from internal paginated request' do
        count.should == 2
      end

      it 'should not perform extra request' do
        FakeWeb.should have(1).request
      end
    end # context 'with paginated scan performed'
  end # describe '#count'

  describe '#all_facets' do
    let(:facet_response) do
      {
        'comments_count' => {
          '_type' => 'terms', 'total' => 2,
          'terms' => [
            { 'term' => 4, 'count' => 1 },
            { 'term' => 2, 'count' => 1 }
          ]
        }
      }
    end
    let(:base_scope) { Post.facets(:comments_count => { :terms => { :field => :comments_count }}) }

    context 'with no requests performed' do
      let!(:facets) do
        stub_elasticsearch_search(
          'default', 'post',
          'hits' => { 'hits' => [], 'total' => 2 },
          'facets' => facet_response
        )
        base_scope.all_facets
      end

      it 'should make count search_type' do
        last_request_params.should include("search_type=count")
      end

      it 'should expose facets with object traversal' do
        facets.comments_count.terms.first.term.should == 4
      end
    end # context 'with no requests performed'

    context 'with count request performed' do
      let!(:facets) do
        stub_elasticsearch_search(
          'default', 'post',
          'hits' => { 'hits' => [], 'total' => 2 },
          'facets' => facet_response
        )
        base_scope.count
        base_scope.all_facets
      end

      it 'should only perform one request' do
        FakeWeb.should have(1).request
      end

      it 'should set facets' do
        facets.comments_count.should be
      end
    end # context 'with count request performed'

    context 'with single-page search performed' do
      let!(:facets) do
        stub_elasticsearch_search(
          'default', 'post',
          'hits' => { 'hits' => make_hits(2), 'total' => 2 },
          'facets' => facet_response
        )
        scope = base_scope.size(10)
        scope.to_a
        scope.all_facets
      end

      it 'should only perform one request' do
        FakeWeb.should have(1).request
      end

      it 'should get facets' do
        facets.comments_count.should be
      end
    end # context 'with single-page search performed'

    context 'with multi-page search performed' do
      let!(:facets) do
        stub_elasticsearch_search(
          'default', 'post',
          'hits' => { 'hits' => make_hits(2), 'total' => 2 },
          'facets' => facet_response
        )
        scope = base_scope.sort(:comments_count => :asc)
        scope.to_a
        scope.all_facets
      end

      it 'should only peform one request' do
        FakeWeb.should have(1).request
      end

      it 'should populate facets' do
        facets.comments_count.should be
      end
    end # context 'with multi-page search performed'
  end # describe '#all_facets'

  def make_hits(count)
    Array.new(count) do |i|
      {
        '_id' => (i + 1).to_s,
        '_type' => 'post',
        '_index' => 'default',
        '_source' => { 'title' => "Post #{i + 1}" }
      }
    end
  end
end
