class CardProgress < ApplicationRecord
  belongs_to :card
  enum :status, { new_card: 0, learning: 1, learned: 2 }
end
