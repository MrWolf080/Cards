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

        render_suggestions(deck)
      end

      def skip_suggestions
        deck = Current.user.decks.find(params[:deck_id])
        entries = DictionaryEntry.where(id: Array(params[:ids]).first(5)).distinct.pluck(:en)
        if entries.any?
          DictionaryView.insert_all(entries.map { |word| { user_id: Current.user.id, word: word } },
            unique_by: [:user_id, :word])
        end
        render_suggestions(deck)
      end

      def reset_dictionary_views
        Current.user.dictionary_views.delete_all
        head :no_content
      end

      # POST /api/v1/decks/:deck_id/cards
      def create
        deck = Current.user.decks.find(params[:deck_id])
        entry = DictionaryEntry.find(params[:dictionary_entry_id]) if params.key?(:dictionary_entry_id)
        card = deck.cards.build(entry ? dictionary_attributes(deck, entry) : card_params)

        Card.transaction do
          card.save!
          card.create_card_progress!(level: 0, status: :new_card, next_review_at: nil)
          DictionaryEntry.increment_counter(:popular, entry.id) if entry
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

      def render_suggestions(deck)
        english_side = deck.ru_en? ? :back : :front
        existing_words = deck.cards.where.not(english_side => nil).select(Arel.sql("LOWER(#{english_side})"))
        excluded_words = DictionaryEntry.where(id: Array(params[:exclude]).first(5)).select(:en)
        candidates = DictionaryEntry.where.not(en: existing_words)
          .where.not(en: Current.user.dictionary_views.select(:word))
          .where.not(en: excluded_words)
          .order(popular: :desc, rank: :asc, id: :asc)
        count = (params[:count] || 5).to_i.clamp(1, 5)
        # Pick the best-ranked meaning of each English word.
        best = DictionaryEntry.from(candidates.reorder(:en, popular: :desc, rank: :asc, id: :asc)
          .select("DISTINCT ON (en) dictionary_entries.*"), :dictionary_entries)
          .order(popular: :desc, rank: :asc, id: :asc).limit(count)
        render json: best.map { |entry|
          { id: entry.id, en: entry.en, ru: entry.ru, part_of_speech: entry.part_of_speech,
            example: dictionary_example(entry, deck) }
        }
      end

      def card_params
        params.require(:card).permit(:front, :back, :example)
      end

      def dictionary_attributes(deck, entry)
        {
          front: deck.ru_en? ? entry.ru : entry.en,
          back: deck.ru_en? ? entry.en : entry.ru,
          example: dictionary_example(entry, deck)
        }
      end

      def dictionary_example(entry, deck)
        deck.ru_en? ? entry.example_ru.presence || entry.example_en : entry.example_en
      end
    end
  end
end
