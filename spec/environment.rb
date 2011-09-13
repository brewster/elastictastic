require 'bundler'
Bundler.require(:default, :test, :development)

%w(author comment post).each do |model|
  require File.expand_path("../models/#{model}", __FILE__)
end
