# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlanPresenter do
  let(:client) { instance_double(MealDbClient) }

  def meal(id, title)
    { "idMeal" => id, "strMeal" => title, "strMealThumb" => "https://img.test/#{id}.jpg" }
  end

  describe "#call" do
    context "when neither session nor saved plan exists" do
      it "returns an empty state with a 7-day range starting today" do
        state = described_class.new(session_plan: nil, client: client).call

        expect(state.slots).to be_empty
        expect(state.start_date).to eq(Date.current)
        expect(state.end_date).to eq(Date.current + 6.days)
      end
    end

    context "when a saved plan exists (no session)" do
      it "uses the most recently saved plan, regardless of start_date order" do
        early_recipe = Recipe.create!(external_id: "1", title: "Old Toast")
        late_recipe  = Recipe.create!(external_id: "2", title: "Fresh Toast")

        older_save = Plan.create!(start_date: Date.new(2027, 1, 1), end_date: Date.new(2027, 1, 2))
        older_save.plan_slots.create!(recipe: early_recipe, scheduled_for: Date.new(2027, 1, 1))

        newer_save = Plan.create!(start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 20))
        newer_save.plan_slots.create!(recipe: late_recipe, scheduled_for: Date.new(2026, 5, 19))

        state = described_class.new(session_plan: nil, client: client).call

        expect(state.start_date).to eq(Date.new(2026, 5, 19))
        expect(state.end_date).to eq(Date.new(2026, 5, 20))
        expect(state.slots.map(&:title)).to eq([ "Fresh Toast" ])
      end
    end

    context "when a session plan is present" do
      it "rebuilds slots from the stored ids via the API, even if a saved plan exists" do
        Plan.create!(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 2))
        allow(client).to receive(:lookup).with("100").and_return(meal("100", "Shakshuka"))
        allow(client).to receive(:lookup).with("101").and_return(meal("101", "Berry Bowl"))

        session_plan = {
          "start_date"   => "2026-05-19",
          "end_date"     => "2026-05-20",
          "external_ids" => %w[100 101]
        }

        state = described_class.new(session_plan: session_plan, client: client).call

        expect(state.slots.map(&:title)).to eq([ "Shakshuka", "Berry Bowl" ])
        expect(state.start_date).to eq(Date.new(2026, 5, 19))
        expect(state.end_date).to eq(Date.new(2026, 5, 20))
      end

      it "skips a day silently when its lookup returns nil" do
        allow(client).to receive(:lookup).with("100").and_return(meal("100", "Shakshuka"))
        allow(client).to receive(:lookup).with("101").and_return(nil)

        session_plan = {
          "start_date"   => "2026-05-19",
          "end_date"     => "2026-05-20",
          "external_ids" => %w[100 101]
        }

        state = described_class.new(session_plan: session_plan, client: client).call

        expect(state.slots.map(&:title)).to eq([ "Shakshuka" ])
      end
    end
  end

  describe "#sample_ids" do
    it "samples one id per day in the range without doing lookups" do
      allow(client).to receive(:list_by_category).with("Breakfast").and_return(%w[100 101 102 103])
      allow(client).to receive(:lookup)

      ids = described_class.new(client: client).sample_ids(
        start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 21)
      )

      expect(ids.size).to eq(3)
      expect(ids).to all(be_in(%w[100 101 102 103]))
      expect(client).not_to have_received(:lookup)
    end

    it "returns at most as many ids as the catalog has" do
      allow(client).to receive(:list_by_category).with("Breakfast").and_return(%w[100 101])

      ids = described_class.new(client: client).sample_ids(
        start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 25)
      )

      expect(ids.size).to eq(2)
    end
  end
end
