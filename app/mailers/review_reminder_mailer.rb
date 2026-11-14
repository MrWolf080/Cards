class ReviewReminderMailer < ApplicationMailer
  def daily
    @count = params.fetch(:count)
    @dashboard_url = "#{ENV.fetch('APP_URL', 'http://localhost:5173').delete_suffix('/')}/dashboard"
    mail(to: params.fetch(:user).email_address,
         from: ENV.fetch("MAIL_FROM", "from@example.com"),
         subject: "Карточки на сегодня")
  end
end
