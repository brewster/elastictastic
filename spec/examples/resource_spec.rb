require File.expand_path('../spec_helper', __FILE__)

describe Elastictastic::Resource do
  describe '::mapping' do
    let(:mapping) { Post.mapping }
    let(:properties) { mapping['post']['properties'] }

    it 'should set basic field' do
      properties.should have_key('title')
    end

    it 'should default type to string' do
      properties['title']['type'].should == 'string'
    end

    it 'should force date format as date_time_no_millis' do
      properties['published_at']['format'].should == 'date_time_no_millis'
    end

    it 'should accept options' do
      properties['comments_count']['type'].should == 'integer'
    end

    it 'should set up multifield' do
      properties['tags'].should == {
        'type' => 'multi_field',
        'fields' => {
          'tags' => { 'type' => 'string', 'index' => 'analyzed' },
          'non_analyzed' => { 'type' => 'string', 'index' => 'not_analyzed' }
        }
      }
    end
  end
end
