require 'bundler'
Bundler.require(:default, :test, :development)

%w(author blog comment post post_observer).each do |model|
  require File.expand_path("../models/#{model}", __FILE__)
end
