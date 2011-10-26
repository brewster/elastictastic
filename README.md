# Elastictastic #

Elastictastic is an object-document mapper and lightweight API adapter for
[ElasticSearch](http://www.elasticsearch.org/). Elastictastic's primary use case
is to define model classes which use ElasticSearch as a primary
document-oriented data store, and to expose ElasticSearch's search functionality
to query for those models.

## Dependencies ##

Elastictastic requires Ruby 1.9 and ActiveSupport 3. Elastictastic does not
require Rails, but if you do run Rails, Elastictastic will only work with Rails
3.

You will also need a running ElasticSearch instance (or cluster). For local
development, you can easily [download](http://www.elasticsearch.org/download/)
and
[install](http://www.elasticsearch.org/guide/reference/setup/installation.html)
a copy, or your preferred package manager might have it available.

## Installation ##

Just add it to your Gemfile:

```ruby
gem 'elastictastic'
```

## Defining models ##

Elastictastic's setup DSL will be familiar to those who have used other
Ruby object-document mappers such as [Mongoid](http://mongoid.org/). Persisted
models mix in the `Elastictastic::Document` module, and fields are defined with
the `field` class macro:

```ruby
class Post
  field :title
end
```

The `field` method can take options; the options available here are simply those
that are available in a
[field mapping](http://www.elasticsearch.org/guide/reference/mapping/core-types.html)
in ElasticSearch. Elastictastic is (mostly) agnostic to the options you pass in;
they're just used to generate the mapping for ElasticSearch.

By default, ElasticSearch assigns fields a `string` type. An example of how one
might define a field with some options:

```ruby
class Post
  include Elastictastic::Document

  field :comments_count, :type => :integer, :store => 'yes'
end
```

### Multi-fields ###

ElasticSearch allows you to define
[multi-fields](http://www.elasticsearch.org/guide/reference/mapping/multi-field-type.html),
which index the same data in multiple ways. To define a multi-field in
Elastictastic, you may pass a block to the `field` macro, in which the alternate
fields are defined using the same DSL:

```ruby
field :title, :type => 'string', :index => 'analyzed' do
  field :unanalyzed, :type => 'string', :index => 'not_analyzed'
end
```

The arguments passed to the outer `field` method are used for the default field
mapping; thus, the above is the same as the following:

```ruby
field :title,
  :type => 'multi_field',
  :fields => {
    :title => { :type => 'string', :index => 'analyzed' },
    :unanalyzed => { :type => 'string', :index => 'not_analyzed' }
  }
```

### Embedded Objects ###

ElasticSearch supports deep nesting of properties by way of
[object fields](http://www.elasticsearch.org/guide/reference/mapping/object-type.html).
To define embedded objects in your Elastictastic models, use the `embed` class
macro:

```ruby
class Post
  include Elastictastic::Document

  embed :author
  embed :recent_comments, :class_name => 'Comment' 
end
```

The class that's embedded should include the `Elastictastic::Resource` mixin,
which exposes the same configuration DSL as `Elastictastic::Document` but does
not give the class the functionality of a top-level persistent object:

```ruby
class Author
  include Elastictastic::Resource

  field :name
  field :email, :index => 'not_analyzed'
end
```

### Parent-child relationships ###

You may define
[parent-child relationships](http://www.elasticsearch.org/blog/2010/12/27/0.14.0-released.html)
 for your documents using the `has_many` and `belongs_to` macros:

```ruby
class Blog
  include Elastictastic::Document

  has_many :posts
end
```

```ruby
class Post
  include Elastictastic::Document

  belongs_to :blog
end
```

Unlike in, say, ActiveRecord, an Elastictastic document can only specify one
parent (`belongs_to`) relationship. A document can have as many children
(`has_many`) as you would like.

The parent/child relationship has far-reaching consequences in ElasticSearch,
and as such you will generally interact with child documents via the parent's
association collection. For instance, this is the standard way to create a new
child instance:

```ruby
post = blog.posts.new
```

The above will return a new Post object whose parent is the `blog`; the
`blog.posts` collection will retain a reference to the transient `post`
instance, and will auto-save it when the `blog` is saved.

You may also create a child instance independently and then add it to a parent's
child collection; however, you must do so before saving the child instance, as
ElasticSeach requires types that define parents to have a parent. The following
code block has the same outcome as the previous one:

```ruby
post = Post.new
blog.posts << post
```

In most other respects, the `blog.posts` collection behaves the same as a
search scope (more on that below), except that enumeration methods (`#each`,
`#map`, etc.) will return unsaved child instances along with instances
persisted in ElasticSearch.

### Syncing your mapping ###

Before you start creating documents with Elastictastic, you need to make
ElasticSearch aware of your document structure. To do this, use the
`sync_mapping` method:

```ruby
Post.sync_mapping
```

If you have a complex multi-index topology, you may want to consider using
[ElasticSearch templates](http://www.elasticsearch.org/guide/reference/api/admin-indices-templates.html)
to manage mappings and other index settings; Elastictastic doesn't provide any
explicit support for this at the moment, although you can use e.g.
`Post.mapping` to retrieve the mapping structure which you can then merge into
your template.

### Reserved Attributes ###

All `Elastictastic::Document` models have an `id` and an `index` field, which
combine to define the full resource locator for the document in ElasticSearch.
You should not define fields or methods with these names. You may, however, set
the id explicitly on new (not yet saved) model instances.

## Persistence ##

Elastictastic models are persisted the usual way, namely by calling `save`:

```ruby
post = Post.new
post.title = 'You know, for search.'
post.save
```

To retrieve a document from the data store, use `get`:

```ruby
Post.find('123')
```

You can look up multiple documents by ID:

```ruby
Post.find('123', '456')
```

You can also pass an array of IDs; the following will return a one-element
array:

```ruby
Post.find(['123'])
```

### Specifying the index ###

Elastictastic defines a default index for your documents. If you're using Rails,
the default index is your application's name suffixed with the current
environment; outside of Rails, the default index is simply "default". You can
change this using the `default_index` configuration key.

To persist a document to an index other than the default, set the `index`
attribute on the model; to retrieve a document from a non-default index, use
the `in_index` method:

```ruby
new_post = Post.in_index('my_special_index').new # create in an index
post = Post.in_index('my_special_index').get('123') # retrieve from an index
```

To retrieve documents from multiple indices at the same time, pass a hash into
`get` where the keys are index names and the values are the IDs you wish to
retrieve from that index:

```ruby
Post.get('default' => ['123', '456'], 'my_special_index' => '789')
```

## Search ##

ElasticSearch is, above all, a search tool. Accordingly, aside from direct
lookup by ID, all retrieval of documents is done via the
[search API](http://www.elasticsearch.org/guide/reference/api/search/).
Elastictastic models have class methods corresponding to the top-level keys
in the ElasticSearch search API; you may chain these much as in ActiveRecord
or Mongoid:

```ruby
Post.query(:query_string => { :query => 'pizza' }).facets(:cuisine => { :term => { :field => :tags }}).from(10).size(10)
# Generates { :query => { :query_string => { :query => 'pizza' }}, :facets => { :cuisine => { :term => { :field => :tags }}}, :from => 10, :size => 10 }
```

Elastictastic also has an alternate block-based query builder, if you prefer:

```ruby
Post.query do
  query_string { query('pizza') }
end.facets { cuisine { term { field :tags }}}.from(10).size(10)
# Same effect as the previous example
```

The scopes that are generated by the preceding calls act as collections of
matching documents; thus all the usual Enumerable methods are available:

```ruby
Post.query(:query_string => { :query => 'pizza' }).each do |post|
  puts post.title
end
```

You may access other components of the response using hash-style access; this
will return a `Hashie::Mash` which allows hash-style or object-style access:

```ruby
Post.facets(:cuisine => { :term => { :field => :tags }})['facets'].each_pair do |name, facet|
  facet.terms.each { |term| puts "#{term.term}: #{term.count}" }
end
```

You can also call `count` on a scope; this will give the total number of
documents matching the query.

In some situations, you may wish to access metadata about search results beyond
simply the result document. To do this, use the `#find_each` method, which
yields a `Hashie::Mash` containing the raw ElasticSearch hit object in the
second argument:

```ruby
Post.highlight { fields(:title => {}) }.find_each do |post, hit|
  puts "Post #{post.id} matched the query string in the title field: #{hit.highlight['title']}"
end
```

Search scope also expose a #find_in_batches method, which also yields the raw
hit. The following code gives the same result as the previous example:

```ruby
Post.highlight { fields(:title => {}) }.find_in_batches do |batch|
  batch.each do |post, hit|
    puts "Post #{post.id} matched the query string in the title field: #{hit.highlight['title']}"
  end
end
```

Both `find_each` and `find_in_batches` accept a :batch_size option.

## License ##

Elastictastic is distributed under the MIT license. See the attached LICENSE
file for all the sordid details.
