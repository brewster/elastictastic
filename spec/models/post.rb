class Post
  include Elastictastic::Document

  field :title
  field :comments_count, :type => 'integer'
  field :score, :type => 'integer'
  field :tags, :index => 'analyzed' do
    field :non_analyzed, :index => 'not_analyzed'
  end
  field :created_at, :type => 'date'
  field :published_at, :type => 'date'

  embed :author
  embed :comments

  belongs_to :blog

  attr_accessible :title

  validates :title, :exclusion => %w(INVALID)

  def observers_that_ran
    @observers_that_ran ||= Set[]
  end

  def self.search_keywords(keywords)
    query do
      query_string do
        query(keywords)
        fields 'title', 'body'
      end
    end
  end

  def self.from_hash(hash)
    new.tap do |post|
      hash.each_pair do |field, value|
        post.__send__("#{field}=", value)
      end
    end
  end
end
