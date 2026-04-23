require "rails_helper"

RSpec.describe Ingredient, type: :model do
  describe "validations" do
    it "is valid with a name" do
      expect(Ingredient.new(name: "Onion")).to be_valid
    end

    it "requires a name" do
      ingredient = Ingredient.new(name: nil)

      expect(ingredient).not_to be_valid
      expect(ingredient.errors[:name]).to include("can't be blank")
    end

    it "requires name to be unique case-insensitively" do
      Ingredient.create!(name: "Onion")
      duplicate = Ingredient.new(name: "ONION")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  describe "name normalization" do
    it "downcases and strips the name before validation" do
      ingredient = Ingredient.create!(name: "  Garlic  ")

      expect(ingredient.name).to eq("garlic")
    end

    it "treats a blank name as invalid rather than raising" do
      ingredient = Ingredient.new(name: nil)

      expect { ingredient.valid? }.not_to raise_error
      expect(ingredient).not_to be_valid
    end
  end

  describe "associations" do
    it "has many recipes through recipe_ingredients" do
      ingredient = Ingredient.create!(name: "Beets")
      recipe = Recipe.create!(external_id: "ext-1", title: "Borscht")
      recipe.recipe_ingredients.create!(ingredient: ingredient, amount: "2 cups")

      expect(ingredient.recipes).to include(recipe)
    end
  end
end
