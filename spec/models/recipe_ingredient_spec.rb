require "rails_helper"

RSpec.describe RecipeIngredient, type: :model do
  let(:recipe) { Recipe.create!(external_id: "ext-1", title: "Borscht") }
  let(:ingredient) { Ingredient.create!(name: "Beets") }

  describe "associations" do
    it "belongs to a recipe" do
      ri = RecipeIngredient.new(ingredient: ingredient)

      expect(ri).not_to be_valid
      expect(ri.errors[:recipe]).to include("must exist")
    end

    it "belongs to an ingredient" do
      ri = RecipeIngredient.new(recipe: recipe)

      expect(ri).not_to be_valid
      expect(ri.errors[:ingredient]).to include("must exist")
    end
  end

  describe "validations" do
    it "is valid with recipe and ingredient" do
      expect(RecipeIngredient.new(recipe: recipe, ingredient: ingredient)).to be_valid
    end

    it "prevents the same ingredient from being added twice to a recipe" do
      RecipeIngredient.create!(recipe: recipe, ingredient: ingredient, amount: "1 cup")
      duplicate = RecipeIngredient.new(recipe: recipe, ingredient: ingredient, amount: "2 cups")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:ingredient_id]).to include("has already been taken")
    end

    it "allows the same ingredient across different recipes" do
      other_recipe = Recipe.create!(external_id: "ext-2", title: "Salad")
      RecipeIngredient.create!(recipe: recipe, ingredient: ingredient, amount: "1 cup")

      expect(RecipeIngredient.new(recipe: other_recipe, ingredient: ingredient)).to be_valid
    end
  end
end
