class RecipesController < ApplicationController
  def index
    @recipes = Recipe.order(:title)
  end

  def show
    @recipe = Recipe.includes(recipe_ingredients: :ingredient).find(params[:id])
  end
end
