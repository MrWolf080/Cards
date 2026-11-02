class Deck < ApplicationRecord
  belongs_to :user
  has_many :cards, dependent: :destroy
  has_many :study_sessions, dependent: :destroy

  # 0 - en_ru, 1 - ru_en
  enum :direction, { en_ru: 0, ru_en: 1 }
end
