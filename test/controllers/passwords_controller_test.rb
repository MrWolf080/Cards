require "test_helper"

# Password recovery has no public routes in the current API.
class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { host! "web" }

  test "unavailable legacy password endpoints cannot reset passwords or send mail" do
    user = users(:one)
    original_digest = user.password_digest
    assert_no_enqueued_emails do
      get "/passwords/new"
      assert_response :not_found
      post "/passwords", params: { email_address: user.email_address }
      assert_response :not_found
      get "/passwords/#{user.password_reset_token}/edit"
      assert_response :not_found
      put "/passwords/#{user.password_reset_token}", params: { password: "new-password123", password_confirmation: "new-password123" }
      assert_response :not_found
    end
    assert_equal original_digest, user.reload.password_digest
  end
end