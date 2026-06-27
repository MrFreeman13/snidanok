# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlanSlot, type: :model do
  let(:plan) { Plan.create!(start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 25)) }
  let(:recipe) { Recipe.create!(external_id: "1", title: "Pancakes") }

  describe "associations" do
    it "belongs to a plan" do
      slot = PlanSlot.new(recipe: recipe, scheduled_for: Date.new(2026, 5, 19))
      expect(slot).not_to be_valid
      expect(slot.errors[:plan]).to include("must exist")
    end

    it "belongs to a recipe" do
      slot = PlanSlot.new(plan: plan, scheduled_for: Date.new(2026, 5, 19))
      expect(slot).not_to be_valid
      expect(slot.errors[:recipe]).to include("must exist")
    end
  end

  describe "validations" do
    it "is valid with plan, recipe, and scheduled_for" do
      slot = PlanSlot.new(plan: plan, recipe: recipe, scheduled_for: plan.start_date)
      expect(slot).to be_valid
    end

    it "requires scheduled_for" do
      slot = PlanSlot.new(plan: plan, recipe: recipe, scheduled_for: nil)
      expect(slot).not_to be_valid
      expect(slot.errors[:scheduled_for]).to include("can't be blank")
    end

    it "prevents two slots on the same date within the same plan" do
      other_recipe = Recipe.create!(external_id: "2", title: "Toast")
      PlanSlot.create!(plan: plan, recipe: recipe, scheduled_for: plan.start_date)
      duplicate = PlanSlot.new(plan: plan, recipe: other_recipe, scheduled_for: plan.start_date)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:scheduled_for]).to include("has already been taken")
    end

    it "allows the same date across different plans" do
      other_plan = Plan.create!(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 7))
      PlanSlot.create!(plan: plan, recipe: recipe, scheduled_for: Date.new(2026, 5, 19))

      expect(PlanSlot.new(plan: other_plan, recipe: recipe, scheduled_for: Date.new(2026, 5, 19))).to be_valid
    end
  end
end
