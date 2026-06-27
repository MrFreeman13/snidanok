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

  describe "GET /recipes/:external_id" do
    context "when the recipe is saved locally" do
      let(:recipe) do
        Recipe.create!(
          external_id: "52772",
          title: "Pancakes",
          instructions: "Mix and cook on a hot pan.",
          image_url: "https://img.test/p.jpg"
        )
      end

      it "renders the title, instructions, image and ingredients from the record" do
        flour = Ingredient.create!(name: "Flour")
        eggs = Ingredient.create!(name: "Eggs")
        recipe.recipe_ingredients.create!(ingredient: flour, amount: "2 cups")
        recipe.recipe_ingredients.create!(ingredient: eggs, amount: "3")

        get recipe_path(recipe)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Pancakes", "Mix and cook on a hot pan.")
        expect(response.body).to include('src="https://img.test/p.jpg"')
        expect(response.body).to include("flour", "2 cups", "eggs", "3")
      end

      it "does not hit the API for a locally saved recipe" do
        client = instance_double(MealDbClient)
        allow(MealDbClient).to receive(:new).and_return(client)
        allow(client).to receive(:lookup)

        get recipe_path(recipe)

        expect(client).not_to have_received(:lookup)
      end
    end

    context "when the recipe is not saved (ephemeral plan slot)" do
      let(:client) { instance_double(MealDbClient) }

      before { allow(MealDbClient).to receive(:new).and_return(client) }

      it "fetches it from MealDB by external_id and renders it" do
        allow(client).to receive(:lookup).with("99001").and_return(
          {
            "idMeal" => "99001", "strMeal" => "Shakshuka",
            "strInstructions" => "Simmer the eggs.", "strMealThumb" => "https://img.test/s.jpg",
            "strIngredient1" => "Eggs", "strMeasure1" => "3"
          }
        )

        get recipe_path("99001")

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Shakshuka", "Simmer the eggs.", "Eggs", "3")
      end

      it "responds with 404 when MealDB has no such recipe" do
        allow(client).to receive(:lookup).with("nope").and_return(nil)

        get recipe_path("nope")

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
