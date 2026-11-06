require "test_helper"

class LiveStudyTest < ActionDispatch::IntegrationTest
  setup do
    host! "web"
    @user = users(:one)
    sign_in_as(@user)
    @deck = create_deck(user: @user)
    @cards = 4.times.map { |i| create_card(deck: @deck, front: "word#{i}", back: "translation#{i}") }
  end

  test "refresh reuses the session and reflects reviews in either mode" do
    ["study", "quiz"].each do |mode|
      get "/api/v1/decks/#{@deck.id}/#{mode}"
      session_id = response.parsed_body["session_id"]
      key = mode == "quiz" ? "questions" : "cards"
      assert_equal 4, response.parsed_body[key].size
      card = @cards.first
      post "/api/v1/decks/#{@deck.id}/study/answer",
        params: { session_id: session_id, card_id: card.id, rating: "good" }, as: :json
      assert_response :success
      assert_no_difference "StudySession.count" do
        get "/api/v1/decks/#{@deck.id}/#{mode}", params: { session_id: session_id }
      end
      assert_equal session_id, response.parsed_body["session_id"]
      assert_equal 3, response.parsed_body[key].size
      assert_equal 1, response.parsed_body["answered_count"]
      assert_equal 1, response.parsed_body["correct_count"]
      card.card_progress.reload.update!(next_review_at: nil)
    end
  end

  test "finished session snapshot does not create another session" do
    session = create_study_session(deck: @deck, finished_at: Time.current)
    assert_no_difference "StudySession.count" do
      get "/api/v1/decks/#{@deck.id}/study", params: { session_id: session.id }
    end
    assert_response :success
    assert response.parsed_body["finished"]
    assert_empty response.parsed_body["cards"]
  end

  test "snapshot cannot access another users session or wrong mode" do
    other = create_study_session(deck: create_deck(user: users(:two)))
    get "/api/v1/decks/#{@deck.id}/study", params: { session_id: other.id }
    assert_response :not_found
    quiz = create_study_session(deck: @deck, mode: :quiz)
    get "/api/v1/decks/#{@deck.id}/study", params: { session_id: quiz.id }
    assert_response :not_found
  end

  test "duplicate ratings and ratings after session finish do not change progress" do
    session = create_study_session(deck: @deck)
    params = { session_id: session.id, card_id: @cards.first.id, rating: "good" }
    post "/api/v1/decks/#{@deck.id}/study/answer", params: params, as: :json
    assert_response :success
    assert_no_difference "SessionAnswer.count" do
      post "/api/v1/decks/#{@deck.id}/study/answer", params: params, as: :json
      assert_response :conflict
    end
    assert_equal 1, @cards.first.card_progress.reload.level
    session.update!(finished_at: Time.current)
    assert_no_difference "SessionAnswer.count" do
      post "/api/v1/decks/#{@deck.id}/study/answer", params: params.merge(card_id: @cards.last.id), as: :json
      assert_response :conflict
    end
  end
end
