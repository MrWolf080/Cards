require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "valid with a user" do
    assert Session.new(user: users(:one)).valid?
  end

  test "invalid without a user" do
    session = Session.new
    assert_not session.valid?
    assert_includes session.errors.attribute_names, :user
  end

  test "is reachable through user.sessions" do
    session = users(:one).sessions.create!
    assert_includes users(:one).sessions, session
  end
end
