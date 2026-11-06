require "test_helper"

class DeckAccessTest < ActionDispatch::IntegrationTest
  setup do
    host! "web"
    sign_in_as(users(:one))
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
      delete "/api/v1/decks/#{deck.id}"
      assert_response :not_found
    end
    assert_nil session.reload.finished_at
    assert_equal 0, card.card_progress.reload.level
    get "/api/v1/decks"
    assert_empty response.parsed_body
  end
end
