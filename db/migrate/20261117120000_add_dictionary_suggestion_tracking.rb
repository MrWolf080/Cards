class AddDictionarySuggestionTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :dictionary_entries, :popular, :integer, default: 0, null: false
    add_index :dictionary_entries, [:popular, :rank, :id], order: { popular: :desc }

    create_table :dictionary_views do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :word, null: false
      t.index [:user_id, :word], unique: true
    end
  end
end
