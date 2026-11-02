class AddDailyGoalToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :daily_goal, :integer, default: 20
  end
end
