data:extend({
    -- Basic
    {
        type = "bool-setting",
        name = "mute_drones",
        setting_type = "startup",
        localised_name = "Mute drone sounds",
        default_value = false,
        order = "1-01",
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-sep-prod",
        setting_type = "startup",
        localised_name = "Separate productivity research for drones",
        default_value = false,
        order = "1-04",
    },

    -- Tweak vanilla
    {
        type = "bool-setting",
        name = "af-mining-drones-no-burner-drill",
        setting_type = "startup",
        default_value = false,
        order = "2-01",
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-no-electric-drill",
        setting_type = "startup",
        default_value = false,
        order = "2-02",
    },

    -- Recipe
    {
        type = "bool-setting",
        name = "af-mining-drones-gears",
        setting_type = "startup",
        default_value = true,
        order = "3-01"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-sticks",
        setting_type = "startup",
        default_value = true,
        order = "3-02"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-steel",
        setting_type = "startup",
        default_value = false,
        order = "3-03"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-green",
        setting_type = "startup",
        default_value = false,
        order = "3-04"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-red",
        setting_type = "startup",
        default_value = true,
        order = "3-05"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-blue",
        setting_type = "startup",
        default_value = false,
        order = "3-06"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-battery",
        setting_type = "startup",
        default_value = true,
        order = "3-07"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-engine",
        setting_type = "startup",
        default_value = false,
        order = "3-08"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-elengine",
        setting_type = "startup",
        default_value = true,
        order = "3-09"
    },
})
