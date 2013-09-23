# Elastictastic #

Elastictastic is an object-document mapper and lightweight API adapter for
[ElasticSearch](http://www.elasticsearch.org/). Elastictastic's primary use case
is to define model classes which use ElasticSearch as a primary
document-oriented data store, and to expose ElasticSearch's search functionality
to query for those models.

[![Build Status](https://secure.travis-ci.org/brewster/elastictastic.png)](http://travis-ci.org/brewster/elastictastic)

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
  include Elastictastic::Document

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

### Document Boost ###

Defining a
[document boost](http://www.elasticsearch.org/guide/reference/mapping/boost-field.html)
will increase or decrease a document's score in search results based on the
value of a field in the document. A boost of 1.0 is neutral. To define a boost
field, use the `boost` class macro:

```ruby
class Post
  include Elastictastic::Document

  field :score, :type => 'integer'
  boost :score
end
```

By default, if the boost field is empty, a score of 1.0 will be applied. You can
override this by passing a `'null_value'` option into the boost method.

### Embedded objects ###

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

The class that's embedded should include the `Elastictastic::NestedDocument` mixin,
which exposes the same configuration DSL as `Elastictastic::Document` but does
not give the class the functionality of a top-level persistent object:

```ruby
class Author
  include Elastictastic::NestedDocument

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

### Reserved attributes ###

All `Elastictastic::Document` models have an `id` and an `index` field, which
combine to define the full resource locator for the document in ElasticSearch.
You should not define fields or methods with these names. You may, however, set
the id explicitly on new (not yet saved) model instances.

### ActiveModel ###

Elastictastic documents include all the usual ActiveModel functionality:
validations, lifecycle hooks, observers, dirty-tracking, mass-assignment
security, and the like. If you would like to squeeze a bit of extra performance
out of the library at the cost of convenience, you can include the
`Elastictastic::BasicDocument` module instead of `Elastictastic::Document`.

## Persistence ##

Elastictastic models are persisted the usual way, namely by calling `save`:

```ruby
post = Post.new
post.title = 'You know, for search.'
post.save
```

To retrieve a document from the data store, use `find`:

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

For child documents, you **must** perform GET requests using the parent's
association collection:

```ruby
post = blog.posts.new
post.save

blog.posts.find(post.id) # this will return the post
Post.find(post.id)       # but this won't!
```

### Specifying the index ###

Elastictastic defines a default index for your documents. If you're using Rails,
the default index is your application's name suffixed with the current
environment; outside of Rails, the default index is simply "default". You can
change this using the `default_index` configuration key.

When you want to work with documents in an index other than the default, use
the `in_index` class method:

```ruby
new_post = Post.in_index('my_special_index').new # create in an index
post = Post.in_index('my_special_index').find('123') # retrieve from an index
```

To retrieve documents from multiple indices at the same time, pass a hash into
`find` where the keys are index names and the values are the IDs you wish to
retrieve from that index:

```ruby
Post.find('default' => ['123', '456'], 'my_special_index' => '789')
```

### Bulk operations ###

If you are writing a large amount of data to ElasticSearch in a single process,
use of the
[bulk API](http://www.elasticsearch.org/guide/reference/api/bulk.html)
is encouraged. To perform bulk operations using Elastictastic, simply wrap your
operations in a `bulk` block:

```ruby
Elastictastic.bulk do
  params[:posts].each do |post_params|
    post = Post.new(post_params)
    post.save
  end
end
```

All create, update, and destroy operations inside the block will be executed in
a single bulk request when the block completes. If you are performing an
indefinite number of operations in a bulk block, you can pass an `:auto_flush`
option to flush the bulk buffer after the specified number of operations:

```ruby
Elastictastic.bulk(:auto_flush => 100) do
  150.times { Post.new.save! }
end
```

The above will perform two bulk requests: the first after the first 100
operations, and the second when the block completes.

You can alternatively pass an `:auto_flush_bytes` option to flush the bulk buffer
after it reaches the specified number of bytes:

```ruby
Elastictastic.bulk(:auto_flush_bytes => 48 * 100) do
  150.times { Post.new.save! }
end
```

Assuming, as in the specs in this project. that 'Post.new.save!' sends a
48-byte operation to Elastic Search, this will cause two batches of requests:
one with 100 Posts, and one with 50.

Note that the nature of bulk writes means that any operation inside a bulk block
is essentially asynchronous: instances are not created, updated, or destroyed
immediately upon calling `save` or `destroy`, but rather when the bulk block
exits. You may pass a block to `save` and `destroy` to provide a callback for
when the instance is actually persisted and its local state updated. Let's say,
for instance, we wish to expand the example above to pass the IDs of the newly
created posts to our view layer:

```ruby
@ids = []
Elastictastic.bulk do
  params[:posts].each do |post_params|
    post = Post.new(post_params)
    post.save do |e|
      @ids << post.id
    end
  end
end
```

If the save was not successful (due to a duplicate ID or a version mismatch,
for instance), the `e` argument to the block will be passed an exception object;
if the save was successful, the argument will be nil.

### Concurrent document creation ###

When Elastictastic creates a document with an application-defined ID, it uses
the `_create` verb in ElasticSearch, ensuring that a document with that ID does
not already exist. If the document does already exist, an
`Elastictastic::ServerError::DocumentAlreadyExistsEngineException` will be
raised. In the case where multiple processes may attempt concurrent creation of
the same document, you can gracefully handle concurrent creation using the
`::create_or_update` class method on your document class. This will first
attempt to create the document; if a document with that ID already exists, it
will then load the document and modify it using the block passed:

```ruby
Post.create_or_update('1') do |post|
	post.title = 'My Post'
end
```

In the above case, Elastictastic will first attempt to create a new post with ID
"1" and title "My Post". If a Post with that ID already exists, it will load it,
set its title to "My Post", and save it. The update uses the `::update` method
(see next section) to ensure that concurrent modification doesn't cause data to
be lost.

### Optimistic locking ###

Elastictastic provides optimistic locking via ElasticSearch's built-in
[document versioning](http://www.elasticsearch.org/guide/reference/api/index_.html).
When a document is retrieved from persistence, it carries a version, which is a
number that increments from 1 on each update. When Elastictastic models are
updated, the document version that it carried when it was loaded is passed into
the update operation; if this version does not match ElasticSearch's current
version for that document, it indicates that another process has modified the
document concurrently, and an
`Elastictastic::ServerError::VersionConflictEngineException` is raised. This
prevents data loss through concurrent conflicting updates.

The easiest way to guard against concurrent modification is to use the
`::update` class method to make changes to existing documents. Consider the
following example:

```ruby
Post.update('12345') do |post|
  post.title = 'New Title'
end
```

In the above, the Post with ID '12345' is loaded from ElasticSearch and yielded
to the block. When the block completes, the instance is saved back to
ElasticSearch. If this save results in a version conflict, a new instance is
loaded from ElasticSearch and the block is run again. The process repeats until
a successful update.

This method will work inside a bulk operation, but note that if the first update
generates a version conflict, additional updates will occur in discrete
requests, not as part of any bulk operation.

If you wish to safely update documents retrieved from a search scope
(see below), use the `update_each` method:

```ruby
Post.query { constant_score { filter { term(:blog_id => 1) }}}.update_each do |post|
  post.title = post.title.upcase
end
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
# Generates {"query": {"query_string": {"query": "pizza"}}, "facets": {"cuisine": {"term": {"field": "tags" }}}, "from": 10, "size": 10}
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

Search scopes also expose a `#find_in_batches` method, which also yields the raw
hit. The following code gives the same result as the previous example:

```ruby
Post.highlight { fields(:title => {}) }.find_in_batches do |batch|
  batch.each do |post, hit|
    puts "Post #{post.id} matched the query string in the title field: #{hit.highlight['title']}"
  end
end
```

Both `find_each` and `find_in_batches` accept a `:batch_size` option.

## Support & Bugs ##

If you find a bug, feel free to
[open an issue](https://github.com/brewster/elastictastic/issues/new) on GitHub.
Pull requests are most welcome.

For questions or feedback, hit up our mailing list at
[elastictastic@groups.google.com](http://groups.google.com/group/elastictastic)
or find outoftime on the #elasticsearch IRC channel on Freenode.

## License ##

Elastictastic is distributed under the MIT license. See the attached LICENSE
file for all the sordid details.
