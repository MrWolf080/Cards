class CreateDecks < ActiveRecord::Migration[8.0]
  def change
    create_table :decks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.integer :direction

      t.timestamps
    end
  end
end
