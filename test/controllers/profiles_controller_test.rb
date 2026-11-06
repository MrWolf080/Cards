require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "web"
    @user = users(:one)
  end

  test "profile requires authentication" do
    get "/api/v1/profile"
    assert_response :unauthorized
    patch "/api/v1/profile", params: { profile: { daily_goal: 30 } }, as: :json
    assert_response :unauthorized
  end

  test "profile shows defaults and saves only current user settings" do
    sign_in_as(@user)
    get "/api/v1/profile"
    assert_response :success
    assert_equal 20, response.parsed_body["daily_goal"]
    assert_equal "UTC", response.parsed_body["time_zone"]
    other = create_user
    original_email = @user.email_address

    patch "/api/v1/profile", params: { profile: {
      daily_goal: 35, time_zone: "Moscow", email_address: "changed@example.com", id: other.id
    } }, as: :json

    assert_response :success
    assert_equal 35, @user.reload.daily_goal
    assert_equal "Moscow", @user.time_zone
    assert_equal original_email, @user.email_address
    assert_equal 20, other.reload.daily_goal
  end

  test "invalid settings are rejected without partial updates" do
    sign_in_as(@user)
    [0, -1, 1001, 1.5, nil, "abc"].each do |goal|
      patch "/api/v1/profile", params: { profile: { daily_goal: goal, time_zone: "Moscow" } }, as: :json
      assert_response :unprocessable_entity
      assert_equal 20, @user.reload.daily_goal
      assert_equal "UTC", @user.time_zone
    end
    patch "/api/v1/profile", params: { profile: { daily_goal: 30, time_zone: "Invalid/Zone" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 20, @user.reload.daily_goal
  end

  test "dashboard and stats count first answers in the user local day across both modes" do
    @user.update!(time_zone: "Moscow", daily_goal: 30)
    sign_in_as(@user)
    travel_to Time.utc(2026, 11, 6, 22, 30) do
      deck = create_deck(user: @user)
      session = create_study_session(deck: deck, finished_at: Time.current)
      quiz = create_study_session(deck: deck, mode: :quiz)
      old_card = create_card(deck: deck)
      new_card = create_card(deck: deck)
      quiz_card = create_card(deck: deck)
      session.session_answers.create!(card: old_card, rating: :good, created_at: Time.utc(2026, 11, 6, 20, 59))
      session.session_answers.create!(card: old_card, rating: :good)
      session.session_answers.create!(card: new_card, rating: :forgot, created_at: Time.utc(2026, 11, 6, 21))
      session.session_answers.create!(card: new_card, rating: :good)
      quiz.session_answers.create!(card: quiz_card, rating: :good)
      other_card = create_card(deck: create_deck(user: create_user))
      create_answer(session: create_study_session(deck: other_card.deck), card: other_card)

      ["/api/v1/dashboard", "/api/v1/stats"].each do |path|
        get path
        assert_response :success
        assert_equal 2, response.parsed_body["new_cards_today"]
        assert_equal 30, response.parsed_body["daily_goal"]
      end

      travel 1.day
      get "/api/v1/stats"
      assert_equal 0, response.parsed_body["new_cards_today"]
    end
  end
end
