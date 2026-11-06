module Api
  module V1
    class ProfilesController < ApplicationController
      def show
        render json: profile_data
      end

      def update
        if Current.user.update(params.require(:profile).permit(:daily_goal, :time_zone))
          render json: profile_data
        else
          render json: { errors: Current.user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def profile_data
        {
          email: Current.user.email_address,
          daily_goal: Current.user.daily_goal,
          time_zone: Current.user.time_zone,
          time_zones: ActiveSupport::TimeZone.all.map { |zone| { value: zone.name, label: zone.to_s } }
        }
      end
    end
  end
end
