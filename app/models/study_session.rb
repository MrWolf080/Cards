class StudySession < ApplicationRecord
  belongs_to :user
  belongs_to :deck
  has_many :session_answers, dependent: :destroy
  enum :mode, { cards: 0, quiz: 1 }
end
