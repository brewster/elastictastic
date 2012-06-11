class Photo
  include Elastictastic::Document

  field :post_id, :type => 'integer'
  field :path
  field :caption

  route_with :post_id, :required => true
end
