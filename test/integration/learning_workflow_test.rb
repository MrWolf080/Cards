require "test_helper"

class LearningWorkflowTest < ActionDispatch::IntegrationTest
  setup { host! "web" }

  test "registration profile deck dictionary study and statistics work together" do
    post "/api/v1/registration", params: { user: {
      email_address: "learner@example.com", password: "password123", password_confirmation: "password123"
    } }, as: :json
    assert_response :created
    assert cookies[:session_id].present?

    patch "/api/v1/profile", params: { profile: { daily_goal: 4, time_zone: "UTC" } }, as: :json
    assert_response :success
    post "/api/v1/decks", params: { deck: { title: "First words", direction: "en_ru" } }, as: :json
    assert_response :created
    deck_id = response.parsed_body["id"]
    entries = 4.times.map { |i| create_entry(en: "word#{i}", ru: "перевод#{i}", example_en: "Example #{i}") }
    entries.each do |entry|
      post "/api/v1/decks/#{deck_id}/cards", params: { dictionary_entry_id: entry.id, front: "forged" }, as: :json
      assert_response :created
      card = Card.where(deck_id: deck_id).order(:id).last
      assert_equal entry.en, card.front
      assert_equal entry.ru, card.back
      assert_equal entry.example_en, card.example
      assert card.card_progress.new_card?
    end

    get "/api/v1/decks/#{deck_id}/study"
    assert_response :success
    session_id = response.parsed_body["session_id"]
    cards = response.parsed_body["cards"]
    assert_equal 4, cards.size
    %w[forgot hard good easy].each_with_index do |rating, index|
      post "/api/v1/decks/#{deck_id}/study/answer",
        params: { session_id: session_id, card_id: cards[index]["id"], rating: rating }, as: :json
      assert_response :success
      progress = Card.find(cards[index]["id"]).card_progress
      assert_equal [0, 0, 1, 2][index], progress.level
      assert_equal Date.current + [1, 2, 4, 7][index], progress.next_review_at
    end
    post "/api/v1/decks/#{deck_id}/study/finish", params: { session_id: session_id }, as: :json
    assert_response :success

    get "/api/v1/stats"
    assert_response :success
    assert_equal 4, response.parsed_body["new_cards_today"]
    assert_equal 4, response.parsed_body["daily_goal"]
    assert_equal 75, response.parsed_body["accuracy"]
    assert_equal 4, response.parsed_body["history"].first["total"]
    assert_equal "Карточки", response.parsed_body["history"].first["mode"]
    assert_no_difference "StudySession.count" do
      get "/api/v1/decks/#{deck_id}/study"
      assert_empty response.parsed_body["cards"]
    end
  end

  test "spaced easy answers learn a word and forgetting resets its progress" do
    sign_in_as(users(:one))
    deck = create_deck
    card = create_card(deck: deck)
    travel_to Time.utc(2026, 11, 6, 12) do
      [2, 4, 5].each_with_index do |level, index|
        travel 7.days unless index.zero?
        get "/api/v1/decks/#{deck.id}/study"
        session_id = response.parsed_body["session_id"]
        post "/api/v1/decks/#{deck.id}/study/answer",
          params: { session_id: session_id, card_id: card.id, rating: "easy" }, as: :json
        assert_response :success
        assert_equal level, card.card_progress.reload.level
        post "/api/v1/decks/#{deck.id}/study/finish", params: { session_id: session_id }, as: :json
      end
      assert card.card_progress.reload.learned?
      assert_equal Date.current + 14, card.card_progress.next_review_at
      get "/api/v1/decks"
      assert_equal 1, response.parsed_body.find { |row| row["id"] == deck.id }["learned_cards"]

      travel 14.days
      get "/api/v1/decks/#{deck.id}/study"
      post "/api/v1/decks/#{deck.id}/study/answer",
        params: { session_id: response.parsed_body["session_id"], card_id: card.id, rating: "forgot" }, as: :json
      assert_response :success
      assert card.card_progress.reload.learning?
      assert_equal 0, card.card_progress.level
      assert_equal Date.current + 1, card.card_progress.next_review_at
      get "/api/v1/stats"
      assert_equal 0, response.parsed_body["new_cards_today"], "A later repetition is not a new card"
    end
  end

  test "quiz offers deck translations and stores a complete session result" do
    sign_in_as(users(:one))
    deck = create_deck
    4.times { |i| create_card(deck: deck, front: "word#{i}", back: "translation#{i}") }
    get "/api/v1/decks/#{deck.id}/quiz"
    assert_response :success
    session_id = response.parsed_body["session_id"]
    questions = response.parsed_body["questions"]
    questions.each_with_index do |question, index|
      assert_equal 4, question["options"].uniq.size
      assert_includes question["options"], question["correct_answer"]
      assert_equal deck.cards.pluck(:back).sort, question["options"].sort
      post "/api/v1/decks/#{deck.id}/study/answer", params: {
        session_id: session_id, card_id: question["card_id"], rating: index.zero? ? "forgot" : "good"
      }, as: :json
      assert_response :success
    end
    post "/api/v1/decks/#{deck.id}/study/finish", params: { session_id: session_id }, as: :json
    assert_response :success
    get "/api/v1/stats"
    assert_equal "Тест", response.parsed_body["history"].first["mode"]
    assert_equal 3, response.parsed_body["history"].first["correct"]
    assert_equal 75, response.parsed_body["history"].first["percent"]
  end
end
