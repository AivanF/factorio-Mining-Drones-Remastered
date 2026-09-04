-- A statistics panel for the mining depot.
--
-- It is a *relative* GUI anchored to the machine window, so Factorio opens and closes it
-- together with the depot's own UI - there is nothing to show or hide by hand. The anchor
-- names the depot prototype, so it never appears on other assembling machines.

local mining_depot = require("script/mining_depot")

local frame_name = "md2r-depot-stats"
local element_prefix = "md2r-stats-"
local refresh_interval = 30

-- Factorio 2.0 renamed several crafting-machine defines; accept either spelling rather
-- than assuming, the way the inventory define caught us out.
local relative_gui_type =
  defines.relative_gui_type.crafter_gui or
  defines.relative_gui_type.assembling_machine_gui

local script_data =
{
  -- player index => depot unit number currently open
  open = {}
}

local rows =
{
  {key = "quality",      caption = "mining-depot-stats-quality",     tooltip = "mining-depot-stats-tooltip-quality"},
  {key = "yield",        caption = "mining-depot-stats-yield",       tooltip = "mining-depot-stats-tooltip-yield"},
  {key = "mined",        caption = "mining-depot-stats-mined",       tooltip = "mining-depot-stats-tooltip-mined"},
  {key = "productivity", caption = "mining-depot-stats-productivity",tooltip = "mining-depot-stats-tooltip-productivity"},
  {key = "delivered",    caption = "mining-depot-stats-delivered",   tooltip = "mining-depot-stats-tooltip-delivered"},
  {key = "pending",      caption = "mining-depot-stats-pending",     tooltip = "mining-depot-stats-tooltip-pending"},
  {key = "drones",       caption = "mining-depot-stats-drones",      tooltip = "mining-depot-stats-tooltip-drones"},
}

local separated = string.format

local group_digits = function(value)
  local text = separated("%d", math.floor(value + 0.5))
  local grouped = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
  return (grouped:gsub("^%s+", ""))
end

-- Yields span 100% down to fractions of a percent, so pick a precision that stays
-- readable at both ends instead of printing 0% for everything interesting.
local as_percent = function(fraction)
  local value = fraction * 100
  if value >= 10 then return separated("%.0f%%", value) end
  if value >= 1 then return separated("%.1f%%", value) end
  if value > 0 then return separated("%.3g%%", value) end
  return "0%"
end

local destroy_frame = function(player)
  local existing = player.gui.relative[frame_name]
  if existing then existing.destroy() end
end

local build_frame = function(player)
  if not relative_gui_type then return end

  destroy_frame(player)

  local frame = player.gui.relative.add
  {
    type = "frame",
    name = frame_name,
    caption = {"mining-depot-stats-title"},
    direction = "vertical",
    anchor =
    {
      gui = relative_gui_type,
      position = defines.relative_gui_position.right,
      name = shared.mining_depot
    }
  }

  local inner = frame.add
  {
    type = "frame",
    name = element_prefix.."inner",
    style = "inside_shallow_frame_with_padding",
    direction = "vertical"
  }

  for _, row in pairs (rows) do
    inner.add{type = "label", name = element_prefix..row.key, tooltip = {row.tooltip}}
  end

  return frame
end

local refresh = function(player, depot)
  local frame = player.gui.relative[frame_name]
  if not frame then
    frame = build_frame(player)
    if not frame then return end
  end

  local inner = frame[element_prefix.."inner"]
  if not inner then return end
  if not (depot and depot.entity and depot.entity.valid) then return end

  local field = function(key) return inner[element_prefix..key] end

  local quality = depot:get_recipe_quality()
  local mined = depot.mined_total or 0
  local carried = depot.output_carry and depot.output_carry[depot.target_resource_name] or 0

  -- With the quality mod off there is exactly one quality, so both rows say nothing: the
  -- yield is always 100% and the name has no locale key outside that mod.
  local quality_enabled = mining_depot.is_quality_enabled()
  field("quality").visible = quality_enabled
  field("yield").visible = quality_enabled

  if quality_enabled then
    local base = mining_depot.get_base_quality()
    field("quality").caption =
      {"mining-depot-stats-quality", (quality or base) and (quality or base).localised_name or ""}
    field("yield").caption =
      {"mining-depot-stats-yield", as_percent(depot:get_quality_multiplier())}
    field("yield").tooltip =
      {"mining-depot-stats-tooltip-yield", as_percent(mining_depot.get_quality_cascade())}
  end

  -- Say so explicitly rather than showing a wall of zeroes that reads like a broken panel.
  field("mined").caption = mined > 0
    and {"mining-depot-stats-mined", group_digits(mined)}
    or {"mining-depot-stats-none"}

  -- At normal quality the delivered figure already *is* the post-productivity one, and the
  -- carry can only ever be a fraction of a single ore, so both rows are noise. Keyed off
  -- the selected quality rather than the values themselves: a value test would make rows
  -- appear and vanish between refreshes as the carry crossed zero.
  local detailed = depot:get_quality_steps() > 0
  field("productivity").visible = detailed
  field("pending").visible = detailed

  field("productivity").caption =
    {"mining-depot-stats-productivity", group_digits(depot.mined_with_productivity or 0)}
  field("delivered").caption =
    {"mining-depot-stats-delivered", group_digits(depot.yielded_total or 0)}
  field("pending").caption = {"mining-depot-stats-pending", separated("%.2f", carried)}
  field("drones").caption =
    {"mining-depot-stats-drones", depot:get_active_drone_count(), depot:get_drone_item_count()}
end

local on_gui_opened = function(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == shared.mining_depot) then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  script_data.open[event.player_index] = entity.unit_number
  refresh(player, mining_depot.get_mining_depot(entity.unit_number))
end

local on_gui_closed = function(event)
  script_data.open[event.player_index] = nil
end

local on_tick = function(event)
  if event.tick % refresh_interval ~= 0 then return end
  if not next(script_data.open) then return end

  for player_index, unit_number in pairs (script_data.open) do
    local player = game.get_player(player_index)
    local depot = mining_depot.get_mining_depot(unit_number)
    if player and player.valid and depot then
      refresh(player, depot)
    else
      script_data.open[player_index] = nil
    end
  end
end

local on_player_removed = function(event)
  script_data.open[event.player_index] = nil
end

local lib = {}

lib.events =
{
  [defines.events.on_gui_opened] = on_gui_opened,
  [defines.events.on_gui_closed] = on_gui_closed,
  [defines.events.on_player_removed] = on_player_removed,
  [defines.events.on_tick] = on_tick,
}

lib.on_init = function()
  storage.depot_gui = storage.depot_gui or script_data
end

lib.on_load = function()
  script_data = storage.depot_gui or script_data
end

lib.on_configuration_changed = function()
  storage.depot_gui = storage.depot_gui or script_data
  script_data = storage.depot_gui
  script_data.open = script_data.open or {}

  -- The layout may have changed with the update, so drop any panel built by an older
  -- version instead of writing into fields that no longer exist.
  for _, player in pairs (game.players) do
    destroy_frame(player)
  end
end

return lib
