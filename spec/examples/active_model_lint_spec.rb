require File.expand_path('../spec_helper', __FILE__)

describe 'ActiveModel compliance' do
  include ActiveModel::Lint::Tests

  ActiveModel::Lint::Tests.public_instance_methods.each do |method|
    method = method.to_s
    if method =~ /^test_/
      example method.gsub('_', ' ') do
        __send__(method)
      end
    end
  end

  private

  def model
    Post.new
  end
end
