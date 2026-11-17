class AddDeckSharing < ActiveRecord::Migration[8.1]
  def change
    add_column :decks, :shared, :boolean, default: false, null: false
    add_column :decks, :copies_count, :integer, default: 0, null: false
    add_reference :decks, :source_deck, foreign_key: { to_table: :decks, on_delete: :nullify }
    add_index :decks, [:user_id, :source_deck_id], unique: true
  end
end
