require File.expand_path('../../environment', __FILE__)
require 'fakeweb'

require File.expand_path('../../support/fakeweb_request_history', __FILE__)

RSpec.configure do |config|
  config.before(:all) do
    FakeWeb.allow_net_connect = false
  end

  config.after(:each) do
    FakeWeb.requests.clear
    FakeWeb.clean_registry
  end

  config.filter_run_excluding compatibility: :active_model_4
end
