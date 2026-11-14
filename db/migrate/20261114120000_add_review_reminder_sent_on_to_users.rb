class AddReviewReminderSentOnToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :review_reminder_sent_on, :date
  end
end
