class PreventCopiedDeckPublication < ActiveRecord::Migration[8.1]
  def up
    add_column :decks, :copied, :boolean, default: false, null: false
    execute "UPDATE decks SET copied = TRUE, shared = FALSE WHERE source_deck_id IS NOT NULL"
    add_check_constraint :decks, "NOT shared OR (NOT copied AND source_deck_id IS NULL)",
      name: "shared_decks_must_be_originals"
  end

  def down
    remove_check_constraint :decks, name: "shared_decks_must_be_originals"
    remove_column :decks, :copied
  end
end
