-- Collect settings
local recipe_ingredients = {}
local need_logistics = false
local need_chemistry = false
local prerequisites = {"automation"}

if settings.startup["af-mining-drones-gears"].value then
    table.insert(recipe_ingredients, {"iron-gear-wheel", 5})
end
if settings.startup["af-mining-drones-sticks"].value then
    table.insert(recipe_ingredients, {"iron-stick", 10})
end
if settings.startup["af-mining-drones-steel"].value then
    table.insert(recipe_ingredients, {"steel-plate", 2})
    table.insert(prerequisites, "steel-processing")
end
if settings.startup["af-mining-drones-green"].value then
    table.insert(recipe_ingredients, {"electronic-circuit", 1})
    table.insert(prerequisites, "electronics")
end
if settings.startup["af-mining-drones-red"].value then
    table.insert(recipe_ingredients, {"advanced-circuit", 1})
    table.insert(prerequisites, "advanced-electronics")
    need_chemistry = true
end
if settings.startup["af-mining-drones-blue"].value then
    table.insert(recipe_ingredients, {"processing-unit", 1})
    table.insert(prerequisites, "advanced-electronics-2")
    need_chemistry = true
end
if settings.startup["af-mining-drones-battery"].value then
    table.insert(recipe_ingredients, {"battery", 1})
    table.insert(prerequisites, "battery")
    need_chemistry = true
end
if settings.startup["af-mining-drones-engine"].value then
    table.insert(recipe_ingredients, {"engine-unit", 1})
    table.insert(prerequisites, "engine")
    need_logistics = true
end
if settings.startup["af-mining-drones-elengine"].value then
    table.insert(recipe_ingredients, {"electric-engine-unit", 1})
    table.insert(prerequisites, "electric-engine")
    need_chemistry = true
end


-- Customise recipe
data.raw.recipe["mining-drone"].ingredients = recipe_ingredients

-- Customise technology research
local tech_ingredients = {
    {"automation-science-pack", 1},
}
if need_logistics or need_chemistry then
    table.insert(tech_ingredients, {"logistic-science-pack", 1})
end
if need_chemistry then
    table.insert(tech_ingredients, {"chemical-science-pack", 1})
end
data.raw.technology["mining-drone"].ingredients = tech_ingredients


-- Optionally disable vanilla mining drills
function hideRecipe(recipe)
    recipe.hidden = true
    recipe.enabled = false
    if recipe.normal then
        recipe.normal.hidden = true
        recipe.normal.enabled = false
        recipe.expensive.hidden = true
        recipe.expensive.enabled = false
    end
end

if settings.startup["af-mining-drones-no-burner-drill"].value then
    data.raw.item["burner-mining-drill"].flags = { "hidden" }
    data.raw["mining-drill"]["burner-mining-drill"].flags = { "hidden" }
    hideRecipe(data.raw.recipe["burner-mining-drill"])
end

if settings.startup["af-mining-drones-no-electric-drill"].value then
    data.raw.item["electric-mining-drill"].flags = { "hidden" }
    data.raw["mining-drill"]["electric-mining-drill"].flags = { "hidden" }
    hideRecipe(data.raw.recipe["electric-mining-drill"])
end
