require File.expand_path('../lib/elastictastic/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'elastictastic'
  s.version = Elastictastic::VERSION
  s.authors = ['Mat Brown', 'Aubrey Holland', 'John Crepezzi']
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
  s.test_files = Dir['spec/examples/**/*.rb']
  s.has_rdoc = true
  s.extra_rdoc_files = 'README.md'
  s.required_ruby_version = '>= 1.9'
  s.add_runtime_dependency 'activesupport', '~> 3.0'
  s.add_runtime_dependency 'activemodel', '~> 3.0'
  s.add_runtime_dependency 'hashie'
  s.add_runtime_dependency 'i18n'
  s.add_runtime_dependency 'multi_json'
  s.add_development_dependency 'rspec', '~> 2.0'
  s.add_development_dependency 'fakeweb', '~> 1.3'
  s.add_development_dependency 'debugger'
  s.add_development_dependency 'yard', '~> 0.6'
  s.requirements << 'ElasticSearch'
end
