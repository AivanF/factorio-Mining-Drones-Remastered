-- Shared data interface between data and script, notably prototype names.

local data = {}

data.mod_name = "Mining_Drones_Remastered"
data.mining_depot = "mining-depot"
data.drone_name = "mining-drone"
data.mining_damage = 5
data.mining_interval = math.floor(26 * 1.5) -- dictated by character mining animation
data.attack_proxy_name = "mining-drone-attack-proxy-new"

data.box_name = "mining-depot-collision-box"
data.proxy_corpse_name = "caution-corpse"
data.energy_int_name = "mining-depot-energy-interface"

data.variation_count = 20
data.mining_drone_collision_mask = {} -- gets overriden in settings-final-fixes.lua

if settings.startup["af-mining-drones-sep-prod"].value then
  data.mining_productivity_technology = "mining-drone-productivity"
else
  data.mining_productivity_technology = "mining-productivity"
end
data.mining_speed_technology = "mining-drone-mining-speed"

data.depot_info =
{
  capacity = settings.startup["af-mining-drones-capacity"].value,
  radius = 25 + 0.5,
  drop_offset = {0, -3.5},
  shifts =
  {
    north = {0,1.5},
    south = {0.1, -0.25},
    east = {-1.25, 0.6},
    west = {1.25, 0.6},
  }
}

data.get_drone_proxy_name = function (ore_name, index)
  return ore_name.."-"..shared.drone_name.."-"..index
end

return data
