# frozen_string_literal: true

# Normalises a recipe for the detail view, whether it comes from a local
# Recipe record (saved plans, imported catalog) or a raw MealDB meal hash
# (ephemeral plan slots not yet saved).
class RecipePresenter
  Ingredient = Struct.new(:name, :amount, keyword_init: true)

  attr_reader :external_id, :title, :image_url, :instructions, :source_url, :ingredients

  def self.from_record(recipe)
    new(
      external_id: recipe.external_id,
      title: recipe.title,
      image_url: recipe.image_url,
      instructions: recipe.instructions,
      source_url: recipe.source_url,
      ingredients: recipe.recipe_ingredients.map { |ri| Ingredient.new(name: ri.ingredient.name, amount: ri.amount) }
    )
  end

  def self.from_meal(meal)
    new(
      external_id: meal["idMeal"],
      title: meal["strMeal"],
      image_url: meal["strMealThumb"],
      instructions: meal["strInstructions"],
      source_url: meal["strSource"],
      ingredients: extract_ingredients(meal)
    )
  end

  def self.extract_ingredients(meal)
    (1..20).filter_map do |i|
      name = meal["strIngredient#{i}"].to_s.strip
      next if name.empty?

      Ingredient.new(name: name, amount: meal["strMeasure#{i}"].to_s.strip)
    end
  end

  def initialize(external_id:, title:, image_url:, instructions:, source_url:, ingredients:)
    @external_id = external_id
    @title = title
    @image_url = image_url
    @instructions = instructions
    @source_url = source_url
    @ingredients = ingredients
  end
end
