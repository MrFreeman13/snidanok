# frozen_string_literal: true

require "rails_helper"

RSpec.describe MealDbClient do
  let(:client) { described_class.new }

  describe "#list_by_category" do
    it "returns the idMeal values from the API response" do
      stub_http(
        "https://www.themealdb.com/api/json/v1/1/filter.php?c=Breakfast",
        { "meals" => [ { "idMeal" => "1" }, { "idMeal" => "2" } ] }
      )

      expect(client.list_by_category("Breakfast")).to eq(%w[1 2])
    end

    it "returns an empty array when the API returns no meals" do
      stub_http(
        "https://www.themealdb.com/api/json/v1/1/filter.php?c=Breakfast",
        { "meals" => nil }
      )

      expect(client.list_by_category("Breakfast")).to eq([])
    end

    it "URL-encodes the category" do
      stub_http(
        "https://www.themealdb.com/api/json/v1/1/filter.php?c=Side+Dish",
        { "meals" => [] }
      )

      expect(client.list_by_category("Side Dish")).to eq([])
    end
  end

  describe "#lookup" do
    it "returns the first meal in the response" do
      meal = { "idMeal" => "42", "strMeal" => "Pancakes" }
      stub_http(
        "https://www.themealdb.com/api/json/v1/1/lookup.php?i=42",
        { "meals" => [ meal ] }
      )

      expect(client.lookup("42")).to eq(meal)
    end

    it "returns nil when no meal is found" do
      stub_http(
        "https://www.themealdb.com/api/json/v1/1/lookup.php?i=999",
        { "meals" => nil }
      )

      expect(client.lookup("999")).to be_nil
    end
  end

  def stub_http(url, payload)
    allow(Net::HTTP).to receive(:get).with(URI(url)).and_return(payload.to_json)
  end
end
