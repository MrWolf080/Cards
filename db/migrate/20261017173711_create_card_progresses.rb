class CreateCardProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :card_progresses do |t|
      t.references :card, null: false, foreign_key: true
      t.integer :level
      t.date :next_review_at
      t.integer :status

      t.timestamps
    end
  end
end
