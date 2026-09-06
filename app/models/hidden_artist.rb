class HiddenArtist < ApplicationRecord
  belongs_to :user

  validates :spotify_artist_id, presence: true,
    uniqueness: { scope: :user_id }
end
