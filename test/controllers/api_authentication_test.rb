require "test_helper"

class ApiAuthenticationTest < ActionDispatch::IntegrationTest
  setup { host! "web" }

  test "guests receive JSON unauthorized for protected API endpoints" do
    ["/api/v1/dashboard", "/api/v1/decks", "/api/v1/decks/1",
     "/api/v1/decks/1/cards", "/api/v1/decks/1/suggestions",
     "/api/v1/decks/1/study", "/api/v1/decks/1/quiz", "/api/v1/stats"].each do |path|
      get path

      assert_response :unauthorized
      assert_equal "application/json", response.media_type
      assert_equal "Необходим вход в аккаунт", response.parsed_body["error"]
    end
  end

  test "guests cannot create decks" do
    assert_no_difference "Deck.count" do
      post "/api/v1/decks", params: { deck: { title: "Guest deck", direction: "en_ru" } }, as: :json
    end

    assert_response :unauthorized
  end

  test "current user endpoint remains available to guests" do
    get "/api/v1/current_user"

    assert_response :success
    assert_nil response.parsed_body["user"]
  end

  test "signed in users can access their decks" do
    sign_in_as(User.take)

    get "/api/v1/decks"

    assert_response :success
    assert_kind_of Array, response.parsed_body
  end

  test "deleted sessions no longer authorize requests" do
    sign_in_as(User.take)
    Current.session.destroy!
    Current.reset

    get "/api/v1/decks"

    assert_response :unauthorized
  end
end
