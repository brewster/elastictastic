class Author
  include Elastictastic::Resource

  field :id, :type => 'integer'
  field :name
  field :email, :index => 'not_analyzed'
end
