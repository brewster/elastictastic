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
      after_save :after_save_ran!
      after_create :after_create_ran!
      after_update :after_update_ran!
      after_destroy :after_destroy_ran!
      
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
    stub_es_create('default', 'my_model')
    stub_es_update('default', 'my_model', id)
    stub_es_destroy('default', 'my_model', id)
  end

  %w(before after).each do |position|
    describe "##{position}_save" do

      it "should run #{position} create" do
        instance.save
        instance.should have_run_hook(:"#{position}_save")
      end

      it 'should run before update' do
        persisted_instance.save
        persisted_instance.should have_run_hook(:"#{position}_save")
      end

      it 'should not run before create when callbacks disabled' do
        instance.save(:callbacks => false)
        instance.should_not have_run_hook(:"#{position}_save")
      end

      it 'should not run before update when hooks disabled' do
        persisted_instance.save(:callbacks => false)
        instance.should_not have_run_hook(:"#{position}_save")
      end
    end

    describe "##{position}_create" do
      it "should run #{position} create" do
        instance.save
        instance.should have_run_hook(:"#{position}_create")
      end

      it "should not run #{position} update" do
        persisted_instance.save
        persisted_instance.should_not have_run_hook(:"#{position}_create")
      end

      it "should not run #{position} create when callbacks disabled" do
        instance.save(:callbacks => false)
        instance.should_not have_run_hook(:"#{position}_create")
      end
    end

    describe "##{position}_update" do
      it "should not run #{position} create" do
        instance.save
        instance.should_not have_run_hook :"#{position}_update"
      end

      it "should run #{position} update" do
        persisted_instance.save
        persisted_instance.should have_run_hook(:"#{position}_update")
      end

      it "should not run #{position} update if callbacks disabled" do
        persisted_instance.save(:callbacks => false)
        persisted_instance.should_not have_run_hook(:"#{position}_update")
      end
    end

    describe "##{position}_destroy" do
      it "should run #{position} destroy" do
        persisted_instance.destroy
        persisted_instance.should have_run_hook(:"#{position}_destroy")
      end

      it "should not run #{position} destroy if callbacks disabled" do
        persisted_instance.destroy(:callbacks => false)
        persisted_instance.should_not have_run_hook(:"#{position}_destroy")
      end
    end
  end
end
