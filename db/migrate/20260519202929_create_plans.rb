# frozen_string_literal: true

class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.date :start_date, null: false
      t.date :end_date, null: false

      t.timestamps
    end
  end
end
