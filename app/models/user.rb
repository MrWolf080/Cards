class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :decks, dependent: :destroy
  has_many :study_sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password,
            length: { minimum: 8 },
            allow_nil: true,   # при обновлении пользователя без смены пароля
            confirmation: true
end
