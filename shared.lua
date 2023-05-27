-- Shared data interface between data and script, notably prototype names.

local data = {}

data.drone_name = "mining-drone"
data.proxy_chest_name = "mining-drone-proxy-chest"
data.mining_damage = 5
data.mining_interval = math.floor(26 * 1.5) -- dictated by character mining animation
data.attack_proxy_name = "mining-drone-attack-proxy-new"
data.mining_depot = "mining-depot"
data.variation_count = 20
data.mining_drone_collision_mask = {"error-fix-me"}

if settings.startup["af-mining-drones-sep-prod"].value then
  data.mining_productivity_technology = "mining-drone-productivity"
else
  data.mining_productivity_technology = "mining-productivity"
end
data.mining_speed_technology = "mining-drone-mining-speed"

data.depots =
{
  ["mining-depot"] =
  {
    radius = 25 + 0.5,
    capacity = settings.startup["af-mining-drones-capacity"].value,
    drop_offset = {0, -3.5},
    shifts =
    {
      north = {0,1.5},
      south = {0.1, -0.25},
      east = {-1.25, 0.6},
      west = {1.25, 0.6},
    }
  }
}

return data
