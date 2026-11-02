class CreateStudySessions < ActiveRecord::Migration[8.0]
  def change
    create_table :study_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :deck, null: false, foreign_key: true
      t.integer :mode
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end
