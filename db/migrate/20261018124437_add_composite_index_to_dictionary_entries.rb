class AddCompositeIndexToDictionaryEntries < ActiveRecord::Migration[7.1]
  def change
    # Составной уникальный индекс: слово + перевод + часть речи
    add_index :dictionary_entries,
              [:en, :ru],
              unique: true,
              name: 'index_dictionary_entries_on_en_ru_pos'
  end
end