class ReviewRemindersJob < ApplicationJob
  def perform
    return if Rails.env.production? && ENV["SMTP_ADDRESS"].blank?

    now = Time.current
    dates = (now.to_date - 1)..(now.to_date + 1)
    User.joins(decks: { cards: :card_progress })
      .where(card_progresses: { next_review_at: dates }).distinct.find_each do |user|
      local_time = now.in_time_zone(user.time_zone)
      date = local_time.to_date
      next if local_time.hour < 9 || user.review_reminder_sent_on == date
      next unless Card.joins(:card_progress).where(deck: user.decks)
        .exists?(card_progresses: { next_review_at: date })

      ReviewReminderJob.perform_later(user.id, date.iso8601)
    end
  end
end
