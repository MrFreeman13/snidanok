# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlanPresenter do
  let(:client) { instance_double(MealDbClient) }

  def summary(id, title)
    { "idMeal" => id, "strMeal" => title, "strMealThumb" => "https://img.test/#{id}.jpg" }
  end

  describe "#call" do
    context "on a first visit (no session, no saved plan)" do
      it "samples breakfasts from the catalog summaries for a 7-day range" do
        summaries = (100..106).map { |i| summary(i.to_s, "Meal #{i}") }
        allow(client).to receive(:summaries).with("Breakfast").and_return(summaries)

        state = described_class.new(session_plan: nil, client: client).call

        expect(state.start_date).to eq(Date.current)
        expect(state.end_date).to eq(Date.current + 6.days)
        expect(state.slots.size).to eq(7)
        expect(state.slots.map(&:scheduled_for)).to eq((Date.current..Date.current + 6.days).to_a)
      end

      it "builds slots without any per-recipe lookups" do
        allow(client).to receive(:summaries).and_return([ summary("100", "Shakshuka") ])
        allow(client).to receive(:lookup)

        described_class.new(session_plan: nil, client: client).call

        expect(client).not_to have_received(:lookup)
      end

      it "exposes a session_payload so the controller can seed the session" do
        summaries = %w[100 101].map { |id| summary(id, "Meal #{id}") }
        allow(client).to receive(:summaries).and_return(summaries)

        state = described_class.new(session_plan: nil, client: client).call

        expect(state.session_payload["external_ids"]).to match_array(%w[100 101])
        expect(state.session_payload["start_date"]).to eq(Date.current.iso8601)
        expect(state.session_payload["end_date"]).to eq((Date.current + 6.days).iso8601)
      end

      it "has nothing to seed when the catalog is empty" do
        allow(client).to receive(:summaries).and_return([])

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
      it "rebuilds slots from the catalog summaries, not per-recipe lookups" do
        summaries = %w[100 101].map { |id| summary(id, id == "100" ? "Shakshuka" : "Berry Bowl") }
        allow(client).to receive(:summaries).with("Breakfast").and_return(summaries)
        allow(client).to receive(:lookup)

        session_plan = {
          "start_date"   => "2026-05-19",
          "end_date"     => "2026-05-20",
          "external_ids" => %w[100 101]
        }

        state = described_class.new(session_plan: session_plan, client: client).call

        expect(state.slots.map(&:title)).to eq([ "Shakshuka", "Berry Bowl" ])
        expect(state.start_date).to eq(Date.new(2026, 5, 19))
        expect(client).not_to have_received(:lookup)
      end

      it "drops a day whose id is no longer in the catalog" do
        allow(client).to receive(:summaries).and_return([ summary("100", "Shakshuka") ])

        session_plan = {
          "start_date"   => "2026-05-19",
          "end_date"     => "2026-05-20",
          "external_ids" => %w[100 999]
        }

        state = described_class.new(session_plan: session_plan, client: client).call

        expect(state.slots.map(&:title)).to eq([ "Shakshuka" ])
      end
    end
  end

  describe "#sample_ids" do
    it "samples one id per day from the catalog summaries" do
      summaries = %w[100 101 102 103].map { |id| summary(id, "Meal #{id}") }
      allow(client).to receive(:summaries).with("Breakfast").and_return(summaries)

      ids = described_class.new(client: client).sample_ids(
        start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 21)
      )

      expect(ids.size).to eq(3)
      expect(ids).to all(be_in(%w[100 101 102 103]))
    end

    it "returns at most as many ids as the catalog has" do
      allow(client).to receive(:summaries).and_return([ summary("100", "Meal") ])

      ids = described_class.new(client: client).sample_ids(
        start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 25)
      )

      expect(ids.size).to eq(1)
    end
  end
end
