# frozen_string_literal: true

# Prepares the plan shown on the landing page, and the data the Generate
# action needs to seed the session. Owns the display precedence:
#
#   1. Session ephemeral plan -> rebuild slots from the stored ids (API)
#   2. Most recently saved Plan -> slots from the DB
#   3. Nothing (first visit) -> sample 7 breakfasts from the API as a preview
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

  # Random breakfast ids for a date range. Used by PlansController#generate
  # to seed the session before the POST-redirect-GET (cheap: no lookups).
  def sample_ids(start_date:, end_date:)
    days = (start_date..end_date).to_a.size
    @client.list_by_category(CATEGORY).sample(days)
  end

  def call
    return from_session if @session_plan.present?

    plan = Plan.latest_saved.first
    return from_saved_plan(plan) if plan

    fallback_preview
  end

  private

  def from_session
    start_d = Date.parse(@session_plan["start_date"])
    end_d   = Date.parse(@session_plan["end_date"])
    slots = slots_from_ids(start_d, end_d, @session_plan["external_ids"])
    State.new(start_date: start_d, end_date: end_d, slots: slots)
  end

  def from_saved_plan(plan)
    slots = plan.plan_slots
                .includes(:recipe)
                .sort_by(&:scheduled_for)
                .map { |s| PlanSlotPresenter.from_recipe(s.scheduled_for, s.recipe) }
    State.new(start_date: plan.start_date, end_date: plan.end_date, slots: slots)
  end

  # First visit: nothing saved, no session. Sample breakfasts from the API so
  # the page isn't blank, and hand back a payload the controller can persist.
  def fallback_preview
    start_d = Date.current
    end_d   = start_d + (DEFAULT_LENGTH_DAYS - 1).days
    ids = sample_ids(start_date: start_d, end_date: end_d)

    State.new(
      start_date: start_d,
      end_date: end_d,
      slots: slots_from_ids(start_d, end_d, ids),
      session_payload: ids.any? ? session_payload(start_d, end_d, ids) : nil
    )
  end

  def session_payload(start_date, end_date, external_ids)
    {
      "start_date"   => start_date.iso8601,
      "end_date"     => end_date.iso8601,
      "external_ids" => external_ids
    }
  end

  # Turns stored external ids into slot presenters (one API lookup each).
  def slots_from_ids(start_date, end_date, external_ids)
    days = (start_date..end_date).to_a.first(external_ids.size)
    days.zip(external_ids).filter_map do |date, id|
      meal = @client.lookup(id)
      next unless meal

      PlanSlotPresenter.from_meal(date, meal)
    end
  end
end
