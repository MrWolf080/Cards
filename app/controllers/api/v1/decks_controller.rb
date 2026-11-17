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
            shared: deck.shared,
            copied: deck.copied,
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

      def sharing
        deck = Current.user.decks.find(params[:id])
        shared = params.require(:sharing).fetch(:shared, nil)
        return head :unprocessable_entity unless shared == true || shared == false
        if shared && deck.copied?
          return render json: { error: "Опубликовать можно только оригинальную колоду." }, status: :unprocessable_entity
        end

        deck.update!(shared: shared)
        render json: { shared: deck.shared }
      end

      def popular
        shared = Deck.where(shared: true)
        ranked = if shared.where("copies_count > 0").exists?
          shared.order(copies_count: :desc, id: :asc)
        else
          shared.order(Arel.sql("RANDOM()"))
        end
        decks = ranked.limit(10).includes(:cards).to_a
        copies = Current.user.decks.where(source_deck_id: decks.map(&:id)).pluck(:source_deck_id, :id).to_h
        render json: decks.map { |deck|
          { id: deck.id, title: deck.title, direction: deck.direction,
            total_cards: deck.cards.size, copies_count: deck.copies_count,
            own: deck.user_id == Current.user.id, copy_id: copies[deck.id] }
        }
      end

      def preview
        deck = Deck.where(shared: true).find(params[:id])
        render json: {
          title: deck.title,
          direction: deck.direction,
          cards: deck.cards.order(:id).as_json(only: [:id, :front, :back, :example])
        }
      end

      def copy
        source = Deck.where(shared: true).where.not(user_id: Current.user.id).find(params[:id])
        copied = nil
        created = false
        source.with_lock do
          raise ActiveRecord::RecordNotFound unless source.shared?

          copied = Current.user.decks.find_by(source_deck_id: source.id)
          unless copied
            copied = Current.user.decks.create!(title: source.title, direction: source.direction,
              source_deck_id: source.id, copied: true)
            source.cards.find_each do |original|
              card = copied.cards.create!(original.attributes.slice("front", "back", "example"))
              card.create_card_progress!(level: 0, status: :new_card)
            end
            created = true
          end
        end
        render json: { id: copied.id }, status: created ? :created : :ok
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
