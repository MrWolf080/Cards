class Deck < ApplicationRecord
  after_commit :broadcast_change, on: [:create, :update, :destroy]

  private def broadcast_change
    UserUpdatesChannel.broadcast_to(user, type: "deck.changed", data: { deck_id: id, deleted: destroyed? })
  end

  belongs_to :user
  has_many :cards, dependent: :destroy
  has_many :study_sessions, dependent: :destroy

  # 0 - en_ru, 1 - ru_en
  enum :direction, { en_ru: 0, ru_en: 1 }
end
