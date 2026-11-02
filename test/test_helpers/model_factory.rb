# Простые «фабрики» для тестов моделей: создают связанные записи одной строкой.
# Подключаются в test/test_helper.rb.
module ModelFactory
  def create_user(email: "user-#{SecureRandom.hex(4)}@example.com", password: "password123")
    User.create!(email_address: email, password: password, password_confirmation: password)
  end

  def create_deck(user: users(:one), title: "English B1", direction: :en_ru)
    user.decks.create!(title: title, direction: direction)
  end

  # Карточка вместе с записью прогресса (как это делает CardsController#create)
  def create_card(deck: nil, front: "luggage", back: "багаж", example: nil,
                  status: :new_card, level: 0, next_review_at: nil)
    deck ||= create_deck
    card = deck.cards.create!(front: front, back: back, example: example)
    card.create_card_progress!(level: level, status: status, next_review_at: next_review_at)
    card
  end

  def create_study_session(deck: nil, user: nil, mode: :cards, finished_at: nil)
    deck ||= create_deck
    user ||= deck.user
    StudySession.create!(user: user, deck: deck, mode: mode,
                         started_at: Time.current, finished_at: finished_at)
  end

  def create_answer(session:, card:, rating: nil, is_correct: true)
    SessionAnswer.create!(study_session: session, card: card, rating: rating, is_correct: is_correct)
  end

  def create_entry(en: "luggage", ru: "багаж", **extra)
    DictionaryEntry.create!({ en: en, ru: ru }.merge(extra))
  end
end
