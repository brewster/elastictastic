class Author
  include Elastictastic::NestedDocument

  field :id, :type => 'integer'
  field :name
  field :email, :index => 'not_analyzed'
end
