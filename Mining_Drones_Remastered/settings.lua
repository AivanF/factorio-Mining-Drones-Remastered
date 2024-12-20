data:extend({
    -- Map/global
    {
        type = "int-setting",
        name = "af-mining-drones-work-energy",
        setting_type = "runtime-global",
        minimum_value = 0,
        maximum_value = 10000,
        default_value = 100,
        order = "1-01",
    },
    {
        type = "double-setting",
        name = "af-mining-drones-pollute-rate",
        setting_type = "runtime-global",
        minimum_value = 0.01,
        maximum_value = 2.0,
        default_value = 0.3,
        order = "1-02",
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-clean-player",
        setting_type = "runtime-global",
        default_value = true,
        order = "1-03",
    },

    -- Basic
    {
        type = "bool-setting",
        name = "mute_drones",
        setting_type = "startup",
        default_value = false,
        order = "1-01",
    },
    {
        type = "int-setting",
        name = "af-mining-drones-capacity",
        setting_type = "startup",
        minimum_value = 10,
        maximum_value = 2000,
        default_value = 100,
        order = "1-02",
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-sep-prod",
        setting_type = "startup",
        default_value = false,
        order = "1-03",
    },
    {
        type = "int-setting",
        name = "af-mining-drones-stack-size",
        setting_type = "startup",
        minimum_value = 5,
        maximum_value = 500,
        default_value = 20,
        order = "1-04",
    },
    {
        type = "int-setting",
        name = "af-mining-drones-perf-mult",
        setting_type = "startup",
        minimum_value = 1,
        maximum_value = 50,
        default_value = 1,
        order = "1-05",
    },
    {
        type = "int-setting",
        name = "af-mining-drones-research-cost",
        setting_type = "startup",
        minimum_value = 5,
        maximum_value = 1000,
        default_value = 100,
        order = "1-06",
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

    -- Other mods related
    {
        type = "bool-setting",
        name = "af-mining-drones-se-allow",
        setting_type = "startup",
        default_value = true,
        order = "3-se-01",
    },

    -- Recipe
    {
        type = "string-setting",
        name = "af-mining-drones-recipe--",
        localised_name = "--------- Recipe settings:",
        setting_type = "startup",
        default_value = "",
        allow_blank = true,
        order = "4-000"
    },
    {
        type = "int-setting",
        name = "af-mining-drones-cost-mult",
        setting_type = "startup",
        minimum_value = 1,
        maximum_value = 200,
        default_value = 1,
        order = "4-001",
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-gears",
        setting_type = "startup",
        default_value = true,
        order = "4-01"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-sticks",
        setting_type = "startup",
        default_value = true,
        order = "4-02"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-steel",
        setting_type = "startup",
        default_value = false,
        order = "4-03"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-green",
        setting_type = "startup",
        default_value = false,
        order = "4-04"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-red",
        setting_type = "startup",
        default_value = true,
        order = "4-05"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-blue",
        setting_type = "startup",
        default_value = false,
        order = "4-06"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-battery",
        setting_type = "startup",
        default_value = true,
        order = "4-07"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-engine",
        setting_type = "startup",
        default_value = false,
        order = "4-08"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-elengine",
        setting_type = "startup",
        default_value = true,
        order = "4-09"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-eldrill",
        setting_type = "startup",
        default_value = false,
        order = "4-100"
    },
    -- AAI Industry
    {
        type = "bool-setting",
        name = "af-mining-drones-aai-motor",
        setting_type = "startup",
        default_value = false,
        order = "5-aai-01"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-aai-elmotor",
        setting_type = "startup",
        default_value = true,
        order = "5-aai-02"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-aai-engine",
        setting_type = "startup",
        default_value = false,
        order = "5-aai-03"
    },
    {
        type = "bool-setting",
        name = "af-mining-drones-aai-elengine",
        setting_type = "startup",
        default_value = false,
        order = "5-aai-04"
    },
})
