class CreateSessionAnswers < ActiveRecord::Migration[8.0]
  def change
    create_table :session_answers do |t|
      t.references :study_session, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.integer :rating
      t.boolean :is_correct

      t.timestamps
    end
  end
end
