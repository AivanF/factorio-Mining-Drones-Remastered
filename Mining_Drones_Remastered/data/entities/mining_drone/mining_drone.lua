local name = shared.drone_name

data:extend
{
  {
    type = "item",
    name = name,
    localised_name = {name},
    icon = "__Mining_Drones_Remastered__/data/icons/mining_drone.png",
    icon_size = 64,
    flags = {},
    subgroup = "extraction-machine",
    order = "zb"..name,
    stack_size = settings.startup["af-mining-drones-stack-size"].value,
    --place_result = name
  },
  {
    type = "recipe",
    name = name,
    localised_name = {name},
    --category = ,
    enabled = false,
    ingredients =
    {
      -- Final ingredients are set in customizer.lua
      {type="item", name="iron-plate", amount=10},
      {type="item", name="iron-gear-wheel", amount=5},
      {type="item", name="iron-stick", amount=10},
    },
    energy_required = 2,
    results = {{type="item", name=name, amount=1}},
  }
}
