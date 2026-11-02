require "test_helper"

class DeckTest < ActiveSupport::TestCase
  test "belongs to a user" do
    deck = create_deck(user: users(:two))
    assert_equal users(:two), deck.user
  end

  test "invalid without a user" do
    deck = Deck.new(title: "No owner", direction: :en_ru)
    assert_not deck.valid?
    assert_includes deck.errors.attribute_names, :user
  end

  test "direction enum has en_ru and ru_en" do
    assert_equal({ "en_ru" => 0, "ru_en" => 1 }, Deck.directions)
  end

  test "direction predicates" do
    deck = create_deck(direction: :ru_en)
    assert deck.ru_en?
    assert_not deck.en_ru?
  end

  test "rejects an unknown direction" do
    assert_raises(ArgumentError) { Deck.new(direction: :de_ru) }
  end

  test "destroying a deck removes its cards and their progress" do
    deck = create_deck
    create_card(deck: deck, front: "luggage", back: "багаж")
    create_card(deck: deck, front: "attempt", back: "попытка")

    assert_difference ["Card.count", "CardProgress.count"], -2 do
      deck.destroy
    end
  end

  test "destroying a deck removes its study sessions" do
    deck = create_deck
    create_study_session(deck: deck)

    assert_difference "StudySession.count", -1 do
      deck.destroy
    end
  end

  test "destroying a deck with answers does not violate foreign keys" do
    deck = create_deck
    card = create_card(deck: deck)
    session = create_study_session(deck: deck)
    create_answer(session: session, card: card)

    assert_nothing_raised { deck.destroy! }
    assert_equal 0, SessionAnswer.where(card_id: card.id).count
  end

  test "other decks are not affected when a deck is destroyed" do
    keep = create_deck(title: "Keep")
    create_card(deck: keep)
    create_deck(title: "Remove").destroy

    assert_equal 1, keep.cards.count
  end
end
