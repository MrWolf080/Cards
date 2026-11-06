class StudySession < ApplicationRecord
  after_update_commit :broadcast_finish, if: -> { saved_change_to_finished_at? && finished_at.present? }

  private def broadcast_finish
    UserUpdatesChannel.broadcast_to(user, type: "session.finished", data: { deck_id: deck_id, session_id: id })
  end

  belongs_to :user
  belongs_to :deck
  has_many :session_answers, dependent: :destroy
  enum :mode, { cards: 0, quiz: 1 }
end
