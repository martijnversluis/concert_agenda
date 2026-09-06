class Artist < ApplicationRecord
  has_many :concerts, dependent: :nullify

  validates :name, :name_normalized, presence: true

  def self.for_concert_name(name)
    normalized = Concert.normalize_name(name)
    find_or_create_by!(name_normalized: normalized) do |a|
      a.name = name
    end
  end
end
