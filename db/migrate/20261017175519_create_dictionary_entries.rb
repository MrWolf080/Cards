class CreateDictionaryEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :dictionary_entries do |t|
      t.string :en
      t.string :ru
      t.string :part_of_speech
      t.text :example_en
      t.text :example_ru
      t.integer :rank
      t.string :source

      t.timestamps
    end
  end
end
