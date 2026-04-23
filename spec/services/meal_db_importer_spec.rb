# frozen_string_literal: true

require "rails_helper"

RSpec.describe MealDbImporter do
  let(:client) { instance_double(MealDbClient) }

  def meal_data(id:, title: "Pancakes", ingredients: [["flour", "1 cup"], ["milk", "1 cup"]])
    data = {
      "idMeal" => id,
      "strMeal" => title,
      "strInstructions" => "Mix and cook.",
      "strMealThumb" => "https://img.test/#{id}.jpg",
      "strSource" => "https://src.test/#{id}"
    }
    ingredients.each_with_index do |(name, amount), idx|
      data["strIngredient#{idx + 1}"] = name
      data["strMeasure#{idx + 1}"] = amount
    end
    data
  end

  describe "#call" do
    it "defaults to Breakfast and a limit of 10" do
      allow(client).to receive(:list_by_category).with("Breakfast").and_return([])

      described_class.new(client: client).call

      expect(client).to have_received(:list_by_category).with("Breakfast")
    end

    it "imports up to `limit` recipes and ignores the rest" do
      ids = (1..15).map(&:to_s)
      allow(client).to receive(:list_by_category).with("Breakfast").and_return(ids)
      ids.first(10).each do |id|
        allow(client).to receive(:lookup).with(id).and_return(meal_data(id: id, title: "Meal #{id}"))
      end

      described_class.new(limit: 10, client: client).call

      expect(Recipe.count).to eq(10)
      expect(Recipe.pluck(:external_id)).to match_array(ids.first(10))
      ids.last(5).each do |id|
        expect(client).not_to have_received(:lookup).with(id)
      end
    end

    it "creates ingredients and recipe_ingredients with amounts" do
      allow(client).to receive(:list_by_category).and_return(["1"])
      allow(client).to receive(:lookup).with("1").and_return(
        meal_data(id: "1", ingredients: [["Flour", "2 cups"], ["Eggs", "3"]])
      )

      described_class.new(client: client).call

      recipe = Recipe.find_by!(external_id: "1")
      expect(recipe.ingredients.pluck(:name)).to match_array(%w[flour eggs])
      expect(recipe.recipe_ingredients.pluck(:amount)).to match_array(["2 cups", "3"])
    end

    it "reuses existing ingredients across recipes" do
      Ingredient.create!(name: "Flour")
      allow(client).to receive(:list_by_category).and_return(%w[1 2])
      allow(client).to receive(:lookup).with("1").and_return(
        meal_data(id: "1", ingredients: [["flour", "1 cup"]])
      )
      allow(client).to receive(:lookup).with("2").and_return(
        meal_data(id: "2", ingredients: [["flour", "2 cups"]])
      )

      expect { described_class.new(client: client).call }.to change(Ingredient, :count).by(0)
      expect(Ingredient.where(name: "flour").count).to eq(1)
    end

    it "skips recipes that already exist" do
      Recipe.create!(external_id: "1", title: "Old Cake")
      allow(client).to receive(:list_by_category).and_return(["1"])
      expect(client).not_to receive(:lookup)

      described_class.new(client: client).call

      expect(Recipe.find_by(external_id: "1").title).to eq("Old Cake")
    end

    it "skips when lookup returns nil" do
      allow(client).to receive(:list_by_category).and_return(["1"])
      allow(client).to receive(:lookup).with("1").and_return(nil)

      expect { described_class.new(client: client).call }.not_to change(Recipe, :count)
    end

    it "logs and continues when a single recipe fails" do
      allow(client).to receive(:list_by_category).and_return(%w[1 2])
      allow(client).to receive(:lookup).with("1").and_raise(StandardError, "boom")
      allow(client).to receive(:lookup).with("2").and_return(meal_data(id: "2"))
      allow(Rails.logger).to receive(:error)

      described_class.new(client: client).call

      expect(Rails.logger).to have_received(:error).with(/\[MealDbImporter\] 1: boom/)
      expect(Recipe.pluck(:external_id)).to eq(["2"])
    end

    it "rolls back the recipe if ingredient creation fails mid-transaction" do
      allow(client).to receive(:list_by_category).and_return(["1"])
      allow(client).to receive(:lookup).with("1").and_return(
        meal_data(id: "1", ingredients: [["flour", "1 cup"]])
      )
      allow(Ingredient).to receive(:find_or_create_by!).and_raise(ActiveRecord::RecordInvalid)
      allow(Rails.logger).to receive(:error)

      expect { described_class.new(client: client).call }.not_to change(Recipe, :count)
    end
  end

  describe ".call" do
    it "instantiates and calls" do
      allow(MealDbClient).to receive(:new).and_return(client)
      allow(client).to receive(:list_by_category).with("Breakfast").and_return([])

      described_class.call

      expect(client).to have_received(:list_by_category).with("Breakfast")
    end
  end
end
