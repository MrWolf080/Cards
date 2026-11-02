require "test_helper"

class CardProgressTest < ActiveSupport::TestCase
  test "belongs to a card" do
    card = create_card
    assert_equal card, card.card_progress.card
  end

  test "invalid without a card" do
    progress = CardProgress.new
    assert_not progress.valid?
    assert_includes progress.errors.attribute_names, :card
  end

  test "new record defaults: level 0, status new_card, no review date" do
    progress = CardProgress.new
    assert_equal 0, progress.level
    assert_equal "new_card", progress.status
    assert_nil progress.next_review_at
  end

  test "status enum values" do
    assert_equal({ "new_card" => 0, "learning" => 1, "learned" => 2 }, CardProgress.statuses)
  end

  test "status predicates" do
    progress = create_card(status: :learning).card_progress
    assert progress.learning?
    assert_not progress.new_card?
    assert_not progress.learned?
  end

  test "status scopes" do
    deck = create_deck
    create_card(deck: deck, front: "a", back: "а", status: :new_card)
    create_card(deck: deck, front: "b", back: "б", status: :learning)
    create_card(deck: deck, front: "c", back: "в", status: :learned)

    assert_equal 1, CardProgress.where(card: deck.cards).new_card.count
    assert_equal 1, CardProgress.where(card: deck.cards).learning.count
    assert_equal 1, CardProgress.where(card: deck.cards).learned.count
  end

  test "rejects an unknown status" do
    assert_raises(ArgumentError) { CardProgress.new(status: :mastered) }
  end

  test "next_review_at is a date and may be empty" do
    card = create_card(next_review_at: Date.new(2026, 11, 3))
    assert_equal Date.new(2026, 11, 3), card.card_progress.reload.next_review_at

    card.card_progress.update!(next_review_at: nil)
    assert_nil card.card_progress.reload.next_review_at
  end

  test "level and status can be updated" do
    progress = create_card.card_progress
    progress.update!(level: 5, status: :learned)
    assert_equal 5, progress.reload.level
    assert progress.learned?
  end
end
