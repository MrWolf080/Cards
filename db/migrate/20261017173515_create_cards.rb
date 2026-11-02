class CreateCards < ActiveRecord::Migration[8.0]
  def change
    create_table :cards do |t|
      t.references :deck, null: false, foreign_key: true
      t.string :front
      t.string :back
      t.string :example

      t.timestamps
    end
  end
end
