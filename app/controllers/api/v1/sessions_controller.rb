module Api
  module V1
    class SessionsController < ApplicationController
      # Разрешаем доступ без авторизации (для входа)
      allow_unauthenticated_access only: :create

      # Если сработает Rate Limit (много попыток входа),
      # возвращаем JSON с ошибкой, а НЕ редирект на HTML-страницу
      #rate_limit to: 10, within: 1.minutes, only: :create,
      #          with: -> { render json: { error: "Слишком много попыток. Попробуйте позже." }, status: :too_many_requests }

      def create
        if user = User.authenticate_by(params.permit(:email_address, :password))
          start_new_session_for user
          render json: { user: { email: user.email_address } }, status: :ok
        else
          # Если пароль неверный — возвращаем 401 статус и JSON
          render json: { error: "Неверный email или пароль" }, status: :unauthorized
        end
      end

      def destroy
        terminate_session
        head :no_content
      end
    end
  end
end