require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Resource do
  describe '::mapping' do
    let(:mapping) { Post.mapping }
    let(:properties) { mapping['post']['properties'] }

    it 'should set basic field' do
      properties.should have_key('title')
    end
  end
end
