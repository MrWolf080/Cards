class MakeNewCardsUndated < ActiveRecord::Migration[8.1]
  def up
    change_column_default :card_progresses, :level, from: nil, to: 0
    change_column_default :card_progresses, :status, from: nil, to: 0

    # Карточки, которые ни разу не оценивали, считаются новыми и остаются без даты
    execute <<~SQL
      UPDATE card_progresses SET next_review_at = NULL
      WHERE status = 0
        AND NOT EXISTS (SELECT 1 FROM session_answers sa WHERE sa.card_id = card_progresses.card_id)
    SQL

    # Карточки, оценённые как «Трудно», застряли в статусе «Новое»: делаем их «Изучается»
    execute <<~SQL
      UPDATE card_progresses SET status = 1
      WHERE status = 0
        AND EXISTS (SELECT 1 FROM session_answers sa WHERE sa.card_id = card_progresses.card_id)
    SQL
  end

  def down
    execute "UPDATE card_progresses SET next_review_at = CURRENT_DATE WHERE next_review_at IS NULL"
  end
end
