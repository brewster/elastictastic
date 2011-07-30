require 'bundler'
Bundler.require(:default, :test)
require 'fakeweb'

Dir[File.expand_path('../../models/**/*.rb', __FILE__)].each do |mock|
  require mock
end

RSpec.configure do |config|
  config.before(:all) do
    FakeWeb.allow_net_connect = false
  end
end
