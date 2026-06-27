# frozen_string_literal: true

# Plain data object for one day in a plan.
# Lets the view render the same shape whether the slot came from
# the MealDB API (ephemeral plan) or from a local Recipe (saved plan).
class PlanSlotPresenter
  attr_reader :scheduled_for, :title, :image_url, :external_id

  def self.from_meal(date, meal)
    new(
      scheduled_for: date,
      title: meal["strMeal"],
      image_url: meal["strMealThumb"],
      external_id: meal["idMeal"]
    )
  end

  def self.from_recipe(date, recipe)
    new(
      scheduled_for: date,
      title: recipe.title,
      image_url: recipe.image_url,
      external_id: recipe.external_id
    )
  end

  def initialize(scheduled_for:, title:, image_url:, external_id:)
    @scheduled_for = scheduled_for
    @title = title
    @image_url = image_url
    @external_id = external_id
  end
end
