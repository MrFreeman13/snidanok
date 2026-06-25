# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlanSlotPresenter do
  let(:date) { Date.new(2026, 5, 19) }

  describe ".from_meal" do
    it "maps title, image and external id from a MealDB meal hash" do
      meal = {
        "idMeal" => "52772",
        "strMeal" => "Shakshuka",
        "strMealThumb" => "https://img.test/shakshuka.jpg"
      }

      slot = described_class.from_meal(date, meal)

      expect(slot.scheduled_for).to eq(date)
      expect(slot.title).to eq("Shakshuka")
      expect(slot.image_url).to eq("https://img.test/shakshuka.jpg")
      expect(slot.external_id).to eq("52772")
    end
  end

  describe ".from_recipe" do
    it "maps title, image and external id from a Recipe record" do
      recipe = Recipe.new(
        external_id: "100",
        title: "Pancakes",
        image_url: "https://img.test/pancakes.jpg"
      )

      slot = described_class.from_recipe(date, recipe)

      expect(slot.scheduled_for).to eq(date)
      expect(slot.title).to eq("Pancakes")
      expect(slot.image_url).to eq("https://img.test/pancakes.jpg")
      expect(slot.external_id).to eq("100")
    end
  end
end
