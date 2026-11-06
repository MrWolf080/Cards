require "test_helper"

class UserUpdatesChannelTest < ActionCable::Channel::TestCase
  test "stream is derived from the authenticated user rather than client parameters" do
    user = users(:one)
    session = user.sessions.create!
    stub_connection current_user: user, current_session: session
    subscribe(user_id: users(:two).id)
    assert subscription.confirmed?
    assert_has_stream_for user
    assert_equal [UserUpdatesChannel.broadcasting_for(user)], subscription.streams
  end

  test "revoked sessions cannot subscribe" do
    session = users(:one).sessions.create!
    session.destroy!
    stub_connection current_user: users(:one), current_session: session
    subscribe
    assert subscription.rejected?
    assert_no_streams
  end
end

class CableConnectionTest < ActionCable::Connection::TestCase
  tests ApplicationCable::Connection

  test "guests are rejected" do
    assert_reject_connection { connect }
  end

  test "signed session authenticates the connection" do
    session = users(:one).sessions.create!
    cookies.signed[:session_id] = session.id
    connect
    assert_equal users(:one), connection.current_user
    assert_equal session, connection.current_session
  end

  test "expired session cookies are rejected" do
    session = users(:one).sessions.create!
    cookies.signed[:session_id] = session.id
    session.destroy!
    assert_reject_connection { connect }
  end
end
