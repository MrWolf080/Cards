module Api
  module V1
    class CurrentUsersController < ApplicationController
      allow_unauthenticated_access only: :show

      def show
        if authenticated?
          render json: { user: { email: Current.user.email_address } }
        else
          render json: { user: nil }, status: :ok
        end
      end
    end
  end
end