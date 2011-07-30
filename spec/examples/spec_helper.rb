require 'bundler'
Bundler.require(:default, :test)
require 'active_support'

Dir[File.expand_path('../../models/**/*.rb', __FILE__)].each do |mock|
  require mock
end
