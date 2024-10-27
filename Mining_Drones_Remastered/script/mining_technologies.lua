local table = require("afutils")

local script_data_template = {
  -- effect => force => number
  cache_short = {
    walking_speed = {},
    mining_speed = {},
    cargo_size = {},
    productivity_bonus = {},
  },
  -- effect => force => technology => count
  cache_full = {},
}
local script_data = deepcopy(script_data_template)

-- technology name => effect => cf
local technology_effects = {
  [shared.mining_speed_technology] = {
    walking_speed = 0.2,
    mining_speed = 0.2,
    cargo_size = 1,
  },
  [shared.mining_productivity_technology] = {
    productivity_bonus = 0.1,
  },
  ["warptorio-mining-prod"] = {
    productivity_bonus = 0.1,
  },
}

local recalc_short_cache = function(forces)
  -- log("MD2R_recalc_short_cache: "..serpent.block(forces))
  for effect, by_force in pairs(script_data.cache_short) do
    for _, force in pairs(forces) do
      by_force[force] = 0
    end
  end
  for technology, by_effect in pairs(technology_effects) do
    for effect, cf in pairs(by_effect) do
      for _, force in pairs(forces) do
        script_data.cache_short[effect][force.index] = (
          (script_data.cache_short[effect][force.index] or 0) +
          cf * (deepget(script_data.cache_full, force.index, technology) or 0)
        )
      end
    end
  end
end

local review_technology = function(technology, do_recalc)
  for name, _ in pairs(technology_effects) do
    if technology.researched and technology.name:find(name, 0, true) then
      local force_index = technology.force.index
      script_data.cache_full[force_index] = script_data.cache_full[force_index] or {}
      script_data.cache_full[force_index][name] = technology.level
      -- log("MD2R_review: added "..technology.name.." for "..force_index)
      if do_recalc then
        recalc_short_cache({fake={index=force_index}})
      end
      return 1
    end
  end
  return 0
end


local on_research_finished = function(event)
  review_technology(event.research, true)
end

local lib = {}

lib.get_walking_speed_bonus = function(force_index)
  return script_data.cache_short.walking_speed[force_index] or 0
end

lib.get_mining_speed_bonus = function(force_index)
  return script_data.cache_short.mining_speed[force_index] or 0
end

lib.get_cargo_size_bonus = function(force_index)
  return script_data.cache_short.cargo_size[force_index] or 0
end

lib.get_productivity_bonus = function(force_index)
  return script_data.cache_short.productivity_bonus[force_index] or 0
end

lib.on_configuration_changed = function()
  log("MD2R_mining_tech_on_conf_changed")
  -- Reset caches
  local a, b = 0, 0
  script_data = deepcopy(script_data_template)
  storage.mining_technologies = script_data
  for _, force in pairs(game.forces) do
    for _, technology in pairs(force.technologies) do
      a = a + 1
      b = b + review_technology(technology, false)
    end
  end
  log("MD2R_tech_eview: "..b.." / "..a)
  -- log("MD2R_tech_cache_full: "..serpent.block(script_data.cache_full))
  recalc_short_cache(game.forces)
  -- log("MD2R_tech_cache_short: "..serpent.block(script_data.cache_short))
end

lib.on_load = function()
  log("MD2R_mining_tech_on_load")
  script_data = storage.mining_technologies or script_data
end

lib.on_init = function()
  log("MD2R_mining_tech_on_init")
  storage.mining_technologies = storage.mining_technologies or script_data
end

lib.events =
{
  [defines.events.on_research_finished] = on_research_finished
}

return lib