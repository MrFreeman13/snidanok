# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Recipes", type: :request do
  describe "GET /recipes" do
    it "returns http success" do
      get recipes_path
      expect(response).to have_http_status(:ok)
    end

    it "lists recipe titles ordered alphabetically" do
      Recipe.create!(external_id: "2", title: "Pancakes")
      Recipe.create!(external_id: "1", title: "Avocado Toast")

      get recipes_path

      expect(response.body).to include("Avocado Toast", "Pancakes")
      expect(response.body.index("Avocado Toast")).to be < response.body.index("Pancakes")
    end

    it "renders the page even when there are no recipes" do
      get recipes_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("All recipes")
    end

    it "renders an image when image_url is present" do
      Recipe.create!(external_id: "1", title: "Pancakes", image_url: "https://img.test/p.jpg")

      get recipes_path

      expect(response.body).to include('src="https://img.test/p.jpg"')
    end
  end

  describe "GET /recipes/:id" do
    let(:recipe) do
      Recipe.create!(
        external_id: "1",
        title: "Pancakes",
        instructions: "Mix and cook on a hot pan.",
        image_url: "https://img.test/p.jpg"
      )
    end

    it "returns http success" do
      get recipe_path(recipe)
      expect(response).to have_http_status(:ok)
    end

    it "renders the title, instructions, and image" do
      get recipe_path(recipe)

      expect(response.body).to include("Pancakes")
      expect(response.body).to include("Mix and cook on a hot pan.")
      expect(response.body).to include('src="https://img.test/p.jpg"')
    end

    it "renders ingredients with their amounts" do
      flour = Ingredient.create!(name: "Flour")
      eggs = Ingredient.create!(name: "Eggs")
      recipe.recipe_ingredients.create!(ingredient: flour, amount: "2 cups")
      recipe.recipe_ingredients.create!(ingredient: eggs, amount: "3")

      get recipe_path(recipe)

      expect(response.body).to include("flour", "2 cups")
      expect(response.body).to include("eggs", "3")
    end

    it "responds with 404 when the recipe does not exist" do
      get recipe_path(id: 999_999)
      expect(response).to have_http_status(:not_found)
    end
  end
end
