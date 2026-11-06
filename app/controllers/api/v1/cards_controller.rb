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
        entry = DictionaryEntry.find(params[:dictionary_entry_id])

        # 👇 Проверяем направление колоды. Если ru_en — меняем слова местами
        front_word = deck.ru_en? ? entry.ru : entry.en
        back_word  = deck.ru_en? ? entry.en : entry.ru

        card = deck.cards.build(
          front: front_word,
          back: back_word,
          example: entry.example_en
        )

        Card.transaction do
          card.save!
          card.create_card_progress!(level: 0, status: :new_card, next_review_at: nil)
        end
        head :created
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
    end
  end
end
