class Newsarticle < ActiveRecord::Base
  require 'popularity'
  include PopularityPast

  has_many :streams, as: :streamable
  has_many :likes, as: :likable
  has_one :popularity, as: :popularable, dependent: :destroy

end
