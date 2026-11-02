require "test_helper"

class SessionAnswerTest < ActiveSupport::TestCase
  setup do
    @deck = create_deck
    @card = create_card(deck: @deck)
    @session = create_study_session(deck: @deck)
  end

  test "belongs to a study session and a card" do
    answer = create_answer(session: @session, card: @card)
    assert_equal @session, answer.study_session
    assert_equal @card, answer.card
  end

  test "invalid without a study session or a card" do
    answer = SessionAnswer.new(is_correct: true)
    assert_not answer.valid?
    assert_includes answer.errors.attribute_names, :study_session
    assert_includes answer.errors.attribute_names, :card
  end

  test "stores is_correct as a boolean" do
    right = create_answer(session: @session, card: @card, is_correct: true)
    wrong = create_answer(session: @session, card: @card, is_correct: false)

    assert_equal true, right.reload.is_correct
    assert_equal false, wrong.reload.is_correct
  end

  test "the same card can be answered in different sessions" do
    other_session = create_study_session(deck: @deck, mode: :quiz)
    create_answer(session: @session, card: @card)
    create_answer(session: other_session, card: @card)

    assert_equal 2, SessionAnswer.where(card: @card).count
  end

  test "session counts correct answers" do
    create_answer(session: @session, card: @card, is_correct: true)
    create_answer(session: @session, card: @card, is_correct: true)
    create_answer(session: @session, card: @card, is_correct: false)

    assert_equal 3, @session.session_answers.count
    assert_equal 2, @session.session_answers.where(is_correct: true).count
  end

  # ВНИМАНИЕ: этот тест выявляет ошибку в текущем коде.
  # Колонка rating — integer, а контроллер передаёт строки 'forgot'/'hard'/'good'/'easy',
  # которые Rails приводит к 0. Тест станет зелёным после добавления в модель:
  #   enum :rating, { forgot: 0, hard: 1, good: 2, easy: 3 }
  test "keeps the rating label" do
    %w[forgot hard good easy].each do |rating|
      answer = create_answer(session: @session, card: @card, rating: rating)
      assert_equal rating, answer.reload.rating, "оценка #{rating} должна сохраняться"
    end
  end
end
