require "rails_helper"

RSpec.describe Recipe, type: :model do
  let(:valid_attributes) { { external_id: "ext-1", title: "Borscht" } }

  describe "validations" do
    it "is valid with external_id and title" do
      expect(Recipe.new(valid_attributes)).to be_valid
    end

    it "requires external_id" do
      recipe = Recipe.new(valid_attributes.merge(external_id: nil))

      expect(recipe).not_to be_valid
      expect(recipe.errors[:external_id]).to include("can't be blank")
    end

    it "requires title" do
      recipe = Recipe.new(valid_attributes.merge(title: nil))

      expect(recipe).not_to be_valid
      expect(recipe.errors[:title]).to include("can't be blank")
    end

    it "requires external_id to be unique" do
      Recipe.create!(valid_attributes)
      duplicate = Recipe.new(valid_attributes.merge(title: "Other"))

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:external_id]).to include("has already been taken")
    end
  end

  describe "associations" do
    let(:recipe) { Recipe.create!(valid_attributes) }
    let(:ingredient) { Ingredient.create!(name: "Beets") }

    it "has many ingredients through recipe_ingredients" do
      recipe.recipe_ingredients.create!(ingredient: ingredient, amount: "2 cups")

      expect(recipe.ingredients).to include(ingredient)
    end

    it "destroys recipe_ingredients when destroyed" do
      recipe.recipe_ingredients.create!(ingredient: ingredient, amount: "2 cups")

      expect { recipe.destroy }.to change(RecipeIngredient, :count).by(-1)
    end
  end
end
