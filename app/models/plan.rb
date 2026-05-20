# frozen_string_literal: true

class Plan < ApplicationRecord
  has_many :plan_slots, dependent: :destroy
  has_many :recipes, through: :plan_slots

  validates :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
