class RecountDeckCopies < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE decks AS original
      SET copies_count = counts.total
      FROM (
        SELECT source.id, COUNT(copy.id) AS total
        FROM decks AS source
        LEFT JOIN decks AS copy ON copy.source_deck_id = source.id
        GROUP BY source.id
      ) AS counts
      WHERE original.id = counts.id AND original.copies_count <> counts.total
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
