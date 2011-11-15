class Blog
  include Elastictastic::Document

  field :name

  has_many :posts
end
