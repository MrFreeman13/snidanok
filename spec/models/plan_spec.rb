# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plan, type: :model do
  describe ".latest_saved" do
    it "orders plans by created_at descending (most recently saved first)" do
      older = Plan.create!(start_date: Date.new(2027, 1, 1), end_date: Date.new(2027, 1, 7))
      newer = Plan.create!(start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 25))

      # `newer` was created after `older`, even though its start_date is earlier
      expect(Plan.latest_saved.to_a).to eq([ newer, older ])
    end
  end
end
