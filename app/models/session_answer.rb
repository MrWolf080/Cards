class SessionAnswer < ApplicationRecord
  belongs_to :study_session
  belongs_to :card
  enum :rating, { forgot: 0, hard: 1, good: 2, easy: 3 }
end
