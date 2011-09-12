require 'bundler'
Bundler.require(:default, :test, :development)
require 'fakeweb'

$: << File.expand_path('../../models', __FILE__)

%w(author comment post).each do |model|
  require File.expand_path("../../models/#{model}", __FILE__)
end

RSpec.configure do |config|
  config.before(:all) do
    FakeWeb.allow_net_connect = false
  end

  config.before(:each) do
    FakeWeb.last_request = nil
  end
end
