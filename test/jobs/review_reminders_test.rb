require "test_helper"

class ReviewRemindersTest < ActiveJob::TestCase
  test "sends only for the local date and does not send twice" do
    user = users(:one)
    user.update!(time_zone: "Tokyo")
    other = users(:two)
    today = Date.new(2026, 11, 15)
    deck = create_deck(user: user)
    create_card(deck: deck, next_review_at: today)
    create_card(deck: deck, next_review_at: today - 1)
    create_card(deck: deck)
    create_card(deck: create_deck(user: other), next_review_at: today - 2)

    travel_to Time.utc(2026, 11, 14, 23) do
      assert_no_enqueued_jobs(only: ReviewReminderJob) { ReviewRemindersJob.perform_now }
    end

    travel_to Time.utc(2026, 11, 15, 0) do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
        perform_enqueued_jobs(only: ReviewReminderJob) { ReviewRemindersJob.perform_now }
        ReviewReminderJob.perform_now(user.id, today.iso8601)
      end
      email = ActionMailer::Base.deliveries.last
      assert_equal [user.email_address], email.to
      assert_includes email.body.decoded, "Карточек к повторению на сегодня: 1"
      assert_equal today, user.reload.review_reminder_sent_on
    end
  end
end
