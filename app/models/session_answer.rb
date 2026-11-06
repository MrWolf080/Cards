class SessionAnswer < ApplicationRecord
  after_create_commit :broadcast_review

  private def broadcast_review
    UserUpdatesChannel.broadcast_to(study_session.user, type: "card.reviewed",
      data: { deck_id: study_session.deck_id, card_id: card_id })
  end

  belongs_to :study_session
  belongs_to :card
  enum :rating, { forgot: 0, hard: 1, good: 2, easy: 3 }
end
