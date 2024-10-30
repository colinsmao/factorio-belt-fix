
local enabled = true
local replace_belts = false
script.on_init(function()
  enabled = settings.global["enabled"].value
  replace_belts = settings.global["replace-belts"].value
end)

script.on_load(function()  -- only for testing, because the format of global could change
  enabled = settings.global["enabled"].value
  replace_belts = settings.global["replace-belts"].value
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  enabled = settings.global["enabled"].value
  replace_belts = settings.global["replace-belts"].value
end)

local invert_event = {}
for event, id in pairs(defines.events) do
  invert_event[id] = event
end

---@param inv LuaInventory
local function print_inventory(inv)
  str = ""
  for _, item in pairs(inv.get_contents()) do
    str = str..item.name..":"..item.count..","
  end
  game.print(str)
end

-- ---@param event EventData.on_pre_build
-- local function on_pre_build(event)
--   game.print(invert_event[event.name])
-- end
-- script.on_event(defines.events.on_built_entity, on_pre_build)

local flip_direction = {
  [defines.direction.north]=defines.direction.south,
  [defines.direction.south]=defines.direction.north,
  [defines.direction.east]=defines.direction.west,
  [defines.direction.west]=defines.direction.east,
}

---@param entity LuaEntity
---@param player LuaPlayer
local function replace_underground(entity, player)
  -- Note: player.build_from_cursor exists, but I would rather have more custom control
  if not entity or not entity.valid or not player then
    print("script valid error")
    return
  end

  local position = entity.position
  local direction = entity.direction
  -- if entity.belt_to_ground_type == "output" then direction = flip_direction[direction] end

  local item = entity.name  -- TODO: use entity.prototype.mineable_properties.products rather than entity.name
  player.get_main_inventory().insert({name=item, count=1})  -- refund the underground belt
  entity.destroy{script_raised_destroy=false}

  -- place the regular belt
  params = {
    name = player.cursor_stack.name,  -- TODO: use place result rather than item.name
    quality = player.cursor_stack.quality,
    player = player,
    force = player.force,
    position = position,
    direction = direction,
  }
  if player.cursor_stack.count < 1 then
    params.inner_name = params.name
    params.name = "entity-ghost"
  else
    player.cursor_stack.count = player.cursor_stack.count - 1
  end
  player.surface.create_entity(params)

end

---@param event EventData.on_built_entity
local function on_built_entity(event)
  if not enabled then return end
  local entity = event.entity
  if not entity or not event.entity.valid then
    game.print("invalid entity")
    return
  end
  game.print(event.tick, {skip=defines.print_skip.never})
  game.print(entity.name, {skip=defines.print_skip.never})
  game.print(entity.position, {skip=defines.print_skip.never})
  game.print(entity.belt_to_ground_type, {skip=defines.print_skip.never})
  -- print_inventory(event.consumed_items)
  local player = game.get_player(event.player_index)
  -- game.print(player.cursor_stack.type)
  if player and player.cursor_stack and player.cursor_stack.name == "transport-belt" then  -- :sub(-14)
    -- replace_underground(entity, player)
    -- player.build_from_cursor{position=entity.position}
    if storage.to_replace == nil then
      -- store the first underground
      storage.to_replace = entity
    else
      -- process both undergrounds together
      replace_underground(storage.to_replace, player)
      replace_underground(entity, player)
      storage.to_replace = nil
    end
  end
end
script.on_event(defines.events.on_built_entity, on_built_entity, {{filter="type", type="underground-belt"}})


-- ---@param event EventData.on_pre_player_mined_item
-- local function on_pre_player_mined_item(event)
--   game.print(invert_event[event.name])
--   game.print(event.entity.name)
-- end
-- script.on_event(defines.events.on_pre_player_mined_item, on_pre_player_mined_item, {{filter="type", type="underground-belt"}, {filter="type", type="transport-belt"}})


-- ---@param event EventData.on_player_mined_entity
-- local function on_player_mined_entity(event)
--   local entity
--   if event.entity and event.entity.valid then
--     entity = event.entity
--   end
--   if not entity then
--     game.print("invalid entity")
--     return
--   end
--   game.print(invert_event[event.name])
--   game.print(event.entity.name)
--   print_inventory(event.buffer)
-- end
-- script.on_event(defines.events.on_player_mined_entity, on_player_mined_entity, {{filter="type", type="underground-belt"}, {filter="type", type="transport-belt"}})


-- ---@param event EventData.on_player_mined_item
-- local function on_player_mined_item(event)
--   game.print(invert_event[event.name])
--   game.print(event.item_stack.name..":"..event.item_stack.count)
-- end
-- script.on_event(defines.events.on_player_mined_item, on_player_mined_item)


