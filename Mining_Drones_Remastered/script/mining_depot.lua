local mining_drone = require("script/mining_drone")
local mining_technologies = require("script/mining_technologies")

local ceil = math.ceil
local floor = math.floor
local min = math.min
local max = math.max
local random = math.random
local insert = table.insert

-- Energy lack handling to reduce oscillations
local on_lack_wait_none = 5  -- no new drones after shortage
local on_lack_wait_small = 15  -- then max 1 new drone output

local target_amount_per_drone = 100
local max_target_amount = 65000 -- Output inventory max size is 2^16
local max_capacity = settings.startup["af-mining-drones-capacity"].value

local path_queue_rate = 13
local path_request_flags = {cache = false, low_priority = false}

local depot_update_rate = 60
local variation_count = shared.variation_count
local perfmult = settings.startup["af-mining-drones-perf-mult"].value

local show_pots = true

local hide_pots = function ()
  log("MD2R_hide_pots")
  show_pots = false
end

---@alias UnitNumber number
---@alias BucketIndex number

---@class DepotCtrl
    ---@field entity LuaEntity @ depot's game object
    ---@field surface_index number @ depot's surface
    ---@field force_index number @ depot's force
    ---@field unit_number UnitNumber @ depot's unit number

    ---@field drones table<UnitNumber, boolean> @ if has a drone
    ---@field potential array<number> @ on_entity_destroyed registrations of ore??
    ---@field path_requests table<path_request_id, entity>
    ---@field fluid table/Ingredient @nullable required fluid for mining
    ---@field corpse LuaEntity @ drones proxy enter
    ---@field spawn_corpse LuaEntity @ drones proxy spawner

local mining_depot = {}
local depot_metatable = {__index = mining_depot}
mining_depot.metatable = {__index = mining_depot}
script.register_metatable("mining_depot", mining_depot.metatable)


-- NOTE: fields with the same name of DepotCtrl and script_data may have different types!
---@shape script_data
    ---@field depots table<BucketIndex, table<UnitNumber, DepotCtrl>>
    ---@field path_requests table<path_request_id, DepotCtrl>
    ---@field targeted_resources WTF
    ---@field request_queue table<path_request_id, DepotCtrl>
    ---@field big_migration boolean
    ---@field reset_corpses boolean
    ---@field clear_wall_migration boolean

local script_data =
{
  depots = {},
  path_requests = {},
  targeted_resources = {},
  request_queue = {},
  big_migration = true,
  reset_corpses = true,
  clear_wall_migration = true,
}


local get_energy_per_work = function()
  return floor(settings.global["af-mining-drones-work-energy"].value * 1000 / 60)
end


local get_mining_depot = function(unit_number)
  local bucket = script_data.depots[unit_number % depot_update_rate]
  return bucket and bucket[unit_number]
end

mining_drone.get_mining_depot = get_mining_depot


local main_products = {}
local get_main_product = function(entity)
  local cached = main_products[entity.name]
  if cached then return cached end
  local products = entity.prototype.mineable_properties.products
  cached = products[1]
  main_products[entity.name] = cached
  return cached

end


function mining_depot:get_mining_count(entity)
  -- entity is ore
  local bonus = mining_technologies.get_cargo_size_bonus(self.force_index)
  return min(3*perfmult + random(2*perfmult + bonus*perfmult), entity.amount)
end


local radius_offsets = {}
local offset = {shared.depot_info.drop_offset[1], shared.depot_info.drop_offset[2]}
local radius_offset = {}
local shifts = shared.depot_info.shifts

radius_offset[defines.direction.north] = {offset[1], offset[2] - 0.5}
radius_offset[defines.direction.south] = {-offset[1], -offset[2] + 0.5}
radius_offset[defines.direction.east] = {-offset[2] + 0.5, -offset[1]}
radius_offset[defines.direction.west] = {offset[2] - 0.5, offset[1]}
radius_offsets[shared.mining_depot] = radius_offset

local custom_drop_offsets = {
  [defines.direction.north] = {0, 0.5},
  [defines.direction.east] = {0, 0.5},
  [defines.direction.south] = {0, -0.5},
  [defines.direction.west] = {0, 0.5},
}

function mining_depot:get_drop_offset()
  local offset = radius_offsets[self.entity.name][self.entity.direction]
  local x = offset[1] + custom_drop_offsets[self.entity.direction][1]
  local y = offset[2] + custom_drop_offsets[self.entity.direction][2]
  return {x, y}
end

function mining_depot:get_radius_offset()
  return radius_offsets[self.entity.name][self.entity.direction]
end


local add_to_bucket = function(depot)
  local unit_number = depot.unit_number
  local depots = script_data.depots
  local bucket = depots[unit_number % depot_update_rate]
  if not bucket then
    bucket = {}
    depots[unit_number % depot_update_rate] = bucket
  end
  bucket[unit_number] = depot
end


local collide_box = function()
  return
  {
    left_top = {x = -2.5, y = -5.5},
    right_bottom = {x = 2.5, y = 2.5}
  }
end

local wall_thickness = 1.25
local wall_padding = 0.25
local front_gap = 2
local box_name = shared.box_name
local render_player_index = 42069

function mining_depot:add_wall()
  local direction = self.entity.direction
  local box = self.entity.bounding_box
  if direction == 0 then
    box.left_top.y = box.left_top.y + 1
  elseif direction == 2 then
    box.right_bottom.x = box.right_bottom.x - 1
  elseif direction == 4 then
    box.right_bottom.x = box.right_bottom.x - 1
  elseif direction == 8 then
    box.right_bottom.y = box.right_bottom.y - 1
  else
    box.left_top.x = box.left_top.x + 1
  end
  local position = {0,0}
  local boxes = {}
  local surface = self.entity.surface

  if direction ~= 0 then
    table.insert(boxes, surface.create_entity
    {
      name = box_name,
      bounding_box =
      {
        {box.left_top.x, box.left_top.y},
        {box.right_bottom.x, box.left_top.y + wall_thickness},
      },
      position = position,
      render_player_index = render_player_index
    })
  end

  if direction ~= 4 then
    table.insert(boxes, surface.create_entity
    {
      name = box_name,
      bounding_box =
      {
        {box.right_bottom.x - wall_thickness, box.left_top.y},
        {box.right_bottom.x, box.right_bottom.y},
      },
      position = position,
      render_player_index = render_player_index
    })
  end

  if direction ~= 8 then
    table.insert(boxes, surface.create_entity
    {
      name = box_name,
      bounding_box =
      {
        {box.left_top.x, box.right_bottom.y - wall_thickness},
        {box.right_bottom.x, box.right_bottom.y},
      },
      position = position,
      render_player_index = render_player_index
    })
  end

  if direction ~= 12 then
    table.insert(boxes, surface.create_entity
    {
      name = box_name,
      bounding_box =
      {
        {box.left_top.x, box.left_top.y},
        {box.left_top.x + wall_thickness, box.right_bottom.y},
      },
      position = position,
      render_player_index = render_player_index
    })
  end

  for k, v in pairs (boxes) do
    v.active = false
  end

  self.boxes = boxes

end

function mining_depot:clear_wall()
  if not self.boxes then return end
  for k, entity in pairs (self.boxes) do
    if entity.valid then
      entity.destroy()
    end
  end
  self.boxes = nil
end

function mining_depot:add_energy_interface()
  if self.energy_interface and self.energy_interface.valid then
    error("depot.energy_interface already set")
    return
  end

  self.energy_interface = self.entity.surface.create_entity
  {
    name = "mining-depot-energy-interface",
    position = self.entity.position,
    force = "neutral"
  }
end

function mining_depot:remove_energy_interface()
  if self.energy_interface and self.energy_interface.valid then
    self.energy_interface.destroy()
    self.energy_interface = nil
  end
end

function mining_depot:add_corpse()
  if self.corpse and self.corpse.valid then
    error("depot.corpse already set")
    return
  end

  local corpse = self.entity.surface.create_entity
  {
    name = shared.proxy_corpse_name,
    position = self:get_drop_position(),
    force = "neutral"
  }
  corpse.corpse_expires = false
  self.corpse = corpse
end

function mining_depot:remove_corpse()

  if self.corpse and self.corpse.valid then
    self.corpse.destroy()
    self.corpse = nil
  end

end

function mining_depot:add_spawn_corpse()
  if self.spawn_corpse and self.spawn_corpse.valid then
    error("depot.spawn_corpse already set")
    return
  end

  local spawn_corpse = self.entity.surface.create_entity
  {
    name = shared.proxy_corpse_name,
    position = self.entity.position,
    force = "neutral"
  }

  spawn_corpse.corpse_expires = false
  self.spawn_corpse = spawn_corpse
end

function mining_depot:remove_spawn_corpse()

  if self.spawn_corpse and self.spawn_corpse.valid then
    self.spawn_corpse.destroy()
    self.spawn_corpse = nil
  end

end


function mining_depot.new(entity)
  local depot =
  {
    entity = entity,
    drones = {},
    potential = {},
    recent = {},
    path_requests = {},
    surface_index = entity.surface.index,
    force_index = entity.force.index,
    unit_number = entity.unit_number,
    fluid = nil,
  }
  setmetatable(depot, mining_depot.metatable)

  if not script_data.targeted_resources[depot.surface_index] then
    script_data.targeted_resources[depot.surface_index] = {}
  end

  depot:add_energy_interface()
  depot:add_corpse()
  depot:add_spawn_corpse()
  depot:add_wall()

  add_to_bucket(depot)

  entity.active = false

  --[[
    local area = depot:get_area()
    rendering.draw_rectangle
    {
      color = {0.5, 0.5, 0, 0.5},
      filled = true,
      left_top = area[1],
      right_bottom = area[2],
      surface = entity.surface,
      draw_on_ground = true
    }
  ]]

  return depot
end


local on_built_entity = function(event)
  local entity = event.entity or event.created_entity or event.destination
  if not (entity and entity.valid) then return end
  if entity.name ~= shared.mining_depot then return end

  mining_depot.new(entity)
  if event.source then
    mining_depot.delete_depot_ctrl(event.source.unit_number)
  end
  -- game.print("MD2R_depot_built "..entity.unit_number)
end


function mining_depot.remove_from_list(unit_number)
  script_data.depots[unit_number % depot_update_rate][unit_number] = nil
end


function mining_depot:get_drop_position()
  local offset = self:get_drop_offset()
  local position = self.entity.position
  position.x = position.x + offset[1]
  position.y = position.y + offset[2]
  return position
end

local get_speed_variance = function()
  return (1 + (random() - 0.5) / 3)
end

local drone_base_speed = 0.1

function mining_depot:get_drone_speed()
  return (drone_base_speed * (1 + 0.2 * mining_technologies.get_walking_speed_bonus(self.force_index))) * get_speed_variance()
end

local direction_shared =
{
  [0] = "north",
  [2] = "east",
  [4] = "south",
  [6] = "west"
}

function mining_depot:get_spawn_corpse()
  if self.spawn_corpse and self.spawn_corpse.valid then
    return self.spawn_corpse
  end
  self:add_spawn_corpse()
  return self.spawn_corpse
end

function mining_depot:get_corpse()
  if self.corpse and self.corpse.valid then
    return self.corpse
  end
  self:add_corpse()
  return self.corpse
end

function mining_depot:spawn_drone()

  if self:get_active_drone_count() >= self:get_drone_item_count() then
    return
  end

  local name = self.target_resource_name.."-"..shared.drone_name.."-"..random(variation_count)

  local entity = self.entity
  local spawn_entity_data =
  {
    name = name,
    position = self.entity.position,
    force = entity.force,
    create_build_effect_smoke = false
  }

  local surface = entity.surface
  if not surface.can_place_entity(spawn_entity_data) then return end

  local unit = surface.create_entity(spawn_entity_data)
  if not unit then return end

  unit.orientation = (entity.direction / 8)
  --unit.ai_settings.do_separation = false

  --self:get_drone_inventory().remove({name = shared.drone_name, count = 1})


  local drone = mining_drone.new(unit, self)
  self.drones[unit.unit_number] = true

  self:update_sticker()
  return drone
end


function mining_depot:update_sticker()
  local text = self:get_active_drone_count().."/"..self:get_drone_item_count()

  local satisfaction = 100
  if self.energy_interface and self.energy_interface.valid then
    satisfaction = 100 * self.energy_interface.energy / self.energy_interface.electric_buffer_size or 0
  end
  if satisfaction < 96 then
    text = text.."\n"..floor(satisfaction).."%"
  end
  -- text = text.." "..serpent.block(self.had_lack)
  -- text = text.."\n"..floor(self.energy_interface.energy)

  if not self.target_resource_name then
    text = ""
  end

  -- Update old one
  if self.rendering and self.rendering.valid then
    self.rendering.text = text
    return
  end

  -- Make new one
  self.rendering = rendering.draw_text
  {
    surface = self.surface_index,
    target = self.entity,
    target_offset = {0, -0.5},
    text = text,
    only_in_alt_mode = true,
    forces = {self.entity.force},
    color = {r = 1, g = 1, b = 1},
    alignment = "center",
    scale = 1.5
  }

end


function mining_depot:cancel_all_orders()
  for unit_number, bool in pairs(self.drones) do
    local drone = mining_drone.get_drone(unit_number)
    if drone then
      drone:cancel_drone()
    end
  end
  self.drones = {}
end


function mining_depot:target_name_changed()

  self.target_resource_name = self:get_target_resource_name()
  self.fluid = self:get_required_fluid()

  self:clear_path_requests()
  self:cancel_all_orders()

  self:find_potential_targets()

  if self.rendering then
    self.rendering.destroy()
    self.rendering = nil
  end

  if self.pot_animation then
    self.pot_animation.destroy()
    self.pot_animation = nil
  end

end


function mining_depot:get_required_fluid()
  local recipe = self.entity.get_recipe()
  if not recipe then return end
  return recipe.ingredients[2]
end


local alert_data = {type = "item", name = shared.mining_depot}
local target_offset = {0, -0.5}

function mining_depot:add_no_items_alert(string)
  for k, player in pairs (self.entity.force.connected_players) do
    player.add_custom_alert(self.entity, alert_data, {"", {"depot-no-target"}}, true)
  end

  rendering.draw_sprite
  {
    surface = self.surface_index,
    target = self.entity,
    sprite = "utility/warning_icon",
    forces = {self.entity.force},
    time_to_live = 30,
    target_offset = target_offset,
    render_layer = "entity-info-icon-above"
  }
end



function mining_depot:update()

  --game.print(tostring(next(self.recent)))

  local entity = self.entity
  if not (entity and entity.valid) then return end

  self:update_sticker()

  local item = self:get_target_resource_name()
  if item ~= self.target_resource_name then
    self:target_name_changed()
    return
  end

  if not item then return end

  self:update_pot()
  self:update_energy_usage()

  if not self:has_mining_targets() then
    --Nothing to mine, nothing to do...

    if next(self.drones) then
      --Drones are still mining, so they can be holding the targets.
      return
    end

    if not self.mined_any then
      -- Last time we rescanned, and we didn't mine anything, so lets give up.
      self:add_no_items_alert()
      return
    end

    self:find_potential_targets()

  end

  if not self:has_enough_fluid() or not self:has_enough_energy() then
    return
  end

  self:try_to_mine_targets()

end


function mining_depot:get_full_ratio(drones_count)
  -- To prevent recalc and allow fake shifting value for visuals
  drones_count = drones_count or self:get_drone_item_count()

  local current_item_count = self:get_max_output_amount()
  if current_item_count == 0 then return 0 end

  local productivity = 1 + mining_technologies.get_productivity_bonus(self.force_index)
  local current_target_item_count = target_amount_per_drone * productivity * drones_count
  current_target_item_count = min(current_target_item_count, max_target_amount)

  local ratio = (current_item_count / current_target_item_count)
  return ratio
end

function mining_depot:drones_want_to_have()
  local drones_count = self:get_drone_item_count()
  local full_ratio = self:get_full_ratio(drones_count)
  local ratio = 1 - full_ratio ^ 2
  return ceil(ratio * drones_count)
end


function mining_depot:get_should_spawn_drone_count(extra)
  -- Check previous energy insufficiency
  local max_by_energy = 10
  if self.had_lack ~= nil then
    if self.had_lack > 0 then
      if not extra then self.had_lack = self.had_lack - 1 end -- Ignore calls by coming back drones
      max_by_energy = 1
      -- game.print("MD2R had_lack: "..self.had_lack)
    end
    if self.had_lack > on_lack_wait_small then return 0 end
  end

  -- Check electric power
  local satisfaction = 1
  if get_energy_per_work() > 0 then
    satisfaction = self.energy_interface and self.energy_interface.valid and self.energy_interface.energy / self.energy_interface.electric_buffer_size or 0
    if satisfaction < 0.8 then
      self.had_lack = on_lack_wait_small + on_lack_wait_none
      return 0
    end
  end

  -- Path finds in progress, don't over achieve
  local path_requests = table_size(self.path_requests)
  local request_queue = script_data.request_queue[self.unit_number]
  if request_queue then
    path_requests = path_requests + table_size(request_queue)
  end

  local active = (self:get_active_drone_count() - (extra and 1 or 0)) + path_requests
  local drones_count = self:get_drone_item_count()
  if active >= drones_count then return 0 end
  local want = self:drones_want_to_have(extra)
  if active >= want then return 0 end

  -- game.print("MD2R: ".." act="..self:get_active_drone_count().." paths="..path_requests.." want="..want.." sat="..floor(satisfaction*100))

  local result = min(
    -- ceil(want * satisfaction) - active,
    want - active,
    ceil(depot_update_rate / path_queue_rate),
    max_by_energy
  )
  -- game.print("MD2R add: "..result.." max_by_energy: "..max_by_energy)
  return result
end

function mining_depot:say(text)
  -- For debugging
  game.print(text)
  self.entity.surface.create_entity{name = "flying-text", position = self.entity.position, text = text}
end

function mining_depot:try_to_mine_targets()

  local drones_count = self:get_drone_item_count()
  local active = self:get_active_drone_count()

  if active >= drones_count then
    return
  end

  local should_spawn_count = self:get_should_spawn_drone_count()

  if should_spawn_count <= 0 then return end

  for k = 1, should_spawn_count do
    local entity = self:find_entity_to_mine()
    if not entity then
      -- game.print("MD2R: nothing no mine :(")
      return
    end
    self:attempt_to_mine(entity)
  end

end


function mining_depot:has_mining_targets()
  return next(self.recent) or next(self.potential)
end


function mining_depot:has_enough_energy()
  local energy_interface = self.energy_interface
  local energy_per_work = get_energy_per_work()
  local result = energy_per_work < 1 or energy_interface and energy_interface.valid and energy_interface.energy > energy_per_work * 2
  if not result then
    -- game.print("MD2R: not enough energy: "..floor(energy_interface.energy / energy_per_work))
  end
  return result
end

function mining_depot:has_enough_fluid()
  if not self.fluid then return true end
  local box = self:get_input_fluidbox()
  if not box then return false end

  return box.amount >= (self.fluid.amount / 10)
end

function mining_depot:get_input_fluidbox()
  local fluidbox = self.entity.fluidbox
  if #fluidbox == 0 then return end
  return fluidbox[1]
end

function mining_depot:get_drone_item_count()
  return self.entity.get_item_count(shared.drone_name)
end

local unique_index = function(entity)
  return script.register_on_object_destroyed(entity)
end


function mining_depot:get_radius()
  return shared.depot_info.radius or error("POOP")
end

local directions =
{
  [defines.direction.north] = {0, -1},
  [defines.direction.south] = {0, 1},
  [defines.direction.east] = {1, 0},
  [defines.direction.west] = {-1, 0},
}

function mining_depot:get_area()
  local origin = self.entity.position
  local drop_offset = self:get_radius_offset()
  local radius = self:get_radius()
  local direction = directions[self.entity.direction]
  local radius_offset = {direction[1] * radius, direction[2] * radius}
  origin.x = origin.x + drop_offset[1] + radius_offset[1]
  origin.y = origin.y + drop_offset[2] + radius_offset[2]
  return util.area(origin, radius)
end


function mining_depot:sort_by_distance(entities)

  local origin = self.entity.position
  local x, y = origin.x, origin.y

  local distance = function(position)
    return ((x - position.x) ^ 2 + (y - position.y) ^ 2)
  end

  local targeted_resources = script_data.targeted_resources[self.surface_index]

  for k, entity in pairs (entities) do
    local index = unique_index(entity)
    if not targeted_resources[index] then
      targeted_resources[index] =
      {
        entity = entity,
        depots = {},
        max_mining = ceil(entity.get_radius() ^ 2),
        mining = 0
      }
    end
    entities[k] = {distance = distance(entity.position), index = index}
  end

  table.sort(entities, function (k1, k2) return k1.distance > k2.distance end )

  for k = 1, #entities do
    entities[k] = entities[k].index
  end

  return entities

end

function mining_depot:find_potential_targets()

  local target_name = self.target_resource_name
  if not target_name then
    self.potential = {}
    self.recent = {}
    self.mined_any = nil
    return
  end

  local unsorted = self.entity.surface.find_entities_filtered
  {
    type = "resource",
    area = self:get_area(),
    name = target_name
  }

  self.potential = self:sort_by_distance(unsorted)
  self.recent = {}
  self.mined_any = nil

end


function mining_depot:find_entity_to_mine()

  local targeted_resources = script_data.targeted_resources[self.surface_index]

  local recent = self.recent

  for entity_index, bool in pairs (recent) do
    local target_data = targeted_resources[entity_index]
    if target_data.entity.valid then
      target_data.depots[self.unit_number] = true
      if target_data.mining < target_data.max_mining then
        target_data.mining = target_data.mining + 1
        if target_data.mining >= target_data.max_mining then
          recent[entity_index] = nil
        end
        return target_data.entity
      end
    end
    recent[entity_index] = nil
  end

  local entities = self.potential
  if not entities[1] then return end

  local size = #entities
  --game.print(size)
  while true do

    local entity_index = entities[size]
    if not entity_index then break end

    local target_data = targeted_resources[entity_index]
    if target_data.entity.valid then
      target_data.depots[self.unit_number] = true
      if target_data.mining < target_data.max_mining then
        target_data.mining = target_data.mining + 1
        if target_data.mining >= target_data.max_mining then
          entities[size] = nil
        end
        return target_data.entity
      end
    end

    entities[size] = nil

    size = size - 1

  end

end

function mining_depot:remove_drone(drone, remove_item)

  if remove_item then
    self:get_drone_inventory().remove{name = shared.drone_name, count = 1}
  end

  local mining_target = drone.mining_target
  if mining_target and mining_target.valid then
    self:add_mining_target(mining_target)
  end

  drone.mining_target = nil

  self.drones[drone.unit_number] = nil
  self:update_sticker()
end

--self.potential[drone.desired_item][unique_index(target)] = target

function mining_depot:order_drone(drone, entity) -- entity is ore
  -- game.print("MD2R order")

  if not self.mined_any then
    self.mined_any = true
  end

  local mining_count = self:get_mining_count(entity)

  if self.fluid then
    local box = self:get_input_fluidbox()
    if not box then
      self:add_mining_target(entity)
      return
    end
    local needed_fluid = (self.fluid.amount / 100) * mining_count
    if box.amount < needed_fluid then
      local mining_count = floor(box.amount / (self.fluid.amount / 100))
      if mining_count == 0 then
        self:add_mining_target(entity)
        return
      end
      needed_fluid = (self.fluid.amount / 100) * mining_count
    end
    self:take_fluid(needed_fluid)
  end

  self:take_energy()

  drone.entity.speed = self:get_drone_speed()
  drone:mine_entity(entity, mining_count)

end

function mining_depot:take_fluid(amount)
  local box = self:get_input_fluidbox()
  if not box then log("MD2R: no fluid box!!!") return end
  local current = box.amount
  box.amount = box.amount - amount
  self.entity.force.get_fluid_production_statistics(self.entity.surface).on_flow(self.fluid.name, -amount)
  if box.amount == 0 then
    box = nil
  end
  self.entity.fluidbox[1] = box
end

function mining_depot:take_energy()
  -- local energy_interface = self.energy_interface
  -- energy_interface.energy = energy_interface.energy - 5 * get_energy_per_work()
  -- self:update_energy_usage()
end

function mining_depot:handle_order_request(drone)

  if not (drone.mining_target and drone.mining_target.valid) then
    self:return_drone(drone)
    return
  end

  local should_spawn_count = (self:get_should_spawn_drone_count(true))

  if should_spawn_count <= 0
      or not self:has_enough_fluid()
      or not self:has_enough_energy()
  then
    self:return_drone(drone)
    return
  end

  self:order_drone(drone, drone.mining_target)

end

function mining_depot:get_output_inventory()
  return self.entity.get_output_inventory()
end

function mining_depot:get_drone_inventory()
  return self.entity.get_inventory(defines.inventory.assembling_machine_input)
end

function mining_depot:get_target_resource_name()
  local recipe = self.entity.get_recipe()
  if not recipe then return end
  local name = recipe.name:sub(("mine-"):len() + 1, recipe.name:len())
  return name
end

function mining_depot:get_max_output_amount()
  local inventory = self:get_output_inventory()
  local amount = 0
  local recipe = self.entity.get_recipe()
  if not recipe then return 0 end
  for k, product in pairs (recipe.products) do
    amount = max(amount, inventory.get_item_count(product.name))
  end
  return amount
end

function mining_depot:handle_path_request_finished(event)

  local entity = self.path_requests[event.id]
  if not (entity and entity.valid) then return end

  if not self.entity.valid then
    self:add_mining_target(entity, true)
    return
  end

  self.path_requests[event.id] = nil

  if event.try_again_later then
    self:attempt_to_mine(entity)
    return
  end

  if not (event.path and self.entity.valid) then
    -- We can't reach it, don't spawn any miners
    self:add_mining_target(entity, true)
    return
  end

  if not self:has_enough_fluid() or not self:has_enough_energy() then
    -- Don't have enough prerequisites to mine anything
    self:add_mining_target(entity)
    return
  end

  local drone = self:spawn_drone()

  if not drone then
    -- For some reason, we can't spawn a drone
      self:add_mining_target(entity)
      return
  end

  self:order_drone(drone, entity)

end

function mining_depot:update_energy_usage()
  local energy_per_work = get_energy_per_work()
  local energy_interface = self.energy_interface

  if energy_per_work < 1 then
    if energy_interface and energy_interface.valid then
      self:remove_energy_interface()
    end
    return
  end

  if not energy_interface or not energy_interface.valid then
    self:add_energy_interface()
    return
  end

  if energy_per_work > 1 then
    -- local required_buffer = (self:get_active_drone_count() + 10) *energy_per_work *60 *5
    -- energy_interface.electric_buffer_size = max(required_buffer, energy_interface.energy)
    energy_interface.electric_buffer_size = 10 * energy_per_work *60 *5

    energy_interface.power_usage = (5 + self:get_active_drone_count()) * energy_per_work
  else
    energy_interface.power_usage = 0
    energy_interface.electric_buffer_size = 0
  end
end

local direction_names =
{
  [0] = "north",
  [4] = "east",
  [8] = "south",
  [12] = "west"
}

function mining_depot:update_pot()

  if not self.target_resource_name or not show_pots then
    if self.pot_animation and rendering.is_valid(self.pot_animation) then
      self.pot_animation.destroy()
    end
    return
  end

  if not show_pots then return end

  if not (self.pot_animation and self.pot_animation.valid) then
    self.pot_animation = rendering.draw_animation
    {
      animation = "depot-pot-"..self.target_resource_name.."-"..direction_names[self.entity.direction],
      render_layer = "higher-object-under",
      target = self.entity,
      surface = self.entity.surface
    }
  end

  -- This prevents insane image swapping (from totally full to almost empty)
  -- when putting/removing drones.
  local full_ratio = self:get_full_ratio(self:get_drone_item_count() + 20)
  local offset = max(0, min(ceil(full_ratio * 17) - 1, 16))
  self.pot_animation.animation_offset = offset
end

function mining_depot:on_resource_given()
  self.entity.surface.create_entity{name = "depot-smoke-"..self.target_resource_name.."-"..direction_names[self.entity.direction], position = self.entity.position}
end

function mining_depot:return_drone(drone)
  self:remove_drone(drone)
  drone:clear_things()
  drone.entity.destroy()
  self:update_sticker()
end


function mining_depot:add_mining_target(entity, ignore_self)
  local targeted_resources = script_data.targeted_resources[self.surface_index]
  local index = unique_index(entity)
  local target_data = targeted_resources[index]
  target_data.mining = target_data.mining - 1

  if target_data.mining < 0 then
    target_data.mining = 0
    -- error("HUHEKR?")
  end

  for depot_index, bool in pairs(target_data.depots) do
    if not ignore_self or depot_index ~= self.unit_number then
      local depot = get_mining_depot(depot_index)
      if depot then
        if not depot.recent then
          depot.recent = {}
        end
        depot.recent[index] = true
      end
    end
  end

end


function mining_depot:clear_path_requests()
  local global_requests = script_data.path_requests
  for k, entity in pairs (self.path_requests) do
    self:add_mining_target(entity, true)
    global_requests[k] = nil
  end
  self.path_requests = {}
end


function mining_depot:handle_depot_deletion()
  self:cancel_all_orders()
  self.drones = nil
  self:remove_energy_interface()
  self:remove_corpse()
  self:remove_spawn_corpse()
  self:clear_wall()
end


function mining_depot:get_all_depots()
  local depots = {}
  for k, bucket in pairs (script_data.depots) do
    for unit_number, depot in pairs (bucket) do
      if not depot.entity.valid then
        bucket[unit_number] = nil
      else
        depots[unit_number] = depot
      end
    end
  end
  return depots
end

function mining_depot:get_active_drone_count()
  return table_size(self.drones)
end


local process_request_queue = function()
  if next(script_data.path_requests) then return end
  for depot_unit_number, entities in pairs (script_data.request_queue) do
    local depot = get_mining_depot(depot_unit_number)
    if depot then
      local entity_index, entity = next(entities)
      if entity then
        if entity.valid then
          depot:request_path(entity)
        end
        entities[entity_index] = nil
      end
    else
      script_data.request_queue[depot_unit_number] = nil
    end
  end
end


local on_tick = function(event)

  local bucket = script_data.depots[event.tick % depot_update_rate]
  if bucket then
    for unit_number, depot in pairs (bucket) do
      if not (depot.entity.valid) then
        depot:handle_depot_deletion()
        bucket[unit_number] = nil
      else
        depot:update()
      end
    end
  end

  if event.tick % path_queue_rate == 0 then
    process_request_queue()
  end

end


local box, mask
local get_box_and_mask = function()
  if not (box and mask) then
    local prototype = prototypes.entity[shared.drone_name]
    box = prototype.collision_box
    mask = prototype.collision_mask
  end
  return box, mask
end


function mining_depot:attempt_to_mine(entity)

  local depot_queue = script_data.request_queue[self.unit_number]
  if not depot_queue then
    depot_queue = {}
    script_data.request_queue[self.unit_number] = depot_queue
  end

  table.insert(depot_queue, entity)
end


function mining_depot:request_path(entity)
  --Will make a path request, and if it passes, send a drone to go mine it.
  local box, mask = get_box_and_mask()
  local path_request_id = self.entity.surface.request_path
  {
    bounding_box = box,
    collision_mask = mask,
    start = self.entity.position,
    goal = entity.position,
    force = self.entity.force,
    radius = entity.get_radius() + 0.5,
    can_open_gates = true,
    pathfind_flags = path_request_flags,
  }

  script_data.path_requests[path_request_id] = self
  self.path_requests[path_request_id] = entity

end


local on_script_path_request_finished = function(event)
  --game.print(event.tick.." - "..event.id)
  local depot = script_data.path_requests[event.id]
  if not depot then return end
  script_data.path_requests[event.id] = nil
  depot:handle_path_request_finished(event)
end


local on_entity_removed = function(event)

  local unit_number = event.unit_number
  if not unit_number then
    local entity = event.entity
    if not (entity and entity.valid) then
      return
    end
    unit_number = entity.unit_number
  end

  mining_depot.delete_depot_ctrl(unit_number)
end


function mining_depot.delete_depot_ctrl(unit_number)
  if not unit_number then return end
  local bucket = script_data.depots[unit_number % depot_update_rate]
  if not bucket then return end
  local depot = bucket[unit_number]
  if not depot then return end
  depot:handle_depot_deletion()
  bucket[unit_number] = nil
end


function mining_depot:check_for_rescan()
  if self.target_resource_name == self:get_target_resource_name() then
    return
  end
  self:target_name_changed()
end


local cancel_all_depots = function()
  for k, bucket in pairs (script_data.depots) do
    for unit_number, depot in pairs (bucket) do
      depot:cancel_all_orders()
      depot:update_sticker()
    end
  end
end


local rescan_all_depots = function(silent)
  if not silent then
    local profiler = game.create_profiler()
  end
  for k, bucket in pairs (script_data.depots) do
    for unit_number, depot in pairs (bucket) do
      depot:find_potential_targets()
    end
  end
  if not silent then
    game.print{"", "Mining drones: Rescanned mining targets. ", profiler}
  end
end


local reset_all_depots = function()
  cancel_all_depots()
  rescan_all_depots()
end


-- local clear_targeted_resources = function()
--   for k, bucket in pairs (script_data.depots) do
--     for unit_number, depot in pairs (bucket) do
--       depot:cancel_all_orders()
--     end
--   end
--   for k, surface in pairs (script_data.targeted_resources) do
--     script_data.targeted_resources[k] = {}
--   end
-- end

local on_object_destroyed = function(event)
  if event.type ~= defines.target_type.entity then return end
  local unit_number = event.useful_id
  local bucket = script_data.depots[unit_number % depot_update_rate]
  if not bucket then return end
  local depot = bucket[unit_number]
  if not depot then return end
  depot:handle_depot_deletion()
  bucket[unit_number] = nil
end


local clean_player_inv = function(event)  -- on_gui_opened
  if not settings.global["af-mining-drones-clean-player"].value then return end

  -- Check depot
  entity = event.entity
  if not (entity and entity.valid) then return end
  if entity.name ~= shared.mining_depot then return end
  --depot = get_mining_depot(entity.unit_number)

  -- game.print("Opening depot: "..entity.unit_number)

  -- Check player
  player = game.get_player(event.player_index)
  if not player then return end

  dst = entity.get_output_inventory()
  --dst = depot:get_output_inventory()
  src = player.get_inventory(defines.inventory.character_main)
  if not src then return end  -- SE satellite view

  local count = 0
  local recipe = entity.get_recipe()
  if not recipe then return end

  for _, product in pairs (recipe.products) do
    count = min(
      src.get_item_count(product.name),
      max_target_amount - dst.get_item_count(product.name)
    )
    if count > 0 then
      src.remove({name = product.name, count = count})
      dst.insert({name = product.name, count = count})
    end
  end
end


local update_configuration = function(manual)
  -- Migrate from other MD mods
  if #script_data.depots == 0 then
    script_data.big_migration = false
    script_data.reset_corpses = false
    script_data.clear_wall_migration = false
    local depot_count = 0
    local drone_count = 0
    local inter_count = 0
    local  wall_count = 0
    for _, surface in pairs (game.surfaces) do
      for _, entity in pairs (surface.find_entities_filtered{name=shared.mining_depot}) do
        mining_depot.new(entity)
        depot_count = depot_count + 1
      end
      for _, v in pairs (surface.find_entities_filtered{name=box_name}) do
        v.destroy()
        wall_count = wall_count + 1
      end
      for _, entity in pairs (surface.find_entities_filtered{name=shared.energy_int_name}) do
        entity.destroy()
        inter_count = inter_count + 1
      end
      for _, entity in pairs (surface.find_entities_filtered{type="unit"}) do
        if entity.name:find(shared.drone_name, 1, true) then
          entity.destroy()
          drone_count = drone_count + 1
        end
      end
    end
    local txt = "MD2R AivanF migration: "
    if manual then txt = "MD2R total reset: " end
    txt = txt.."De="..depot_count..", Dr="..drone_count..", w="..wall_count..", int="..inter_count
    game.print(txt)
    log(txt)
  end

  -- Clear texts with no references to prevent overlapping
  local alive_labels = {}
  for _, depot in pairs(script_data.depots) do
    if depot.rendering then
      alive_labels[depot.rendering.id] = true
    end
  end
  local removed_labels = 0
  local all_drawings = rendering.get_all_objects()
  for _, obj in pairs(all_drawings) do
    if (obj
      and obj.type == "text"
      -- `target` property is missing on many other types
      and obj.target.entity
      and obj.target.entity.name == shared.mining_depot
      and not alive_labels[obj.id]
    ) then
      obj.destroy()
      removed_labels = removed_labels + 1
    end
  end
  if removed_labels > 0 then
    local txt = "MD2R: removed "..removed_labels.." labels."
    -- game.print(txt)
    log(txt)
  end

  if not script_data.big_migration then
    script_data.big_migration = true
    script_data.targeted_resources = {}
    script_data.path_requests = {}
    for k, surface in pairs (game.surfaces) do
      script_data.targeted_resources[surface.index] = {}
    end

    for k, bucket in pairs (script_data.depots) do
      for unit_number, depot in pairs (bucket) do
        depot.path_requests = {}
      end
    end
    script_data.request_queue = {}
  end

  if not script_data.reset_corpses then
    script_data.reset_corpses = true
    for k, bucket in pairs (script_data.depots) do
      for unit_number, depot in pairs (bucket) do
        depot.unit_number = unit_number
        if not depot.entity.valid then
          depot:handle_depot_deletion()
          bucket[unit_number] = nil
        else
          depot:remove_energy_interface()
          depot:add_energy_interface()
          depot:remove_corpse()
          depot:add_corpse()
          depot:remove_spawn_corpse()
          depot:add_spawn_corpse()
          depot:clear_wall()
          depot:add_wall()
          depot:check_for_rescan()
        end
      end
    end
  end

  for k, bucket in pairs (script_data.depots) do
    --Idk, things can happen, let the depots rescan if they want.
    for unit_number, depot in pairs (bucket) do
      if depot.entity.valid then
        depot:check_for_rescan()
      else
        depot:handle_depot_deletion()
        bucket[unit_number] = nil
      end
    end
  end

  if not script_data.migrate_drones then
    script_data.migrate_drones = true
    for k, bucket in pairs (script_data.depots) do
      for unit_number, depot in pairs (bucket) do
        for drone_unit_number, drone in pairs (depot.drones) do
          depot.drones[drone_unit_number] = true
        end
      end
    end
  end

  if not script_data.clear_wall_migration then
    script_data.clear_wall_migration = true
    for k, bucket in pairs (script_data.depots) do
      for unit_number, depot in pairs (bucket) do
        depot.unit_number = unit_number
        if depot.entity.valid then
          depot:clear_wall()
          depot:add_wall()
        end
      end
    end
  end

end


local total_reload = function()
  script_data.depots = {}
  update_configuration(true)
end


local lib = {}

lib.events =
{
  -- Depot creation
  [defines.events.on_built_entity] = on_built_entity,
  [defines.events.on_robot_built_entity] = on_built_entity,
  [defines.events.script_raised_revive] = on_built_entity,
  [defines.events.script_raised_built] = on_built_entity,
  [defines.events.on_entity_cloned] = on_built_entity,

  -- Depot deletion
  [defines.events.on_player_mined_entity] = on_entity_removed,
  [defines.events.on_robot_mined_entity] = on_entity_removed,
  [defines.events.on_entity_died] = on_entity_removed,
  [defines.events.script_raised_destroy] = on_entity_removed,

  -- Misc handlers
  [defines.events.on_script_path_request_finished] = on_script_path_request_finished,
  [defines.events.on_gui_opened] = clean_player_inv,

  -- Main
  [defines.events.on_tick] = on_tick
}

lib.on_init = function()
  storage.mining_depot = storage.mining_depot or script_data
end

lib.on_load = function()
  script_data = storage.mining_depot or script_data

  -- -- TODO: get rid of it! Check script.register_metatable works
  -- for k, bucket in pairs (script_data.depots) do
  --   for unit_number, depot in pairs (bucket) do
  --     setmetatable(depot, depot_metatable)
  --   end
  -- end
  -- for path_request_id, depot in pairs (script_data.path_requests) do
  --   setmetatable(depot, depot_metatable)
  -- end

  if remote.interfaces["warptorio"] ~= nil then
    log("MD2R_depot: warptorio2 blacklists")

    -- Blacklist hidden entities
    local to_block = { shared.box_name, shared.proxy_corpse_name, shared.energy_int_name, }
    for _, name in pairs(to_block) do
      remote.call("warptorio", "InsertModTable", "harvester_blacklist", shared.mod_name, name)
      remote.call("warptorio", "InsertModTable",      "warp_blacklist", shared.mod_name, name)
    end
  end
end

lib.on_configuration_changed = update_configuration

lib.add_commands = function()
  commands.add_command(
    "mining-depots-rescan",
    "Forces all mining depots to cancel all orders and refresh their target list",
    reset_all_depots)
  commands.add_command(
    "mining-depots-total-reset",
    "Completely reloads the mod",
    total_reload)
end

-- For remote interface
lib.rescan_all_depots = function()
  rescan_all_depots(true)
end
lib.hide_pots = hide_pots

return lib