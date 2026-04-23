# frozen_string_literal: true

class MealDbImporter
  DEFAULT_CATEGORY = "Breakfast"
  DEFAULT_LIMIT = 10

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(category: DEFAULT_CATEGORY, limit: DEFAULT_LIMIT, client: MealDbClient.new)
    @category = category
    @limit = limit
    @client = client
  end

  def call
    external_ids.each { |id| import_recipe(id) }
  end

  private

  attr_reader :category, :limit, :client

  def external_ids
    client.list_by_category(category).first(limit)
  end

  def import_recipe(external_id)
    return if Recipe.exists?(external_id: external_id)

    data = client.lookup(external_id)
    return unless data

    Recipe.transaction do
      recipe = create_recipe(data)
      attach_ingredients(recipe, data)
    end
  rescue => e
    Rails.logger.error "[MealDbImporter] #{external_id}: #{e.message}"
  end

  def create_recipe(data)
    Recipe.create!(
      external_id: data["idMeal"],
      title: data["strMeal"],
      instructions: data["strInstructions"],
      image_url: data["strMealThumb"],
      source_url: data["strSource"]
    )
  end

  def attach_ingredients(recipe, data)
    extract_ingredients(data).each do |name, amount|
      ingredient = Ingredient.find_or_create_by!(name: name)
      recipe.recipe_ingredients.create!(ingredient: ingredient, amount: amount)
    end
  end

  def extract_ingredients(data)
    (1..20).filter_map do |i|
      name = data["strIngredient#{i}"].to_s.strip
      amount = data["strMeasure#{i}"].to_s.strip
      next if name.empty?

      [name.downcase, amount]
    end
  end
end
