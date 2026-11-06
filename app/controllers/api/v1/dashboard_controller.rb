module Api
  module V1
    class DashboardController < ApplicationController
      def show
        # 1. К повторению сегодня (карточки, у которых next_review_at <= сегодня)
        cards_to_review = Current.user.decks.joins(cards: :card_progress)
                                 .where(card_progresses: { next_review_at: ..Date.current }).count

        # 2. Выучено слов (status: learned)
        learned_words = Current.user.decks.joins(cards: :card_progress)
                               .where(card_progresses: { status: :learned }).count

        # 👇 2.1. Сколько слов получили статус "выучено" за последние 7 дней
        learned_last_week = Current.user.decks.joins(cards: :card_progress)
                                   .where(card_progresses: { status: :learned })
                                   .where('card_progresses.updated_at >= ?', 7.days.ago).count

        # Прирост (если за неделю ничего не выучили, будет 0)
        learned_delta = learned_last_week

        # 3. Точность за 7 дней
        recent_answers = SessionAnswer.joins(study_session: :user)
                                      .where(users: { id: Current.user.id })
                                      .where('study_sessions.created_at >= ?', 7.days.ago)
        total_answers = recent_answers.count
        correct_answers = recent_answers.where(is_correct: true).count
        accuracy = total_answers > 0 ? (correct_answers.to_f / total_answers * 100).round : 0

        # 4. Серия дней (упрощенный расчет: считаем уникальные дни, когда были сессии)
        # В идеале тут нужна сложная логика, считающая именно ПОДРЯД идущие дни
        streak = Current.user.study_sessions.where.not(finished_at: nil)
                        .select('DATE(finished_at)').distinct.count

        # 5. График активности за 7 дней (количество карточек, пройденных в каждый день)
        chart_data = (0..6).map do |days_ago|
          date = Date.current - days_ago.days
          count = SessionAnswer.joins(study_session: :user)
                               .where(users: { id: Current.user.id })
                               .where(study_sessions: { finished_at: date.in_time_zone.all_day }).count
          { day: date.strftime("%a"), count: count }
        end

        # 6. Последние сессии
        recent_sessions = Current.user.study_sessions.where.not(finished_at: nil)
                                 .includes(:deck, :session_answers)
                                 .order(finished_at: :desc).limit(5)
                                 .map do |session|
          {
            date: session.finished_at.in_time_zone.strftime("%d.%m"),
            deck_title: session.deck.title,
            total: session.session_answers.count,
            correct: session.session_answers.where(is_correct: true).count
          }
        end

        render json: {
          cards_to_review: cards_to_review,
          daily_goal: Current.user.daily_goal,
          new_cards_today: Current.user.new_cards_studied_today,
          learned_words: learned_words,
          learned_delta: learned_delta,
          streak: streak,
          accuracy: accuracy,
          chart_data: chart_data,
          recent_sessions: recent_sessions
        }
      end
    end
  end
end