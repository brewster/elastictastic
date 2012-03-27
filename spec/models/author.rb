class Author
  include Elastictastic::EmbeddedDocument

  field :id, :type => 'integer'
  field :name
  field :email, :index => 'not_analyzed'

  validates :name, :exclusion => %w(INVALID)
end
