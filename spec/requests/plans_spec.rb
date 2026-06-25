# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Plans", type: :request do
  let(:client) { instance_double(MealDbClient) }

  def meal(id, title)
    { "idMeal" => id, "strMeal" => title, "strMealThumb" => "https://img.test/#{id}.jpg" }
  end

  before do
    # Keep request specs off the network. Default: empty catalog (no slots).
    # Individual tests override list_by_category / lookup as needed.
    allow(MealDbClient).to receive(:new).and_return(client)
    allow(client).to receive(:list_by_category).with("Breakfast").and_return([])
    allow(client).to receive(:lookup).and_return(nil)
  end

  describe "GET / (plans#current)" do
    it "returns http success and renders the date form + Generate button" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Generate")
      expect(response.body).to include("type=\"date\"")
    end

    it "shows the empty-state message when the catalog has no breakfasts" do
      get root_path
      expect(response.body).to include("No breakfasts yet")
    end

    it "samples breakfasts from the API on a first visit" do
      allow(client).to receive(:list_by_category).with("Breakfast").and_return(%w[100 101])
      allow(client).to receive(:lookup).with("100").and_return(meal("100", "Shakshuka"))
      allow(client).to receive(:lookup).with("101").and_return(meal("101", "Berry Bowl"))

      get root_path

      expect(response.body).to include("Shakshuka", "Berry Bowl")
      expect(response.body).not_to include("No breakfasts yet")
    end

    it "seeds the session so a refresh does not re-sample" do
      allow(client).to receive(:list_by_category).with("Breakfast").and_return(%w[100 101 102])
      %w[100 101 102].each { |id| allow(client).to receive(:lookup).with(id).and_return(meal(id, "Meal #{id}")) }

      get root_path
      get root_path

      expect(client).to have_received(:list_by_category).once
    end

    it "renders the most recently saved plan when one exists" do
      recipe = Recipe.create!(external_id: "1", title: "Saved Shakshuka", image_url: "https://img.test/s.jpg")
      plan = Plan.create!(start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 19))
      plan.plan_slots.create!(recipe: recipe, scheduled_for: Date.new(2026, 5, 19))

      get root_path

      expect(response.body).to include("Saved Shakshuka")
      expect(response.body).to include("May 19")
    end

    it "renders the session-stored ephemeral plan when present" do
      allow(client).to receive(:list_by_category).with("Breakfast").and_return(%w[100 101])
      allow(client).to receive(:lookup).with("100").and_return(meal("100", "Shakshuka"))
      allow(client).to receive(:lookup).with("101").and_return(meal("101", "Berry Bowl"))

      post generate_plans_path, params: { start_date: "2026-05-19", end_date: "2026-05-20" }
      get root_path

      expect(response.body).to include("Shakshuka", "Berry Bowl")
    end
  end

  describe "POST /plans/generate" do
    it "redirects to root (POST-redirect-GET, so Turbo renders the result)" do
      allow(client).to receive(:list_by_category).with("Breakfast").and_return(%w[100 101 102])

      post generate_plans_path, params: { start_date: "2026-05-19", end_date: "2026-05-21" }

      expect(response).to redirect_to(root_path)
    end

    it "renders the chosen dates after following the redirect" do
      allow(client).to receive(:list_by_category).with("Breakfast").and_return(%w[100 101 102])
      allow(client).to receive(:lookup).with("100").and_return(meal("100", "Shakshuka"))
      allow(client).to receive(:lookup).with("101").and_return(meal("101", "Berry Bowl"))
      allow(client).to receive(:lookup).with("102").and_return(meal("102", "Pancakes"))

      post generate_plans_path, params: { start_date: "2026-05-19", end_date: "2026-05-21" }
      follow_redirect!

      expect(response.body).to include("May 19", "May 20", "May 21")
    end

    it "stores the generated plan in the session so refreshing keeps it" do
      allow(client).to receive(:list_by_category).with("Breakfast").and_return(%w[100])
      allow(client).to receive(:lookup).with("100").and_return(meal("100", "Shakshuka"))

      post generate_plans_path, params: { start_date: "2026-05-19", end_date: "2026-05-19" }

      get root_path
      expect(response.body).to include("Shakshuka")
    end
  end
end
