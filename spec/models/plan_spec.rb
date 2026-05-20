
  describe ".recent" do
    it "orders plans by start_date descending" do
      older = Plan.create!(start_date: Date.new(2026, 5, 1), end_date: Date.new(2026, 5, 7))
      newer = Plan.create!(start_date: Date.new(2026, 5, 19), end_date: Date.new(2026, 5, 25))

      expect(Plan.recent).to eq([ newer, older ])
    end
  end
