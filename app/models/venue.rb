class Venue < ApplicationRecord
  has_many :concerts, dependent: :nullify

  def display_location
    [city, country].compact_blank.join(", ")
  end
end
