module Api
  module V1
    class CardsController < ApplicationController
      # GET /api/v1/decks/:deck_id/cards
      def index
        deck = Current.user.decks.find(params[:deck_id])
        cards = deck.cards.includes(:card_progress)

        render json: cards.map { |card|
          {
            id: card.id,
            front: card.front,
            back: card.back,
            example: card.example,
            status: card.card_progress.status,
            next_review: card.card_progress.next_review_at
          }
        }
      end

      # GET /api/v1/decks/:deck_id/suggestions
      def suggestions
        deck = Current.user.decks.find(params[:deck_id])

        # Слова, которые уже есть в колоде
        existing_words = deck.cards.pluck(:front)

        # 👇 Получаем параметры от фронтенда
        count = params[:count] ? params[:count].to_i : 5
        exclude_ids = params[:exclude] || []

        # Ищем случайные слова, исключая те, что в колоде, и те, что уже на экране
        suggestions = DictionaryEntry.where.not(en: existing_words)
                                     .where.not(id: exclude_ids)
                                     .order("RANDOM()")
                                     .limit(count)

        render json: suggestions.map { |entry|
          { id: entry.id, en: entry.en, ru: entry.ru, part_of_speech: entry.part_of_speech }
        }
      end

      # POST /api/v1/decks/:deck_id/cards
      def create
        deck = Current.user.decks.find(params[:deck_id])
        card = deck.cards.build(params.key?(:dictionary_entry_id) ? dictionary_attributes(deck) : card_params)

        Card.transaction do
          card.save!
          card.create_card_progress!(level: 0, status: :new_card, next_review_at: nil)
        end
        head :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        deck = Current.user.decks.find(params[:deck_id])
        deck.cards.find(params[:id]).update!(card_params)
        head :no_content
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      # DELETE /api/v1/decks/:deck_id/cards/:id
      def destroy
        deck = Current.user.decks.find(params[:deck_id])
        card = deck.cards.find(params[:id])
        card.destroy
        head :no_content
      end

      private

      def card_params
        params.require(:card).permit(:front, :back, :example)
      end

      def dictionary_attributes(deck)
        entry = DictionaryEntry.find(params[:dictionary_entry_id])
        {
          front: deck.ru_en? ? entry.ru : entry.en,
          back: deck.ru_en? ? entry.en : entry.ru,
          example: entry.example_en
        }
      end
    end
  end
end
