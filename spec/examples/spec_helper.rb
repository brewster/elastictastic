require 'bundler'
Bundler.require(:default, :test)
require 'active_support'
require 'rspec/mocks'

Dir[File.expand_path('../../mocks/**/*.rb', __FILE__)].each do |mock|
  require mock
end
