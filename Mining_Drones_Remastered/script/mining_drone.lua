local mining_technologies = require("script/mining_technologies")
local default_bot_name = shared.drone_name
local mining_interval = shared.mining_interval
local mining_damage = shared.mining_damage

local max = math.max
local min = math.min
local random = math.random
local sin = math.sin
local cos = math.cos
local ceil = math.ceil
local floor= math.floor
local pi = math.pi

local perfmult = settings.startup["af-mining-drones-perf-mult"].value

local script_data =
{
  drones = {},
  big_migration = true,
  entities = {},
}

local drone_path_flags = {prefer_straight_paths = false, use_cache = false}

local lib = {}

lib.get_mining_depot = function(self)
  -- Gets overridden by mining_depot.lua
  error("Trying to use get_mining_depot before set up")
end

lib.metatable = {__index = lib}

local add_drone = function(drone)
  script_data.drones[drone.unit_number] = drone
end

local remove_drone = function(drone)
  script_data.drones[drone.unit_number] = nil
end

local get_drone = function(unit_number)
  local drone = script_data.drones[unit_number]

  if not drone then return end

  if not drone.entity.valid then
    drone:clear_things()
    return
  end

  return drone
end


local get_drone_mining_speed = function()
  -- TODO: check entity type and it's speed: some ores require higher mining time
  return 0.5 * perfmult
end

local mining_times = {}
local get_mining_time = function(entity)

  local name = entity.name
  local time = mining_times[name]
  if time then return time end

  time = entity.prototype.mineable_properties.mining_time
  mining_times[name] = time
  return time

end

local proxy_names = {}
local get_proxy_name = function(entity)

  local entity_name = entity.name
  local proxy_name = proxy_names[entity_name]
  if proxy_name then
    return proxy_name
  end

  if game.entity_prototypes[shared.attack_proxy_name..entity.name] then
    proxy_name = shared.attack_proxy_name..entity.name
  else
    local size = min(ceil((max(entity.get_radius() - 0.1, 0.25)) * 2), 10)
    proxy_name = shared.attack_proxy_name..size
  end

  proxy_names[entity_name] = proxy_name

  return proxy_name

end

function lib:get_mining_speed()
  return get_drone_mining_speed() * (1 + mining_technologies.get_mining_speed_bonus(self.force_index))
end

function lib:make_attack_proxy()

  --Health is set so it will take just enough mining_damage at exactly the right time
  local entity = self.mining_target
  local count = self.mining_count
  local mining_time = get_mining_time(entity) * count

  local number_of_ticks = (mining_time / self:get_mining_speed()) * 60
  local number_of_hits = ceil(number_of_ticks / mining_interval)
  local position = entity.position
  local radius = entity.get_radius() * 0.707
  if radius > 0.5 then
    local r2 = random() * (radius ^ 2)
    local angle = random() * pi * 2
    position.x = position.x + (r2^0.5) * cos(angle)
    position.y = position.y + (r2^0.5) * sin(angle)
  end
  local proxy = entity.surface.create_entity{name = get_proxy_name(entity), position = position, force = "neutral"}
  proxy.health = number_of_hits * mining_damage
  proxy.active = false

  self.attack_proxy = proxy
end

local states =
{
  mining_entity = 1,
  return_to_depot = 2
}

lib.new = function(entity, depot)

  local drone =
  {
    entity = entity,
    unit_number = entity.unit_number,
    force_index = entity.force.index,
    depot = depot.entity.unit_number,
    inventory = game.create_inventory(100)
  }
  entity.ai_settings.path_resolution_modifier = 0
  setmetatable(drone, lib.metatable)

  add_drone(drone)
  return drone
end

function lib:get_depot()
  if not self.depot then return end
  return lib.get_mining_depot(self.depot)
end


function lib:process_mining()

  local target = self.mining_target
  if not (target and target.valid) then
    -- Cancel command or something
    return self:return_to_depot()
  end

  local depot = self:get_depot()
  if not depot then
    self:cancel_drone()
    return
  end

  if target.type ~= "resource" then error("HUEHRUEH") end

  local pollution_count = 0
  local mine_opts = {inventory = self.inventory}
  local mine = target.mine
  for k = 1, self.mining_count do
    if target.valid then
      mine(mine_opts)
      pollution_count = pollution_count + 1
    else
      self:clear_mining_target()
      break
    end
  end
  self.mining_count = nil
  local pollution_per_mine = settings.global["af-mining-drones-pollute-rate"].value
  local pollution_value = pollution_count * pollution_per_mine

  local drone = self.entity
  drone.surface.pollute(drone.position, pollution_value)
  game.pollution_statistics.on_flow(default_bot_name, pollution_value)

  self:return_to_depot()
end


function lib:request_order()
  self:get_depot():handle_order_request(self)
end


local distance = util.distance
function lib:distance(position)
  return distance(self.entity.position, position)
end

function lib:process_return_to_depot()

  local depot = self:get_depot()
  if not (depot and depot.entity.valid) then
    self:say("My depot isn't valid!")
    self:cancel_drone()
    -- TODO: kill?
    return
  end

  if self:distance(depot:get_corpse().position) > 5 then
    self:say("return_to_depot: Go!")
    self:return_to_depot()
    return
  end

  local target_inventory = depot:get_output_inventory()
  local productivity_bonus = 1 + mining_technologies.get_productivity_bonus(self.force_index)
  local chance = productivity_bonus % 1
  productivity_bonus = productivity_bonus - chance

  if chance > random() then
    productivity_bonus = productivity_bonus + 1
  end


  local item_flow = self.entity.force.item_production_statistics.on_flow
  for name, count in pairs (self.inventory.get_contents()) do
    local real_count = ceil(count * productivity_bonus)
    target_inventory.insert({name = name, count = real_count})
    item_flow(name, real_count)
  end
  depot:on_resource_given()

  self.inventory.clear()

  self:request_order()
  self:say("return_to_depot: done...")
end


function lib:process_failed_command()
  self.fail_count = (self.fail_count or 0) + 1

  if self.fail_count == 2 then self.entity.ai_settings.path_resolution_modifier = 1 end
  if self.fail_count == 4 then self.entity.ai_settings.path_resolution_modifier = 2 end

  if self.state == states.mining_entity then

    self:clear_attack_proxy()

    if self.mining_target.valid and self.fail_count <= 5 then
      return self:mine_entity(self.mining_target, self.mining_count)
    end

    self:say("I can't mine that entity!")
    self:clear_mining_target()
    self:return_to_depot()
    return
  end

  if self.state == states.return_to_depot then
    if self.fail_count <= 5 then
      return self:wait(random(25, 45))
    end
    self:say("I can't return to my depot!")
    self:cancel_drone()
    return
  end
end


function lib:wait(ticks)
  self.entity.set_command
  {
    type = defines.command.wander,
    ticks_to_wait = ticks,
    distraction = defines.distraction.none
  }
  self:say("wait, wander?!")
end

function lib:process_distracted_command()
  if self.state == states.mining_entity then
    -- We were in the middle of attacking the proxy, go mine it.
    self:attack_mining_proxy()
    return
  end

  if self.state == states.return_to_depot then
    -- We were walking home, lets walk home again.
    self:return_to_depot()
    return
  end

end

function lib:update(event)
  if not self.entity.valid then return end

  if event.result ~= defines.behavior_result.success then
    self:say("drone.update: failed")
    self:process_failed_command()
    return
  end

  if event.was_distracted then
    self:say("drone.update: distracted")
    self:process_distracted_command()
    return
  end

  if self.state == states.mining_entity then
    self:say("drone.update: mining")
    self:process_mining()
    return
  end

  if self.state == states.return_to_depot then
    self:say("drone.update: return")
    self:process_return_to_depot()
    return
  end
end

function lib:say(text)
  -- For debugging
  -- log("MD2R_drone_say: "..text)
  -- game.print(text)
  -- if not (self.entity and self.entity.valid) then return end
  -- self.entity.surface.create_entity{name="flying-text", position=self.entity.position, text=text}
end

function lib:attack_mining_proxy()

  local depot = self:get_depot()

  if not (depot and depot.entity.valid) then
    self:cancel_drone()
    return
  end

  local attack_proxy = self.attack_proxy
  if not (attack_proxy and attack_proxy.valid) then
    --dunno
    self:return_to_depot()
    return
  end

  local commands =
  {
    {
      type = defines.command.go_to_location,
      destination_entity = depot:get_corpse(),
      radius = 0.25,
      distraction = defines.distraction.none,
      pathfind_flags = drone_path_flags
    },
    {
      type = defines.command.go_to_location,
      destination_entity = attack_proxy,
      distraction = defines.distraction.none,
      pathfind_flags = drone_path_flags
    },
    {
      type = defines.command.attack,
      target = attack_proxy,
      distraction = defines.distraction.none
    }
  }

  self.entity.set_command
  {
    type = defines.command.compound,
    structure_type = defines.compound_command.return_last,
    distraction = defines.distraction.none,
    commands = commands
  }
  self:say("attack_mining_proxy")
end

function lib:mine_entity(entity, count)

  self.mining_count = count or 1
  self.mining_target = entity
  self.state = states.mining_entity

  self:make_attack_proxy()
  self:attack_mining_proxy()

end

function lib:clear_things()
  self:clear_mining_target()
  self:clear_attack_proxy()
  self:clear_depot()
  remove_drone(self)
end

function lib:cancel_drone()
  self:clear_things()
  self.entity.force = "neutral"
  self.entity.die()
end


function lib:return_to_depot()
  self.state = states.return_to_depot
  self:clear_attack_proxy()

  local depot = self:get_depot()

  if not (depot and depot.entity.valid) then
    self:cancel_drone()
    return
  end
  self:say("Returning to depot: "..depot.entity.unit_number)

  local commands =
  {
    {
      type = defines.command.go_to_location,
      destination_entity = depot:get_corpse(),
      radius = 0.25,
      distraction = defines.distraction.none,
      pathfind_flags = drone_path_flags
    },
    {
      type = defines.command.go_to_location,
      destination_entity = depot:get_spawn_corpse(),
      radius = 1.5,
      distraction = defines.distraction.none,
      pathfind_flags = drone_path_flags
    }
  }

  self.entity.set_command
  {
    type = defines.command.compound,
    structure_type = defines.compound_command.return_last,
    distraction = defines.distraction.none,
    commands = commands
  }
end


function lib:go_to_position(position, radius)
  self.entity.set_command
  {
    type = defines.command.go_to_location,
    destination = position,
    radius = radius or 1,
    distraction = defines.distraction.none,
    pathfind_flags = drone_path_flags,
  }
  self:say("go_to_position: "..serpent.block(position))
end


function lib:go_to_entity(entity, radius)
  self.entity.set_command
  {
    type = defines.command.go_to_location,
    destination_entity = entity,
    radius = radius or 1,
    distraction = defines.distraction.none,
    pathfind_flags = drone_path_flags
  }
  self:say("go_to_entity: "..serpent.block(entity.position))
end


function lib:clear_attack_proxy()
  local destroyed = self.attack_proxy and self.attack_proxy.valid and self.attack_proxy.destroy()
  self.attack_proxy = nil
end


function lib:clear_mining_target()
  if self.mining_target and self.mining_target.valid then
    if self:get_depot() then
      self:get_depot():add_mining_target(self.mining_target)
    end
  end
  self.mining_target = nil
end


function lib:clear_depot()
  if not self:get_depot() then return end
  self:get_depot().drones[self.unit_number] = nil
  self.depot = nil
end


function lib:handle_drone_deletion()
  if not self.entity.valid then error("Hi, i am not handled.") end

  if self:get_depot() then
    self:get_depot():remove_drone(self, true)
  end

  self:clear_things()
end


function lib:is_returning_to_depot()
  return self.state == states.return_to_depot
end


local on_ai_command_completed = function(event)
  local drone = get_drone(event.unit_number)
  if not drone then return end
  drone:update(event)
end


local on_entity_removed = function(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end

  local unit_number = entity.unit_number
  if not unit_number then return end

  local drone = get_drone(unit_number)
  if not drone then return end

  if event.force and event.force.valid then
    event.force.kill_count_statistics.on_flow(default_bot_name, 1)
  end

  entity.force.kill_count_statistics.on_flow(default_bot_name, -1)

  drone:handle_drone_deletion()
end


local validate_proxy_orders = function()
  --local count = 0
  for unit_number, drone in pairs (script_data.drones) do
    if drone.entity.valid then
      if drone.state == states.mining_entity then
        if not drone.attack_proxy.valid then
          drone:return_to_depot()
          ---count = count + 1
        end
      end
    else
      drone:clear_things()
    end
  end
  --game.print(count)
end


local on_unit_added_to_group = function(event)
  --game.print("ON GROUP EVENT")
  local entity = event.unit
  if not (entity and entity.valid) then return end

  local drone = get_drone(entity.unit_number)
  if not drone then return end

  local group = event.group
  if not (group and group.valid) then return end
  --game.print("HOT "..group.group_number)
  group.destroy()

  drone:process_distracted_command()
end


local cache_global_data = function()
  script_data.entities = {}
  local units = game.get_filtered_entity_prototypes{{filter="type", type="unit"}}
  for name, proto in pairs(units) do
    if name:find(default_bot_name, 1, true) then
      script_data.entities[name] = name
    end
  end
  -- log("MD2R_cache_global_data: "..serpent.block(script_data.entities))
end



lib.events =
{
  --[defines.events.on_built_entity] = on_built_entity,
  --[defines.events.on_robot_built_entity] = on_built_entity,
  --[defines.events.script_raised_revive] = on_built_entity,
  --[defines.events.script_raised_built] = on_built_entity,

  [defines.events.on_player_mined_entity] = on_entity_removed,
  [defines.events.on_robot_mined_entity] = on_entity_removed,

  [defines.events.on_entity_died] = on_entity_removed,
  [defines.events.script_raised_destroy] = on_entity_removed,

  [defines.events.on_ai_command_completed] = on_ai_command_completed,

  [defines.events.on_unit_added_to_group] = on_unit_added_to_group,
}

lib.on_load = function()
  script_data = global.mining_drone or script_data
  for unit_number, drone in pairs (script_data.drones) do
    setmetatable(drone, lib.metatable)
  end

  if remote.interfaces["warptorio"] ~= nil then
    log("MD2R_drones: warptorio2 setting remote interfaces")

    -- Blacklist drones from being teleported
    for _, name in pairs(script_data.entities) do
      remote.call("warptorio", "InsertModTable", "harvester_blacklist", shared.mod_name, name)
      remote.call("warptorio", "InsertModTable",      "warp_blacklist", shared.mod_name, name)
    end

    -- Subscribe to teleport events
    local eventdefs = remote.call("warptorio", "get_events")
    script.on_event(eventdefs["on_warp"], function()
      -- game.print("MD2R_warptorio2: on_warp")
      -- log("MD2R_warptorio2: on_warp")
    end)
    script.on_event(eventdefs["harvester_recall"], function()
      -- game.print("MD2R_warptorio2: harvester_recall")
      -- log("MD2R_warptorio2: harvester_recall")
    end)
    script.on_event(eventdefs["harvester_deploy"], function()
      -- game.print("MD2R_warptorio2: harvester_deploy")
      -- log("MD2R_warptorio2: harvester_deploy")
    end)
  end
end

lib.on_init = function()
  global.mining_drone = global.mining_drone or script_data
  game.map_settings.path_finder.use_path_cache = false
  cache_global_data()
end

lib.on_configuration_changed = function()
  if not script_data.big_migration then
    script_data.big_migration = true
    for unit_number, drone in pairs (script_data.drones) do
      script_data.drones[unit_number] = nil
      if drone.entity.valid then
        drone.entity.destroy()
      end
      if drone.attack_proxy and drone.attack_proxy.valid then
        drone.attack_proxy.destroy()
      end
    end
    script_data.drones = {}
  end

  validate_proxy_orders()
  cache_global_data()
end

lib.get_drone = get_drone

lib.get_drone_count = function()
  return table_size(script_data.drones)
end

return lib