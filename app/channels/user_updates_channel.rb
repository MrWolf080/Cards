class UserUpdatesChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_session && Session.exists?(current_session.id)

    stream_for current_user
  end
end
