require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    @deck = create_deck
  end

  # Фиксируем «сегодня», чтобы тесты не зависели от реальной даты
  def at_today(date = Date.new(2026, 10, 30), &block)
    travel_to(Time.zone.local(date.year, date.month, date.day, 12), &block)
  end

  test "belongs to a deck" do
    card = create_card(deck: @deck)
    assert_equal @deck, card.deck
  end

  test "invalid without a deck" do
    card = Card.new(front: "luggage", back: "багаж")
    assert_not card.valid?
    assert_includes card.errors.attribute_names, :deck
  end

  test "has one card progress" do
    card = create_card(deck: @deck, status: :learning, level: 2)
    assert_equal "learning", card.card_progress.status
    assert_equal 2, card.card_progress.level
  end

  test "destroying a card removes its progress and answers" do
    card = create_card(deck: @deck)
    session = create_study_session(deck: @deck)
    create_answer(session: session, card: card)

    assert_difference ["Card.count", "CardProgress.count", "SessionAnswer.count"], -1 do
      card.destroy
    end
  end

  test "example is optional" do
    assert create_card(deck: @deck, example: nil).persisted?
    card = create_card(deck: @deck, front: "bag", back: "сумка", example: "Where is my bag?")
    assert_equal "Where is my bag?", card.example
  end

  # --- due_today: срок наступил, новые карточки (NULL) не входят ---

  test "due_today includes cards due today or overdue" do
    at_today do
      overdue = create_card(deck: @deck, front: "a", back: "а", status: :learning, next_review_at: Date.new(2026, 10, 28))
      today   = create_card(deck: @deck, front: "b", back: "б", status: :learning, next_review_at: Date.new(2026, 10, 30))

      assert_equal [overdue.id, today.id].sort, @deck.cards.due_today.pluck(:id).sort
    end
  end

  test "due_today excludes future cards and new cards without a date" do
    at_today do
      create_card(deck: @deck, front: "future", back: "будущее", status: :learning, next_review_at: Date.new(2026, 11, 1))
      create_card(deck: @deck, front: "fresh", back: "новое", next_review_at: nil)

      assert_empty @deck.cards.due_today
    end
  end

  test "a card becomes due on its next_review_at day" do
    card = create_card(deck: @deck, status: :learning, next_review_at: Date.new(2026, 11, 1))

    at_today(Date.new(2026, 10, 31)) { assert_not_includes @deck.cards.due_today, card }
    at_today(Date.new(2026, 11, 1))  { assert_includes @deck.cards.due_today, card }
    at_today(Date.new(2026, 11, 5))  { assert_includes @deck.cards.due_today, card }
  end

  test "due_today ignores cards of other decks when scoped to a deck" do
    at_today do
      other = create_deck(title: "Other")
      create_card(deck: other, status: :learning, next_review_at: Date.new(2026, 10, 29))

      assert_empty @deck.cards.due_today
    end
  end

  test "cards without a progress record are not due" do
    at_today do
      Card.create!(deck: @deck, front: "orphan", back: "сирота")
      assert_empty @deck.cards.due_today
    end
  end

  # --- available_today: просроченные и новые ---

  test "available_today includes new, due today and overdue cards" do
    at_today do
      fresh   = create_card(deck: @deck, front: "fresh", back: "новое", next_review_at: nil)
      today   = create_card(deck: @deck, front: "today", back: "сегодня", status: :learning, next_review_at: Date.new(2026, 10, 30))
      overdue = create_card(deck: @deck, front: "late", back: "поздно", status: :learning, next_review_at: Date.new(2026, 10, 1))

      assert_equal [fresh.id, today.id, overdue.id].sort, @deck.cards.available_today.pluck(:id).sort
    end
  end

  test "available_today excludes future cards" do
    at_today do
      create_card(deck: @deck, front: "future", back: "будущее", status: :learning, next_review_at: Date.new(2026, 10, 31))
      assert_empty @deck.cards.available_today
    end
  end

  test "available_today is a superset of due_today" do
    at_today do
      create_card(deck: @deck, front: "fresh", back: "новое")
      create_card(deck: @deck, front: "late", back: "поздно", status: :learning, next_review_at: Date.new(2026, 10, 20))

      assert_equal 1, @deck.cards.due_today.count
      assert_equal 2, @deck.cards.available_today.count
    end
  end
end
