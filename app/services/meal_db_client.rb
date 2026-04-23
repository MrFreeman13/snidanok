# frozen_string_literal: true

require "net/http"
require "json"

class MealDbClient
  BASE_URL = "https://www.themealdb.com/api/json/v1/1"

  def list_by_category(category)
    encoded = URI.encode_www_form_component(category)
    meals = get_json("#{BASE_URL}/filter.php?c=#{encoded}")["meals"] || []
    meals.map { |m| m["idMeal"] }
  end

  def lookup(external_id)
    get_json("#{BASE_URL}/lookup.php?i=#{external_id}").dig("meals", 0)
  end

  private

  def get_json(url)
    JSON.parse(Net::HTTP.get(URI(url)))
  end
end
