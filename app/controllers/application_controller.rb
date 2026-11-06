class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Authentication

  around_action :use_user_time_zone

  private

  def use_user_time_zone(&action)
    Time.use_zone(Current.user&.time_zone || "UTC", &action)
  end
end
