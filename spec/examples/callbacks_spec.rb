require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Callbacks do
  include Elastictastic::TestHelpers

  let(:MyModel) do
    Class.new do
      def self.name
        'MyModel'
      end

      include Elastictastic::Document

      before_save :before_save_ran!
      before_create :before_create_ran!
      before_update :before_update_ran!
      before_destroy :before_destroy_ran!
      
      def hooks_that_ran
        @hooks_that_ran ||= Set[]
      end

      def has_run_hook?(hook)
        hooks_that_ran.include?(hook.to_sym)
      end

      private

      def method_missing(method, *args, &block)
        if method.to_s =~ /^(.*)_ran!$/
          hooks_that_ran << $1.to_sym
        else
          super
        end
      end
    end
  end

  let(:id) { '123' }
  let(:instance) { MyModel().new }
  let(:persisted_instance) do
    MyModel().new.tap do |instance|
      instance.elasticsearch_hit = { '_id' => id, '_index' => 'default' }
    end
  end

  before do
    stub_elasticsearch_create('default', 'my_model')
    stub_elasticsearch_update('default', 'my_model', id)
    stub_elasticsearch_destroy('default', 'my_model', id)
  end

  describe '#before_save' do

    it 'should run before create' do
      instance.save
      instance.should have_run_hook(:before_save)
    end

    it 'should run before update' do
      persisted_instance.save
      persisted_instance.should have_run_hook(:before_save)
    end
  end

  describe '#before_create' do
    it 'should run before create' do
      instance.save
      instance.should have_run_hook(:before_create)
    end

    it 'should run before update' do
      persisted_instance.save
      persisted_instance.should_not have_run_hook(:before_create)
    end
  end

  describe '#before_update' do
    it 'should not run before create' do
      instance.save
      instance.should_not have_run_hook :before_update
    end

    it 'should run before update' do
      persisted_instance.save
      persisted_instance.should have_run_hook(:before_update)
    end
  end

  describe '#before_destroy' do
    it 'should run before destroy' do
      persisted_instance.destroy
      persisted_instance.should have_run_hook(:before_destroy)
    end
  end
end
