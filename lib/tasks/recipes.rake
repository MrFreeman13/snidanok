namespace :recipes do
  desc "Import breakfast recipes from themealdb.com"
  task import: :environment do
    count_before = Recipe.count
    MealDbImporter.new.call
    puts "Imported #{Recipe.count - count_before} new recipes (total: #{Recipe.count})"
  end
end
