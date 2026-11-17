require "test_helper"

class DeckAccessTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  test "suggestions use popularity then frequency and skips belong to the current user" do
    deck = create_deck
    frequent = create_entry(en: "first", ru: "первый", rank: 1)
    popular = create_entry(en: "second", ru: "второй", rank: 2)
    create_entry(en: "second", ru: "секунда", rank: 3)
    other_deck = create_deck(user: users(:two))
    path = "/api/v1/decks/#{deck.id}/suggestions"

    get path
    assert_equal [frequent.id, popular.id], response.parsed_body.pluck("id")
    post "/api/v1/decks/#{deck.id}/cards", params: { dictionary_entry_id: popular.id }, as: :json
    assert_response :created
    assert_equal 1, popular.reload.popular

    sign_in_as(users(:two))
    other_path = "/api/v1/decks/#{other_deck.id}/suggestions"
    get other_path
    assert_equal [popular.id, frequent.id], response.parsed_body.pluck("id")
    post "#{other_path}/skip", params: { ids: [popular.id] }, as: :json
    assert_equal [frequent.id], response.parsed_body.pluck("id")
    get other_path
    assert_equal [frequent.id], response.parsed_body.pluck("id")
    assert_empty users(:one).dictionary_views
    delete "/api/v1/dictionary/views"
    assert_response :no_content
    get other_path
    assert_equal [popular.id, frequent.id], response.parsed_body.pluck("id")
  end

  setup do
    host! "web"
    sign_in_as(users(:one))
  end

  test "custom cards are validated and edits preserve progress and answers" do
    deck = create_deck
    path = "/api/v1/decks/#{deck.id}/cards"
    assert_no_difference ["Card.count", "CardProgress.count"] do
      post path, params: { card: { front: "   ", back: "перевод" } }, as: :json
      assert_response :unprocessable_entity
    end

    post path, params: { card: { front: "  acomplish ", back: "выполнить" } }, as: :json
    assert_response :created
    card = deck.cards.sole
    assert_equal "acomplish", card.front
    assert card.card_progress.new_card?
    assert_equal 0, card.card_progress.level
    progress = card.card_progress
    progress.update!(status: :learning, level: 2, next_review_at: Date.current + 3)
    original_progress = progress.attributes
    answer = create_answer(session: create_study_session(deck: deck), card: card, rating: :easy)

    assert_broadcast_on(UserUpdatesChannel.broadcasting_for(deck.user),
      type: "card.changed", data: { deck_id: deck.id, card_id: card.id }) do
      patch "#{path}/#{card.id}", params: { card: { front: "accomplish", example: "I want to accomplish my goal." } }, as: :json
      assert_response :no_content
    end
    assert_equal original_progress, progress.reload.attributes
    assert_equal card.id, answer.reload.card_id
    get path
    assert_equal "accomplish", response.parsed_body.first["front"]
    assert_equal "I want to accomplish my goal.", response.parsed_body.first["example"]

    patch "#{path}/#{card.id}", params: { card: { back: "" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "выполнить", card.reload.back
  end

  test "dictionary content is copied in the selected direction and deletion removes progress" do
    deck = create_deck(direction: :ru_en)
    entry = create_entry(en: "borrow", ru: "занимать", example_en: "Borrow a book")
    post "/api/v1/decks/#{deck.id}/cards", params: { dictionary_entry_id: entry.id }, as: :json
    assert_response :created
    card = deck.cards.last
    assert_equal "занимать", card.front
    assert_equal "borrow", card.back
    entry.update!(ru: "другой перевод")
    get "/api/v1/decks/#{deck.id}/cards"
    assert_equal "занимать", response.parsed_body.first["front"]
    assert_difference ["Card.count", "CardProgress.count"], -1 do
      delete "/api/v1/decks/#{deck.id}/cards/#{card.id}"
      assert_response :no_content
    end
  end

  test "foreign deck endpoints cannot read or mutate another users data" do
    deck = create_deck(user: users(:two))
    card = create_card(deck: deck)
    session = create_study_session(deck: deck)
    entry = create_entry
    own_deck = create_deck
    assert_no_difference ["Deck.count", "Card.count", "CardProgress.count", "SessionAnswer.count"] do
      %W[/api/v1/decks/#{deck.id} /api/v1/decks/#{deck.id}/cards /api/v1/decks/#{deck.id}/suggestions /api/v1/decks/#{deck.id}/study /api/v1/decks/#{deck.id}/quiz].each do |path|
        get path
        assert_response :not_found
      end
      post "/api/v1/decks/#{deck.id}/cards", params: { dictionary_entry_id: entry.id }, as: :json
      assert_response :not_found
      post "/api/v1/decks/#{deck.id}/study/answer", params: { session_id: session.id, card_id: card.id, rating: "easy" }, as: :json
      assert_response :not_found
      post "/api/v1/decks/#{deck.id}/study/finish", params: { session_id: session.id }, as: :json
      assert_response :not_found
      delete "/api/v1/decks/#{deck.id}/cards/#{card.id}"
      assert_response :not_found
      patch "/api/v1/decks/#{deck.id}/cards/#{card.id}", params: { card: { front: "Forbidden edit" } }, as: :json
      assert_response :not_found
      patch "/api/v1/decks/#{own_deck.id}/cards/#{card.id}", params: { card: { front: "Forbidden edit" } }, as: :json
      assert_response :not_found
      delete "/api/v1/decks/#{deck.id}"
      assert_response :not_found
    end
    assert_nil session.reload.finished_at
    assert_equal 0, card.card_progress.reload.level
    get "/api/v1/decks"
    assert_equal [own_deck.id], response.parsed_body.pluck("id")
  end
end
