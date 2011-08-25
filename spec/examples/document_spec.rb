require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Document do
  include Elastictastic::TestHelpers

  let(:last_request) { FakeWeb.last_request }

  describe '#save' do
    context 'new object' do
      let!(:id) { stub_elasticsearch_create('default', 'post') }
      let(:post) { Post.new }

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
        post.id.should == id
      end

      it 'should mark object as persisted' do
        post.should be_persisted
      end
    end

    context 'new object with ID' do
      let(:post) { Post.new.tap { |post| post.id = '123' }}

      context 'with unique id' do
        before do
          stub_elasticsearch_create('default', 'post', post.id)
          post.save
        end

        it 'should send PUT request' do
          last_request.method.should == 'PUT'
        end

        it 'should send request to _create verb for document resource' do
          last_request.path.should == '/default/post/123/_create'
        end

        it 'should send document in body' do
          last_request.body.should == post.to_elasticsearch_doc.to_json
        end
      end

      context 'with duplicate ID' do
        before do
          stub_elasticsearch_create(
            'default', 'post', '123',
            :body => {
              'error' => 'DocumentAlreadyExistsEngineException[[post][2] [post][1]]: document already exists',
              'status' => 409
            }.to_json
          )
        end

        let(:save) { lambda { post.save }}

        it 'should raise DocumentAlreadyExistsEngineException' do
          expect(&save).to raise_error(Elastictastic::ServerError::DocumentAlreadyExistsEngineException)
        end

        it 'should inject the error message into the exception' do
          expect(&save).to raise_error { |error|
            error.message.should == 'document already exists'
          }
        end

        it 'should inject the status into the exception' do
          expect(&save).to raise_error { |error|
            error.status.should == 409
          }
        end
      end
    end

    shared_examples_for 'persisted object' do
      describe 'identity attributes' do
        it 'should not allow setting of ID' do
          lambda { post.id = 'bogus' }.should raise_error(Elastictastic::IllegalModificationError)
        end

        it 'should not allow setting of index' do
          lambda { post.index = 'silly_index' }.should raise_error(Elastictastic::IllegalModificationError)
        end
      end

      describe '#save' do
        before do
          stub_elasticsearch_update('default', 'post', post.id)
          post.title = 'Fun Factories for Fickle Ferrets'
          post.save
        end

        it 'should send PUT request' do
          last_request.method.should == 'PUT'
        end

        it "should send to document's resource path" do
          last_request.path.should == "/default/post/#{post.id}"
        end

        it "should send document's body in request" do
          last_request.body.should == post.to_elasticsearch_doc.to_json
        end
      end
    end

    context 'object after save' do
      let(:post) do
        stub_elasticsearch_create('default', 'post')
        Post.new.tap { |post| post.save }
      end

      it_should_behave_like 'persisted object'
    end

    context 'existing persisted object' do
      let(:post) do
        Post.new.tap do |post|
          post.id = '123'
          post.persisted!
        end
      end

      it_should_behave_like 'persisted object'
    end
  end
end
