require File.expand_path('../lib/elastictastic/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'elastictastic'
  s.version = Elastictastic::VERSION
  s.author = 'Mat Brown'
  s.email = 'mat.a.brown@gmail.com'
  s.license = 'MIT'
  s.summary = 'Object-document mapper for ElasticSearch'
  s.description = <<DESC
Elastictastic is an object-document mapper and lightweight API adapter for
ElasticSearch. Elastictastic's primary use case is to define model classes which
use ElasticSearch as a primary document-oriented data store, and to expose
ElasticSearch's search functionality to query for those models.
DESC

  s.files = Dir['lib/**/*.rb', 'spec/**/*.rb', 'README.md', 'CHANGELOG.md', 'LICENSE']
  s.has_rdoc = true
  s.extra_rdoc_files = 'README.md'
  s.add_runtime_dependency 'activesupport', '~> 3.0'
  s.add_runtime_dependency 'hashie'
  s.add_development_dependency 'rspec', '~> 2.0'
end
