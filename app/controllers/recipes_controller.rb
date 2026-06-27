# frozen_string_literal: true

class RecipesController < ApplicationController
  def index
    @recipes = Recipe.order(:title)
  end

  def show
    @recipe = find_recipe
    head :not_found unless @recipe
  end

  private

  # A recipe is shown by external_id. If it's saved locally we present the
  # record; otherwise it's an ephemeral plan slot, so we fetch it from MealDB.
  def find_recipe
    record = Recipe.includes(recipe_ingredients: :ingredient).find_by(external_id: params[:external_id])
    return RecipePresenter.from_record(record) if record

    meal = MealDbClient.new.lookup(params[:external_id])
    RecipePresenter.from_meal(meal) if meal
  end
end
