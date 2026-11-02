# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
puts "Очистка старого словаря..."
DictionaryEntry.destroy_all

puts "Запуск импорта словаря..."

# Находим все файлы в папке db/words и загружаем их по очереди
Dir[Rails.root.join("db/words/*.rb")].sort.each do |file|
  puts "Загружаю: #{File.basename(file)}"
  load file
end

puts "Готово! Всего слов в базе: #{DictionaryEntry.count}"