require File.expand_path('../spec_helper', __FILE__)

# This spec describes the behavior of Elastictastic when interacting with
# ElasticSearch to perform searches and related lookups. For behavior relating
# to the construction of search scopes, see spec/examples/search_spec
describe Elastictastic::Scope do
  include Elastictastic::TestHelpers

  let(:last_request) { FakeWeb.last_request }
  let(:last_request_body) { JSON.parse(FakeWeb.last_request.body) }

  describe '#each' do
    let(:scope) { Post.query { match_all }.fields('title') }
    let(:scan_request) { FakeWeb.requests[0] }
    let(:scroll_requests) { FakeWeb.requests[1..-1] }
    let(:noop) { lambda { |arg| } }

    before do
      @scroll_ids = stub_elasticsearch_scan(
        'default', 'post', 2,
        {
          '_id' => '1', '_type' => 'post', '_index' => 'default',
          '_source' => { 'title' => 'post the first' }
        },
        {
          '_id' => '2', '_type' => 'post', '_index' => 'default',
          '_source' => { 'title' => 'post the second' }
        },
        {
          '_id' => '3', '_type' => 'post', '_index' => 'default',
          '_source' => { 'title' => 'post the third' }
        }
      )
    end

    it 'should return all contact documents' do
      documents = []
      scope.each { |post| documents << post }
      documents.map { |doc| doc.id }.should == %w(1 2 3)
    end

    describe 'initial scan search' do
      before { scope.each(&noop) }

      it 'should make request to index/type search endpoint' do
        scan_request.path.split('?').first.should == '/default/post/_search'
      end

      it 'should send query in data for initial search' do
        scan_request.body.should == scope.params.to_json
      end

      it 'should send POST request initially' do
        scan_request.method.should == 'POST'
      end
    end

    context 'with options specified' do
      before { scope.each(:batch_size => 20, :ttl => 30, &noop) }

      it 'should make request to index/type search endpoint with batch size and TTL' do
        scan_request.path.split('?').last.split('&').should =~
          %w(search_type=scan scroll=30s size=20)
      end
    end

    describe 'paging through cursor' do
      before { scope.each(&noop) }

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
    end
  end # describe '#each'
end
