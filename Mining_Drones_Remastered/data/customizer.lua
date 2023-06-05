-- Aggregate settings
local depot_ingredients = {}
local drone_ingredients = {}
local need_logistics = false
local need_chemistry = false
local prerequisites = {"automation"}

local aai = mods["aai-industry"] ~= nil

local cnt = settings.startup["af-mining-drones-cost-mult"].value

if settings.startup["af-mining-drones-gears"].value then
    table.insert(depot_ingredients, {"iron-gear-wheel", 20})
    table.insert(drone_ingredients, {"iron-gear-wheel", cnt*5})
end
if settings.startup["af-mining-drones-sticks"].value then
    table.insert(depot_ingredients, {"iron-stick", 20})
    table.insert(drone_ingredients, {"iron-stick", cnt*10})
end
if settings.startup["af-mining-drones-steel"].value then
    table.insert(depot_ingredients, {"steel-plate", 20})
    table.insert(depot_ingredients, {"steel-chest", 10})
    table.insert(drone_ingredients, {"steel-plate", cnt*2})
    table.insert(prerequisites, "steel-processing")
else
    table.insert(depot_ingredients, {"iron-plate", 20})
    table.insert(depot_ingredients, {"iron-chest", 10})
end
if settings.startup["af-mining-drones-green"].value then
    table.insert(depot_ingredients, {"electronic-circuit", 20})
    table.insert(drone_ingredients, {"electronic-circuit", cnt*2})
    table.insert(prerequisites, "electronics")
end
if settings.startup["af-mining-drones-red"].value then
    table.insert(depot_ingredients, {"advanced-circuit", 20})
    table.insert(drone_ingredients, {"advanced-circuit", cnt*1})
    table.insert(prerequisites, "advanced-electronics")
    need_chemistry = true
end
if settings.startup["af-mining-drones-blue"].value then
    table.insert(depot_ingredients, {"processing-unit", 10})
    table.insert(drone_ingredients, {"processing-unit", cnt*1})
    table.insert(prerequisites, "advanced-electronics-2")
    need_chemistry = true
end
if settings.startup["af-mining-drones-battery"].value then
    table.insert(depot_ingredients, {"battery", 10})
    table.insert(drone_ingredients, {"battery", cnt*1})
    table.insert(prerequisites, "battery")
    need_chemistry = true
end
if settings.startup["af-mining-drones-engine"].value and not aai then
    table.insert(drone_ingredients, {"engine-unit", cnt*1})
    table.insert(prerequisites, "engine")
    need_logistics = true
end
if settings.startup["af-mining-drones-elengine"].value and not aai then
    table.insert(drone_ingredients, {"electric-engine-unit", cnt*1})
    table.insert(prerequisites, "electric-engine")
    need_chemistry = true
end
if settings.startup["af-mining-drones-eldrill"].value then
    table.insert(drone_ingredients, {"electric-mining-drill", cnt*1})
    -- TODO: add prerequisites, science packs for overhaul mods
end

if aai then
    if settings.startup["af-mining-drones-aai-motor"].value then
        table.insert(drone_ingredients, {"motor", cnt*1})
    end
    if settings.startup["af-mining-drones-aai-elmotor"].value then
        table.insert(drone_ingredients, {"electric-motor", cnt*1})
    end
    if settings.startup["af-mining-drones-aai-engine"].value then
        table.insert(drone_ingredients, {"engine-unit", cnt*1})
        table.insert(prerequisites, "engine")
    end
    if settings.startup["af-mining-drones-aai-elengine"].value then
        table.insert(drone_ingredients, {"electric-engine-unit", cnt*1})
        table.insert(prerequisites, "electric-engine")
    end
end

-- Customise recipes
data.raw.recipe[shared.mining_depot].ingredients = depot_ingredients
data.raw.recipe[shared.drone_name].ingredients = drone_ingredients

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

data.raw.technology[shared.drone_name].prerequisites = prerequisites
data.raw.technology[shared.drone_name].unit.ingredients = tech_ingredients


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
