module Api
  module V1
    class RegistrationsController < ApplicationController
      allow_unauthenticated_access only: :create

      def create
        @user = User.new(user_params)
        if @user.save
          start_new_session_for @user
          render json: { user: { email: @user.email_address } }, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        render json: { errors: ["Email уже зарегистрирован"] }, status: :unprocessable_entity
      end

      private

      def user_params
        params.require(:user).permit(:email_address, :password, :password_confirmation)
      end
    end
  end
end