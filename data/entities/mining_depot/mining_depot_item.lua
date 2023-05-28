local names = require("shared")
local name = names.mining_depot

data:extend
{
  {
    type = "item",
    name = name,
    icon = "__Mining_Drones_Remastered__/data/icons/mining_depot.png",
    icon_size = 64,
    flags = {},
    subgroup = "extraction-machine",
    order = "za"..name,
    place_result = name,
    stack_size = 5
  },
  {
    -- For ore mining
    type = "recipe-category",
    name = name
  },
  {
    type = "recipe",
    name = name,
    localised_name = {name},
    enabled = false,
    ingredients =
    {
      -- Final ingredients are set in customizer.lua
      {"iron-plate", 20},
      {"iron-chest", 10},
      {"iron-gear-wheel", 10},
      {"iron-stick", 20},
    },
    energy_required = 5,
    result = name
  },
}
