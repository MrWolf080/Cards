module Api
  module V1
    class StatsController < ApplicationController
      def index
        # 1. Точность за неделю
        answers_week = SessionAnswer.joins(study_session: :user)
                                    .where(users: { id: Current.user.id })
                                    .where('session_answers.created_at >= ?', 7.days.ago)
        total_week = answers_week.count
        correct_week = answers_week.where(is_correct: true).count
        accuracy = total_week > 0 ? (correct_week.to_f / total_week * 100).round : 0

        # 2. Текущая серия дней (подряд)
        dates = Current.user.study_sessions.where.not(finished_at: nil)
                       .order(finished_at: :desc)
                       .pluck(:finished_at).map { |time| time.in_time_zone.to_date }.uniq
        streak = 0
        expected_date = Date.current

        # Если сегодня еще не занимались, проверяем со вчерашнего дня
        if dates.first != Date.current && dates.first == Date.current - 1.day
          expected_date = Date.current - 1.day
        end

        dates.each do |date|
          if date == expected_date
            streak += 1
            expected_date -= 1.day
          elsif date < expected_date
            break # Серия прервалась
          end
        end

        # 3. Дневная цель
        new_cards_today = Current.user.new_cards_studied_today
        daily_goal = Current.user.daily_goal || 20

        # 4. История сессий
        history = Current.user.study_sessions.where.not(finished_at: nil)
                         .includes(:deck, :session_answers)
                         .order(finished_at: :desc).limit(15)
                         .map do |session|
          total = session.session_answers.count
          correct = session.session_answers.where(is_correct: true).count
          {
            id: session.id,
            date: session.finished_at.in_time_zone.strftime("%d.%m.%Y"),
            deck_title: session.deck.title,
            mode: session.mode == 'cards' ? 'Карточки' : 'Тест',
            correct: correct,
            total: total,
            percent: total > 0 ? (correct.to_f / total * 100).round : 0
          }
        end

        render json: {
          accuracy: accuracy,
          streak: streak,
          daily_goal: daily_goal,
          new_cards_today: new_cards_today,
          history: history
        }
      end
    end
  end
end