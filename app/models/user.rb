class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :decks, dependent: :destroy
  has_many :study_sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :daily_goal, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1000 }
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

  # One card counts once, on the date of its first answer in either study mode.
  def new_cards_studied_today
    first_answers = SessionAnswer.joins(:study_session)
      .where(study_sessions: { user_id: id })
      .group(:card_id)
      .having("MIN(session_answers.created_at) >= ? AND MIN(session_answers.created_at) < ?",
              Time.current.beginning_of_day, Time.current.tomorrow.beginning_of_day)
      .select(:card_id)
    SessionAnswer.where(card_id: first_answers).distinct.count(:card_id)
  end

  validates :email_address,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password,
            length: { minimum: 8 },
            allow_nil: true,   # при обновлении пользователя без смены пароля
            confirmation: true
end
