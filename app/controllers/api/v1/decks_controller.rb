module Api
  module V1
    class DecksController < ApplicationController
      def index
        decks = Current.user.decks.includes(:cards)

        render json: decks.map { |deck|
          total_cards = deck.cards.count
          # Считаем выученные (статус learned)
          learned = deck.cards.joins(:card_progress).where(card_progresses: { status: :learned }).count
          # Считаем те, что нужно повторить сегодня
          to_review = deck.cards.due_today.count

          {
            id: deck.id,
            title: deck.title,
            direction: deck.direction == 'en_ru' ? 'EN → RU' : 'RU → EN',
            total_cards: total_cards,
            learned_cards: learned,
            to_review: to_review
          }
        }
      end

      def create
        deck = Current.user.decks.build(deck_params)
        if deck.save
          render json: { id: deck.id, title: deck.title, direction: deck.direction }, status: :created
        else
          render json: { errors: deck.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        # Ищем колоду только среди колод текущего пользователя (для безопасности)
        deck = Current.user.decks.find(params[:id])
        deck.destroy
        head :no_content # Возвращаем пустой успешный ответ (204)
      end

      def show
        deck = Current.user.decks.find(params[:id])

        # 👇 Считаем карточки к повторению для ЭТОЙ колоды
        to_review = deck.cards.due_today.count

        render json: {
          id: deck.id,
          title: deck.title,
          direction: deck.direction == 'en_ru' ? 'EN → RU' : 'RU → EN',
          to_review: to_review # 👈 Передаем на фронтенд
        }
      end

      private

      def deck_params
        params.require(:deck).permit(:title, :direction)
      end
    end
  end
end