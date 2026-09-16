# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecipePresenter do
  describe ".from_record" do
    it "maps fields and ingredients from a local Recipe" do
      recipe = Recipe.create!(
        external_id: "52772",
        title: "Pancakes",
        instructions: "Mix and cook.",
        image_url: "https://img.test/p.jpg"
      )
      recipe.recipe_ingredients.create!(ingredient: Ingredient.create!(name: "Flour"), amount: "2 cups")
      recipe.recipe_ingredients.create!(ingredient: Ingredient.create!(name: "Eggs"), amount: "3")

      presenter = described_class.from_record(recipe)

      expect(presenter.external_id).to eq("52772")
      expect(presenter.title).to eq("Pancakes")
      expect(presenter.image_url).to eq("https://img.test/p.jpg")
      expect(presenter.instructions).to eq("Mix and cook.")
      expect(presenter.ingredients.map(&:name)).to contain_exactly("flour", "eggs")
      expect(presenter.ingredients.map(&:amount)).to contain_exactly("2 cups", "3")
    end
  end

  describe ".from_meal" do
    let(:meal) do
      {
        "idMeal" => "52772",
        "strMeal" => "Shakshuka",
        "strMealThumb" => "https://img.test/shakshuka.jpg",
        "strInstructions" => "Simmer and poach the eggs.",
        "strSource" => "https://src.test/shakshuka",
        "strIngredient1" => "Eggs",     "strMeasure1" => "3",
        "strIngredient2" => "Tomatoes", "strMeasure2" => "1 can",
        "strIngredient3" => "",         "strMeasure3" => "ignored",
        "strIngredient4" => nil,        "strMeasure4" => nil
      }
    end

    it "maps the scalar fields from the meal hash" do
      presenter = described_class.from_meal(meal)

      expect(presenter.external_id).to eq("52772")
      expect(presenter.title).to eq("Shakshuka")
      expect(presenter.image_url).to eq("https://img.test/shakshuka.jpg")
      expect(presenter.instructions).to eq("Simmer and poach the eggs.")
      expect(presenter.source_url).to eq("https://src.test/shakshuka")
    end

    it "pairs ingredients with measures and skips blank/missing slots" do
      ingredients = described_class.from_meal(meal).ingredients

      expect(ingredients.map(&:name)).to eq([ "Eggs", "Tomatoes" ])
      expect(ingredients.map(&:amount)).to eq([ "3", "1 can" ])
    end
  end
end
