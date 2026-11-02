require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "user is taken from the current session" do
    Current.session = users(:one).sessions.create!
    assert_equal users(:one), Current.user
  end

  test "user is nil when there is no session" do
    assert_nil Current.user
  end
end
