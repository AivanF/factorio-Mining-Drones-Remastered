-- Prerequisites and ingredients are set in customizer.lua
data:extend{{
    name = "mining-drone",
    type = "technology",
    icons = {
      {
        icon = "__Mining_Drones_Remastered__/data/technologies/mining_drones_tech.png",
        icon_size = 256,
        icon_mipmaps = 0,
      }
    },
    upgrade = true,
    effects = {
        {
            type = "unlock-recipe",
            recipe = "mining-depot",
        },
        {
            type = "unlock-recipe",
            recipe = "mining-drone",
        },
    },
    prerequisites = {},
    unit = {
        count = 100,
        ingredients = {{"automation-science-pack", 1}},
        time = 30
    },
    order = name
}}
