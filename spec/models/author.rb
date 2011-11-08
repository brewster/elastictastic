class Author
  include Elastictastic::NestedDocument

  field :id, :type => 'integer'
  field :name
  field :email, :index => 'not_analyzed'

  validates :name, :exclusion => %w(INVALID)
end
