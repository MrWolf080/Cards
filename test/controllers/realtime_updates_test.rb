require "test_helper"

class RealtimeUpdatesTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  setup do
    host! "web"
    @user = users(:one)
    sign_in_as(@user)
    @deck = create_deck(user: @user)
    @stream = UserUpdatesChannel.broadcasting_for(@user)
  end

  test "card creation and deletion notify only the owner" do
    entry = create_entry
    other_stream = UserUpdatesChannel.broadcasting_for(users(:two))
    assert_no_broadcasts(other_stream) do
      assert_broadcasts(@stream, 1) do
        post "/api/v1/decks/#{@deck.id}/cards", params: { dictionary_entry_id: entry.id }, as: :json
        assert_response :created
      end
    end
    card = @deck.cards.last
    assert card.card_progress.present?
    assert_broadcast_on(@stream, type: "card.changed", data: { deck_id: @deck.id, card_id: card.id }) do
      delete "/api/v1/decks/#{@deck.id}/cards/#{card.id}"
      assert_response :no_content
    end
  end

  test "reviews and finishing sessions broadcast the required events" do
    card = create_card(deck: @deck)
    session = create_study_session(deck: @deck)
    assert_broadcast_on(@stream, type: "card.reviewed", data: { deck_id: @deck.id, card_id: card.id }) do
      post "/api/v1/decks/#{@deck.id}/study/answer",
        params: { card_id: card.id, session_id: session.id, rating: "good" }, as: :json
      assert_response :success
    end
    assert_equal 1, card.card_progress.reload.level
    assert_broadcast_on(@stream, type: "session.finished", data: { deck_id: @deck.id, session_id: session.id }) do
      post "/api/v1/decks/#{@deck.id}/study/finish", params: { session_id: session.id }, as: :json
      assert_response :success
    end
  end

  test "deck changes include deletion information and cascade safely" do
    assert_broadcast_on(@stream, type: "deck.changed", data: { deck_id: @deck.id, deleted: false }) do
      @deck.update!(title: "Renamed")
    end
    create_card(deck: @deck)
    assert_broadcast_on(@stream, type: "deck.changed", data: { deck_id: @deck.id, deleted: true }) do
      delete "/api/v1/decks/#{@deck.id}"
      assert_response :no_content
    end
  end

  test "unauthorized changes do not broadcast" do
    other_deck = create_deck(user: users(:two))
    assert_no_broadcasts(@stream) do
      delete "/api/v1/decks/#{other_deck.id}"
      assert_response :not_found
    end
  end

  test "rolled back changes do not broadcast" do
    assert_no_broadcasts(@stream) do
      Deck.transaction do
        @deck.update!(title: "Rolled back")
        raise ActiveRecord::Rollback
      end
    end
  end
end
