util = require "data/tf_util/tf_util"
shared = require("shared")

local collision_util = require("collision-mask-util")
local default_masks = require("collision-mask-defaults")

local drone_layer = { type = "collision-layer", order = "42", name = "mining_drone" }
data:extend{drone_layer}

for k, prototype in pairs (collision_util.collect_prototypes_with_layer("player")) do
  if prototype.name ~= "mining-depot" and prototype.type ~= "character" then
    local mask = collision_util.get_mask(prototype)
    mask.layers[drone_layer.name] = true
    prototype.collision_mask = mask
  end
end

shared.mining_drone_collision_mask = {
  not_colliding_with_itself = true,
  consider_tile_transitions = true,
  layers =
  {
    mining_drone = true,
    doodad = true
  }
}

require("data/entities/attack_proxy/attack_proxy")
