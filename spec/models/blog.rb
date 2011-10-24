class Blog
  include Elastictastic::Document

  has_many :posts
end
