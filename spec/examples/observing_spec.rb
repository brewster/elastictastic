require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Observing do
  include Elastictastic::TestHelpers

  let(:id) { '123' }
  let(:post) { Post.new }
  let(:persisted_post) do
    Post.new.tap do |post|
      post.elasticsearch_hit = { '_id' => id, '_index' => 'default' }
    end
  end

  before do
    stub_elasticsearch_create('default', 'post')
    stub_elasticsearch_update('default', 'post', id)
    stub_elasticsearch_destroy('default', 'post', id)
    Elastictastic.config.observers = [:post_observer]
    Elastictastic.config.instantiate_observers
  end

  context 'on create' do
    let(:observers) { post.observers_that_ran }

    before do
      post.save
    end

    it 'should run before_create' do
      observers.should include(:before_create)
    end

    it 'should run after_create' do
      observers.should include(:after_create)
    end

    it 'should run before_save' do
      observers.should include(:before_save)
    end

    it 'should run after_save' do
      observers.should include(:after_save)
    end

    it 'should not run before_update' do
      observers.should_not include(:before_update)
    end

    it 'should not run after_update' do
      observers.should_not include(:after_update)
    end

    it 'should not run before_destroy' do
      observers.should_not include(:before_destroy)
    end
    
    it 'should not run after_destroy' do
      observers.should_not include(:after_destroy)
    end
  end

  context 'on update' do
    let(:observers) { persisted_post.observers_that_ran }

    before do
      persisted_post.save
    end

    it 'should not run before_create' do
      observers.should_not include(:before_create)
    end

    it 'should not run after_create' do
      observers.should_not include(:after_create)
    end

    it 'should run before_update' do
      observers.should include(:before_update)
    end

    it 'should run after_update' do
      observers.should include(:after_update)
    end

    it 'should run before_save' do
      observers.should include(:before_save)
    end

    it 'should run after_save' do
      observers.should include(:after_save)
    end

    it 'should not run before_destroy' do
      observers.should_not include(:before_destroy)
    end

    it 'should not run after_destroy' do
      observers.should_not include(:after_destroy)
    end
  end

  context 'on destroy' do
    let(:observers) { persisted_post.observers_that_ran }

    before do
      persisted_post.destroy
    end

    it 'should not run before_create' do
      observers.should_not include(:before_create)
    end

    it 'should not run after_create' do
      observers.should_not include(:after_create)
    end

    it 'should not run before_update' do
      observers.should_not include(:before_update)
    end

    it 'should not run after_update' do
      observers.should_not include(:after_update)
    end

    it 'should not run before_save' do
      observers.should_not include(:before_save)
    end

    it 'should not run after_save' do
      observers.should_not include(:after_save)
    end

    it 'should run before_destroy' do
      observers.should include(:before_destroy)
    end

    it 'should run after_destroy' do
      observers.should include(:after_destroy)
    end
  end
end
