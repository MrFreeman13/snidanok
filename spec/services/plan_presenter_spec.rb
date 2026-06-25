# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlanPresenter do
  let(:client) { instance_double(MealDbClient) }

  def meal(id, title)
    { "idMeal" => id, "strMeal" => title, "strMealThumb" => "https://img.test/#{id}.jpg" }
  end

  describe "#call" do
    context "on a first visit (no session, no saved plan)" do
      it "samples breakfasts from the API for a 7-day range starting today" do
        ids = %w[100 101 102 103 104 105 106]
        allow(client).to receive(:list_by_category).with("Breakfast").and_return(ids)
        ids.each { |id| allow(client).to receive(:lookup).with(id).and_return(meal(id, "Meal #{id}")) }

        state = described_class.new(session_plan: nil, client: client).call

        expect(state.start_date).to eq(Date.current)
        expect(state.end_date).to eq(Date.current + 6.days)
        expect(state.slots.size).to eq(7)
        expect(state.slots.map(&:scheduled_for)).to eq((Date.current..Date.current + 6.days).to_a)
      end

      it "exposes a session_payload so the controller can seed the session" do
        ids = %w[100 101]
        allow(client).to receive(:list_by_category).and_return(ids)
        ids.each { |id| allow(client).to receive(:lookup).with(id).and_return(meal(id, "Meal #{id}")) }

        state = described_class.new(session_plan: nil, client: client).call

        expect(state.session_payload["external_ids"]).to match_array(ids)
        expect(state.session_payload["start_date"]).to eq(Date.current.iso8601)
        expect(state.session_payload["end_date"]).to eq((Date.current + 6.days).iso8601)
      end

      it "has nothing to seed when the catalog is empty" do
        allow(client).to receive(:list_by_category).and_return([])

        state = described_class.new(session_plan: nil, client: client).call

        expect(state.slots).to be_empty
        expect(state.session_payload).to be_nil
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

      it "does not produce a session_payload (saved plans are not re-seeded)" do
        recipe = Recipe.create!(external_id: "1", title: "Toast")
        plan = Plan.create!(start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 19))
        plan.plan_slots.create!(recipe: recipe, scheduled_for: Date.new(2026, 5, 19))

        state = described_class.new(session_plan: nil, client: client).call

        expect(state.session_payload).to be_nil
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
