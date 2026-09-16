# frozen_string_literal: true

class Recipe < ApplicationRecord
  has_many :recipe_ingredients, dependent: :destroy
  has_many :ingredients, through: :recipe_ingredients

  validates :external_id, :title, presence: true
  validates :external_id, uniqueness: true

  # external_id is the natural identifier shared with MealDB, so URLs key on it
  # (and the same path works for ephemeral, not-yet-saved recipes).
  def to_param
    external_id
  end
end
