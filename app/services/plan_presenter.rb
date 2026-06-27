# frozen_string_literal: true

# Prepares the plan shown on the landing page, and the data the Generate
# action needs to seed the session. Owns the display precedence:
#
#   1. Session ephemeral plan -> slots from the bulk catalog summaries
#   2. Most recently saved Plan -> slots from the DB
#   3. Nothing (first visit) -> sample 7 breakfasts from the catalog summaries
#
# Every branch builds slots from the bulk `summaries` listing (one API call,
# which already carries title + thumbnail). Full per-recipe detail is fetched
# only on the recipe detail page, never here.
#
# Always returns a State. For the first-visit branch the State also carries a
# `session_payload` the controller can persist, so the preview stays stable on
# refresh. The presenter itself never writes to the session.
class PlanPresenter
  CATEGORY = "Breakfast"
  DEFAULT_LENGTH_DAYS = 7

  State = Struct.new(:start_date, :end_date, :slots, :session_payload, keyword_init: true)

  def initialize(session_plan: nil, client: MealDbClient.new)
    @session_plan = session_plan
    @client = client
  end

  # Random breakfast ids for a date range. Used by PlansController#generate to
  # seed the session before the POST-redirect-GET.
  def sample_ids(start_date:, end_date:)
    days = (start_date..end_date).to_a.size
    summaries.sample(days).map { |m| m["idMeal"] }
  end

  def call
    return from_session if @session_plan.present?

    plan = Plan.latest_saved.first
    return from_saved_plan(plan) if plan

    fallback_preview
  end

  private

  def summaries
    @summaries ||= @client.summaries(CATEGORY)
  end

  def summary_index
    @summary_index ||= summaries.index_by { |m| m["idMeal"] }
  end

  def from_session
    start_d = Date.parse(@session_plan["start_date"])
    end_d   = Date.parse(@session_plan["end_date"])
    meals = @session_plan["external_ids"].map { |id| summary_index[id] }
    State.new(start_date: start_d, end_date: end_d, slots: slots_for(start_d, end_d, meals))
  end

  def from_saved_plan(plan)
    slots = plan.plan_slots
                .includes(:recipe)
                .sort_by(&:scheduled_for)
                .map { |s| PlanSlotPresenter.from_recipe(s.scheduled_for, s.recipe) }
    State.new(start_date: plan.start_date, end_date: plan.end_date, slots: slots)
  end

  # First visit: nothing saved, no session. Sample breakfasts from the catalog
  # so the page isn't blank, and hand back a payload the controller can persist.
  def fallback_preview
    start_d = Date.current
    end_d   = start_d + (DEFAULT_LENGTH_DAYS - 1).days
    picked = summaries.sample((start_d..end_d).to_a.size)
    ids = picked.map { |m| m["idMeal"] }

    State.new(
      start_date: start_d,
      end_date: end_d,
      slots: slots_for(start_d, end_d, picked),
      session_payload: ids.any? ? session_payload(start_d, end_d, ids) : nil
    )
  end

  # Pairs each date with its meal summary, dropping days whose meal is missing.
  def slots_for(start_date, end_date, meals)
    days = (start_date..end_date).to_a.first(meals.size)
    days.zip(meals).filter_map do |date, meal|
      next unless meal

      PlanSlotPresenter.from_meal(date, meal)
    end
  end

  def session_payload(start_date, end_date, external_ids)
    {
      "start_date"   => start_date.iso8601,
      "end_date"     => end_date.iso8601,
      "external_ids" => external_ids
    }
  end
end
