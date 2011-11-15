require File.expand_path('../lib/elastictastic/version', __FILE__)

task :default => :release
task :release => [:build, :tag, :push, :cleanup]

task :build do
  system 'gem build elastictastic.gemspec'
end

task :tag do
  system "git tag -a -m 'Version #{Elastictastic::VERSION}' #{Elastictastic::VERSION}"
  system "git push origin #{Elastictastic::VERSION}:#{Elastictastic::VERSION}"
end

task :push do
  system "gem inabox elastictastic-#{Elastictastic::VERSION}.gem"
end

task :cleanup do
  system "rm -v *.gem"
end
