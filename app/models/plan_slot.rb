# frozen_string_literal: true

class PlanSlot < ApplicationRecord
  belongs_to :plan
  belongs_to :recipe

  validates :scheduled_for, presence: true
  validates :scheduled_for, uniqueness: { scope: :plan_id }
end
