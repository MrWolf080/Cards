class Card < ApplicationRecord
  belongs_to :deck
  has_one :card_progress, dependent: :destroy
  has_many :session_answers, dependent: :destroy

  # Срок повторения наступил. Новые карточки (next_review_at = NULL) сюда не входят.
  scope :due_today, -> {
    joins(:card_progress).where(card_progresses: { next_review_at: ..Date.today })
  }

  # Доступны для занятия: просроченные и новые
  scope :available_today, -> {
    joins(:card_progress).where(
      'card_progresses.next_review_at IS NULL OR card_progresses.next_review_at <= ?', Date.today
    )
  }
end
