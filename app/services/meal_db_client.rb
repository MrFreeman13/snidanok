# frozen_string_literal: true

require "net/http"
require "json"

class MealDbClient
  BASE_URL = "https://www.themealdb.com/api/json/v1/1"

  # Bulk listing: each summary already carries idMeal, strMeal and
  # strMealThumb — enough to render a plan list without per-recipe lookups.
  def summaries(category)
    encoded = URI.encode_www_form_component(category)
    get_json("#{BASE_URL}/filter.php?c=#{encoded}")["meals"] || []
  end

  def list_by_category(category)
    summaries(category).map { |m| m["idMeal"] }
  end

  # Full detail for one meal (ingredients + instructions). Only needed on the
  # recipe detail page, so it runs on click, not on every list render.
  def lookup(external_id)
    get_json("#{BASE_URL}/lookup.php?i=#{external_id}").dig("meals", 0)
  end

  private

  def get_json(url)
    JSON.parse(Net::HTTP.get(URI(url)))
  end
end
