# frozen_string_literal: true

class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.string :external_id, null: false
      t.string :title, null: false
      t.text :instructions
      t.string :image_url
      t.string :source_url

      t.timestamps
    end
    add_index :recipes, :external_id, unique: true
  end
end
