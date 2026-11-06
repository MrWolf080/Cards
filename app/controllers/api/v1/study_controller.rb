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

        study_session = session_for(deck, :cards, due_cards.any?)
        due_cards = [] if study_session&.finished_at
        render json: session_data(study_session, deck).merge(
          cards: due_cards.map { |card|
            { id: card.id, front: card.front, back: card.back, level: card.card_progress.level }
          }
        )
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

        study_session = session_for(deck, :quiz, due_cards.any?)
        due_cards = [] if study_session&.finished_at

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

        render json: session_data(study_session, deck).merge(
          questions: questions, existing_card_ids: all_cards.map(&:first), available_answers: all_cards.map(&:last).uniq
        )
      end

      # POST /api/v1/decks/:deck_id/study/answer
      def answer
        deck = Current.user.decks.find(params[:deck_id])
        card = deck.cards.find(params[:card_id])
        session = deck.study_sessions.where(user: Current.user).find(params[:session_id])
        rating = params[:rating]

        card.with_lock do
          if session.reload.finished_at || session.session_answers.exists?(card: card) ||
              (card.card_progress.next_review_at && card.card_progress.next_review_at > Date.current)
            return render json: { error: "Карточка уже оценена или сессия завершена. Данные обновлены." }, status: :conflict
          end
          # Ответ и прогресс фиксируются вместе до рассылки события.
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

          progress.save!
        end
        head :ok
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      # POST /api/v1/decks/:deck_id/study/finish
      def finish
        deck = Current.user.decks.find(params[:deck_id])
        session = deck.study_sessions.where(user: Current.user).find(params[:session_id])
        session.update!(finished_at: Time.current) unless session.finished_at
        head :ok
      end
      private

      def session_for(deck, mode, has_cards)
        scope = deck.study_sessions.where(user: Current.user, mode: mode)
        return scope.find(params[:session_id]) if params[:session_id].present?
        return unless has_cards

        scope.find_or_create_by!(finished_at: nil) { |session| session.started_at = Time.current }
      end

      def session_data(session, deck)
        {
          session_id: session&.id, deck_title: deck.title,
          finished: session&.finished_at.present?,
          answered_count: session ? session.session_answers.count : 0,
          correct_count: session ? session.session_answers.where(is_correct: true).count : 0
        }
      end
    end
  end
end
