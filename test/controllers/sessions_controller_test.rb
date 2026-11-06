require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { host! "web" }

  test "login sets a cookie and permits access until logout" do
    post "/api/v1/session", params: { email_address: users(:one).email_address, password: "password" }, as: :json
    assert_response :success
    assert cookies[:session_id].present?
    assert_equal users(:one).email_address, response.parsed_body.dig("user", "email")
    get "/api/v1/decks"
    assert_response :success
    assert_difference "Session.count", -1 do
      delete "/api/v1/session"
      assert_response :no_content
    end
    get "/api/v1/decks"
    assert_response :unauthorized
    get "/api/v1/current_user"
    assert_nil response.parsed_body["user"]
  end

  test "invalid credentials do not create a session" do
    assert_no_difference "Session.count" do
      post "/api/v1/session", params: { email_address: users(:one).email_address, password: "wrong" }, as: :json
      assert_response :unauthorized
    end
    assert_nil cookies[:session_id]
    get "/api/v1/decks"
    assert_response :unauthorized
  end

  test "duplicate registration is rejected without logging in" do
    assert_no_difference ["User.count", "Session.count"] do
      post "/api/v1/registration", params: { user: {
        email_address: users(:one).email_address.upcase, password: "password123", password_confirmation: "password123"
      } }, as: :json
      assert_response :unprocessable_entity
    end
    get "/api/v1/current_user"
    assert_nil response.parsed_body["user"]
  end
end