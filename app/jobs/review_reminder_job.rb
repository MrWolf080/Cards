class ReviewReminderJob < ApplicationJob
  def perform(user_id, scheduled_date)
    user = User.find_by(id: user_id)
    return unless user

    user.with_lock do
      today = Time.current.in_time_zone(user.time_zone).to_date
      next if scheduled_date != today.iso8601 || user.review_reminder_sent_on == today

      count = Card.joins(:card_progress).where(deck: user.decks)
        .where(card_progresses: { next_review_at: today }).count
      next if count.zero?

      ReviewReminderMailer.with(user: user, count: count).daily.deliver_now
      user.update_columns(review_reminder_sent_on: today)
    end
  end
end
