require 'bundler'
Bundler.require(:default, :test, :development)
require 'fakeweb'

require File.dirname(__FILE__) + '/../models/author'
require File.dirname(__FILE__) + '/../models/post'

RSpec.configure do |config|
  config.before(:all) do
    FakeWeb.allow_net_connect = false
  end
end
