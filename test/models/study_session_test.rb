require "test_helper"

class StudySessionTest < ActiveSupport::TestCase
  test "belongs to a user and a deck" do
    deck = create_deck
    session = create_study_session(deck: deck)
    assert_equal deck, session.deck
    assert_equal deck.user, session.user
  end

  test "invalid without a user or a deck" do
    session = StudySession.new(mode: :cards)
    assert_not session.valid?
    assert_includes session.errors.attribute_names, :user
    assert_includes session.errors.attribute_names, :deck
  end

  test "mode enum values" do
    assert_equal({ "cards" => 0, "quiz" => 1 }, StudySession.modes)
  end

  test "mode predicates and scopes" do
    deck = create_deck
    cards_session = create_study_session(deck: deck, mode: :cards)
    quiz_session  = create_study_session(deck: deck, mode: :quiz)

    assert cards_session.cards?
    assert quiz_session.quiz?
    assert_equal [quiz_session], deck.study_sessions.quiz.to_a
  end

  test "rejects an unknown mode" do
    assert_raises(ArgumentError) { StudySession.new(mode: :flash) }
  end

  test "is unfinished until finished_at is set" do
    session = create_study_session
    assert_nil session.finished_at

    session.update!(finished_at: Time.current)
    assert_not_nil session.reload.finished_at
  end

  test "destroying a session removes its answers but not the cards" do
    deck = create_deck
    card = create_card(deck: deck)
    session = create_study_session(deck: deck)
    create_answer(session: session, card: card)

    assert_difference "SessionAnswer.count", -1 do
      session.destroy
    end
    assert Card.exists?(card.id)
  end

  # StudyController#index / #quiz опираются на это поведение
  test "an unfinished session of the same user, deck and mode is reused" do
    deck = create_deck
    find = lambda do
      deck.user.study_sessions.find_or_create_by!(deck: deck, mode: :cards, finished_at: nil) do |s|
        s.started_at = Time.current
      end
    end

    first = find.call
    assert_equal first.id, find.call.id

    first.update!(finished_at: Time.current)
    assert_not_equal first.id, find.call.id
  end

  test "a quiz session is separate from a cards session" do
    deck = create_deck
    cards_session = create_study_session(deck: deck, mode: :cards)
    quiz_session  = create_study_session(deck: deck, mode: :quiz)
    assert_not_equal cards_session.id, quiz_session.id
  end
end
