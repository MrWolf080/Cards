require "test_helper"

class DictionaryEntryTest < ActiveSupport::TestCase
  test "saves word, translation and optional fields" do
    entry = create_entry(en: "borrow", ru: "занимать", part_of_speech: "гл.",
                         example_en: "Can I borrow your pen?", example_ru: "Можно взять твою ручку?",
                         rank: 120, source: "test")
    entry.reload

    assert_equal "borrow", entry.en
    assert_equal "занимать", entry.ru
    assert_equal "гл.", entry.part_of_speech
    assert_equal 120, entry.rank
  end

  test "part of speech, examples and source are optional" do
    entry = create_entry(en: "ceiling", ru: "потолок")
    assert_nil entry.part_of_speech
    assert_nil entry.example_en
    assert_nil entry.source
  end

  test "the same word and translation pair cannot be stored twice" do
    create_entry(en: "luggage", ru: "багаж")
    assert_raises(ActiveRecord::RecordNotUnique) do
      create_entry(en: "luggage", ru: "багаж")
    end
  end

  test "one English word may have several translations" do
    create_entry(en: "light", ru: "свет")
    create_entry(en: "light", ru: "лёгкий")
    assert_equal 2, DictionaryEntry.where(en: "light").count
  end

  test "different words may share a translation" do
    create_entry(en: "alter", ru: "изменять")
    create_entry(en: "change", ru: "изменять")
    assert_equal 2, DictionaryEntry.where(ru: "изменять").count
  end

  test "entries can be ordered by rank" do
    create_entry(en: "rare", ru: "редкий", rank: 900)
    create_entry(en: "common", ru: "частый", rank: 10)
    assert_equal %w[common rare], DictionaryEntry.where(en: %w[rare common]).order(:rank).pluck(:en)
  end

  test "is independent from cards: editing an entry does not change a copied card" do
    entry = create_entry(en: "attempt", ru: "попытка")
    card = create_card(front: entry.en, back: entry.ru)

    entry.update!(ru: "проба")
    assert_equal "попытка", card.reload.back
  end
end
