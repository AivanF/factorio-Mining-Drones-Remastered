-- Optionally disable vanilla mining drills.
--
-- Required from data-final-fixes, NOT from data.lua. This mod declares no dependency on
-- space-age, so Factorio is free to load it first and does: the log shows this mod at
-- data.lua before space-age. At data stage the big mining drill therefore does not exist
-- yet, and every lookup below would silently find nothing. Final fixes is the first stage
-- where every other mod's prototypes are guaranteed to be present -- which also means a
-- mod cannot re-enable a drill after us.
-- F2.0 dropped the "hidden" item/entity flag in favour of a top-level boolean property,
-- and F2.1 rejects the old flag outright instead of ignoring it.

-- Splices a now-pointless technology out of the tree: everything that depended on it
-- inherits its own prerequisites, so no branch is left stranded behind a dead node.
local function retire_technology(technology)
    for _, dependent in pairs (data.raw.technology) do
        local prerequisites = dependent.prerequisites
        if prerequisites then
            local present = {}
            for _, prerequisite in pairs (prerequisites) do
                present[prerequisite] = true
            end
            for i = #prerequisites, 1, -1 do
                if prerequisites[i] == technology.name then
                    table.remove(prerequisites, i)
                    for _, inherited in pairs (technology.prerequisites or {}) do
                        if not present[inherited] and inherited ~= dependent.name then
                            present[inherited] = true
                            table.insert(prerequisites, inherited)
                        end
                    end
                end
            end
        end
    end
    -- Kept as a prototype rather than deleted, so foreign references stay resolvable.
    technology.hidden = true
    technology.enabled = false
end

local function forget_recipe(recipe_name)
    for _, technology in pairs (data.raw.technology) do
        local effects = technology.effects
        if effects then
            local dropped = false
            for i = #effects, 1, -1 do
                if effects[i].type == "unlock-recipe" and effects[i].recipe == recipe_name then
                    table.remove(effects, i)
                    dropped = true
                end
            end
            if dropped and not next(effects) then
                retire_technology(technology)
            end
        end
    end
end

-- Some technologies are unlocked by crafting an item rather than by research alone,
-- and that item may be one we just took away.
local function retarget_research_trigger(item_name, replacement_name)
    for _, technology in pairs (data.raw.technology) do
        local trigger = technology.research_trigger
        if trigger and trigger.type == "craft-item" and trigger.item == item_name then
            trigger.item = replacement_name
        end
    end
end

local function disable_drill(name)
    local item = data.raw.item[name]
    if item then
        item.hidden = true
    end

    local entity = data.raw["mining-drill"][name]
    if entity then
        entity.hidden = true
        entity.hidden_in_factoriopedia = true
    end

    local recipe = data.raw.recipe[name]
    if recipe then
        recipe.hidden = true
        recipe.enabled = false
    end

    forget_recipe(name)
end

-- Swaps one ingredient for another, merging amounts if the replacement is already
-- in the list, since a recipe may not name the same item twice.
local function substitute_ingredient(recipe_name, old_item, replacement)
    local recipe = data.raw.recipe[recipe_name]
    if not recipe or not recipe.ingredients then return end

    local existing
    for _, ingredient in pairs (recipe.ingredients) do
        if ingredient.name == replacement.name and ingredient.name ~= old_item then
            existing = ingredient
        end
    end

    for index = #recipe.ingredients, 1, -1 do
        if recipe.ingredients[index].name == old_item then
            if existing then
                existing.amount = existing.amount + replacement.amount
                table.remove(recipe.ingredients, index)
            else
                recipe.ingredients[index] = replacement
            end
        end
    end
end

local big_drill = "big-mining-drill"
local remove_big_drill = settings.startup["af-mining-drones-sa-no-big-drill"].value

-- Space Exploration hides both vanilla drill settings (see settings-final-fixes.lua), so
-- their effect has to stop too. A player who switched one on before installing SE would
-- otherwise be left with drills removed and no visible way back, since a mod cannot
-- rewrite a startup setting -- reported on the portal as "Burner Drill perma-disabled".
local vanilla_drills_removable = not mods["space-exploration"]

if vanilla_drills_removable and settings.startup["af-mining-drones-no-burner-drill"].value then
    disable_drill("burner-mining-drill")
end

if vanilla_drills_removable and settings.startup["af-mining-drones-no-electric-drill"].value then
    disable_drill("electric-mining-drill")

    -- Space Age builds the big mining drill out of an electric one, which no longer has a
    -- recipe. Unless it is being removed outright below, pay for it in steel plate instead,
    -- so the Vulcanus chain that runs through it stays reachable.
    if not remove_big_drill then
        substitute_ingredient(big_drill, "electric-mining-drill",
            {type = "item", name = "steel-plate", amount = 20})
    end
end

if remove_big_drill then
    -- Retiring its technology hands the big drill's prerequisites to whatever depended on
    -- it, and tungsten steel is additionally gated on *crafting* one - the foundry takes
    -- over that role, being what the big drill technology was itself triggered by.
    disable_drill(big_drill)
    retarget_research_trigger(big_drill, "foundry")
end
