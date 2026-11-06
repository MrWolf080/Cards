class Card < ApplicationRecord
  after_commit :broadcast_change, on: [:create, :destroy]

  private def broadcast_change
    UserUpdatesChannel.broadcast_to(deck.user, type: "card.changed", data: { deck_id: deck_id, card_id: id })
  end

  belongs_to :deck
  has_one :card_progress, dependent: :destroy
  has_many :session_answers, dependent: :destroy

  # Срок повторения наступил. Новые карточки (next_review_at = NULL) сюда не входят.
  scope :due_today, -> {
    joins(:card_progress).where(card_progresses: { next_review_at: ..Date.current })
  }

  # Доступны для занятия: просроченные и новые
  scope :available_today, -> {
    joins(:card_progress).where(
      'card_progresses.next_review_at IS NULL OR card_progresses.next_review_at <= ?', Date.current
    )
  }
end
