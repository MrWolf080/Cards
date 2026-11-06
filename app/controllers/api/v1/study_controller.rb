module Api
  module V1
    class StudyController < ApplicationController
      # GET /api/v1/decks/:deck_id/study
      def index
        deck = Current.user.decks.find(params[:deck_id])

        due_cards = deck.cards.available_today
                        .includes(:card_progress)
                        .order(Arel.sql('card_progresses.next_review_at ASC NULLS LAST, cards.id ASC'))
                        .to_a

        # Повторять нечего: пустую сессию не создаём
        if due_cards.empty?
          return render json: { session_id: nil, deck_title: deck.title, cards: [] }
        end

        study_session = Current.user.study_sessions.find_or_create_by!(
          deck: deck, mode: :cards, finished_at: nil
        ) { |s| s.started_at = Time.current }

        render json: {
          session_id: study_session.id,
          deck_title: deck.title,
          cards: due_cards.map { |card|
            { id: card.id, front: card.front, back: card.back, level: card.card_progress.level }
          }
        }
      end

      # GET /api/v1/decks/:deck_id/quiz
      def quiz
        deck = Current.user.decks.find(params[:deck_id])

        # Варианты ответов берём из всей колоды, поэтому лимит в 4 карточки считаем по ней
        all_cards = deck.cards.pluck(:id, :back)
        if all_cards.size < 4
          return render json: { error: "Для теста нужно минимум 4 карточки в колоде." },
                        status: :unprocessable_entity
        end

        due_cards = deck.cards.available_today
                        .includes(:card_progress)
                        .order(Arel.sql('card_progresses.next_review_at ASC NULLS LAST, cards.id ASC'))
                        .to_a

        if due_cards.empty?
          return render json: { session_id: nil, deck_title: deck.title, questions: [] }
        end

        study_session = Current.user.study_sessions.find_or_create_by!(
          deck: deck, mode: :quiz, finished_at: nil
        ) { |s| s.started_at = Time.current }

        questions = due_cards.map do |card|
          wrong = all_cards.reject { |id, back| id == card.id || back == card.back }
                           .map(&:last).uniq.sample(3)
          {
            card_id: card.id,
            word: card.front,
            correct_answer: card.back,
            options: (wrong + [card.back]).shuffle
          }
        end

        render json: { session_id: study_session.id, deck_title: deck.title, questions: questions }
      end

      # POST /api/v1/decks/:deck_id/study/answer
      def answer
        deck = Current.user.decks.find(params[:deck_id])
        card = deck.cards.find(params[:card_id])
        session = Current.user.study_sessions.find(params[:session_id])
        rating = params[:rating]

        # 👇 Сохраняем ответ в историю
        session.session_answers.create!(
          card: card,
          rating: rating,
          is_correct: rating != 'forgot'
        )

        progress = card.card_progress
        case rating
        when 'forgot'
          progress.level = 0
          progress.next_review_at = Date.current + 1.day
          progress.status = :learning
        when 'hard'
          progress.next_review_at = Date.current + 2.days
          progress.status = :learning if progress.new_card?
        when 'good'
          progress.level = [progress.level + 1, 5].min
          progress.next_review_at = Date.current + 4.days
          progress.status = :learning
        when 'easy'
          progress.level = [progress.level + 2, 5].min
          progress.next_review_at = Date.current + 7.days
          progress.status = :learning
        end

        if progress.level == 5
          progress.status = :learned
          progress.next_review_at = Date.current + 14.days
        end

        if progress.save
          head :ok
        else
          render json: { errors: progress.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/decks/:deck_id/study/finish
      def finish
        session = Current.user.study_sessions.find(params[:session_id])
        session.update!(finished_at: Time.current) # 👇 Фиксируем время окончания
        head :ok
      end
    end
  end
end