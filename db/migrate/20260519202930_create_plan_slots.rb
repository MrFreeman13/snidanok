# frozen_string_literal: true

class CreatePlanSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :plan_slots do |t|
      t.references :plan, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true
      t.date :scheduled_for, null: false

      t.timestamps
    end

    add_index :plan_slots, [ :plan_id, :scheduled_for ], unique: true
  end
end
