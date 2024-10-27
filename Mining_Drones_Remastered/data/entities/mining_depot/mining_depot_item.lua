local name = shared.mining_depot

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
      {type = "item", name = "iron-plate", amount = 20},
      {type = "item", name = "iron-chest", amount = 10},
      {type = "item", name = "iron-gear-wheel", amount = 10},
      {type = "item", name = "iron-stick", amount = 20},
    },
    energy_required = 5,
    results = {{type="item", name=name, amount=1}},
  },
}
