require File.expand_path('../lib/elastictastic/version', __FILE__)
require 'rspec/core/rake_task'

task :default => :release
task :release => [:test, :build, :tag, :push, :cleanup]

desc 'Build gem'
task :build do
  system 'gem build elastictastic.gemspec'
end

desc 'Create git release tag'
task :tag do
  system "git tag -a -m 'Version #{Elastictastic::VERSION}' #{Elastictastic::VERSION}"
  system "git push origin #{Elastictastic::VERSION}:#{Elastictastic::VERSION}"
end

desc 'Push gem to repository'
task :push => :inabox

task 'Push gem to geminabox'
task :inabox do
  system "gem inabox elastictastic-#{Elastictastic::VERSION}.gem"
end

task 'Remove packaged gems'
task :cleanup do
  system "rm -v *.gem"
end

desc 'Run the specs'
RSpec::Core::RakeTask.new(:test)
