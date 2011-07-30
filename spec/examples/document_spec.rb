require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Document do
  let(:last_request) { FakeWeb.last_request }
  let(:next_response) { {} }

  before do
    FakeWeb.register_uri(
      :any,
      %r(^http://localhost:9200/),
      :body => next_response.to_json
    )
  end

  describe '#save' do
    context 'new object' do
      let(:post) { Post.new }
      let(:next_response) {{ '_id' => 'abcde' }}

      before do
        post.title = 'Hot Pasta'
        post.save
      end

      it 'should send POST request' do
        last_request.method.should == 'POST'
      end

      it 'should send to index/type path' do
        last_request.path.should == '/default/post'
      end

      it 'should send document in the body' do
        last_request.body.should == post.to_elasticsearch_doc.to_json
      end

      it 'should populate ID of model object' do
        post.id.should == 'abcde'
      end

      it 'should mark object as persisted' do
        post.should be_persisted
      end
    end

    context 'existing object' do
      it 'should not allow setting of ID' do
        pending
      end

      it 'should not allow setting of type' do
        pending
      end
    end
  end

  private

  def hit(id, index, properties = {})
  end
end
