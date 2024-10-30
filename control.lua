
local enabled = true
local replace_belts = false
script.on_init(function()
  storage.last_built_belt_direction = {}
  enabled = settings.global["enabled"].value
  replace_belts = settings.global["replace-belts"].value
end)

script.on_load(function()  -- only for testing, because the format of global could change
  enabled = settings.global["enabled"].value
  replace_belts = settings.global["replace-belts"].value
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  storage.last_built_belt_direction = storage.last_built_belt_direction or {}  -- TESTING
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

--- Given a pair of undergrounds, return the direction from first to second. If invalid (not in a line), returns nil
---@param first LuaEntity
---@param second LuaEntity
---@return defines.direction?
local function orient_pair(first, second)
  if first.position.x == second.position.x then
    if first.position.y == second.position.y then  -- same position
      return nil
    elseif first.position.y < second.position.y then
      return defines.direction.south
    else  -- first.position.y > second.position.y
      return defines.direction.north
    end
  elseif first.position.y == second.position.y then
    if first.position.x < second.position.x then
      return defines.direction.east
    else
      return defines.direction.west
    end
  else
    return nil
  end
end

---@param entity LuaEntity
---@param player LuaPlayer
---@param direction defines.direction?
local function replace_with_belt(entity, player, direction)
  -- Note: player.build_from_cursor exists, but I would rather have more custom control
  if not entity or not entity.valid or not player then
    print("script valid error")
    return
  end

  local position = entity.position
  direction = direction or entity.direction
  -- if entity.belt_to_ground_type == "output" then direction = flip_direction[direction] end

  local is_ghost = entity.type == "entity-ghost"
  local item
  if not is_ghost then
    item = entity.name  -- TODO: use entity.prototype.mineable_properties.products rather than entity.name
  else
    item = entity.ghost_name
  end
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
  -- TODO check player build mode. If it is a ghost because the player is out of undergrounds, build a normal belt. But if the player is in ghost mode, build a ghost.
  if is_ghost or player.cursor_stack.count < 1 then
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
  if entity.type == "transport-belt" or (entity.type == "entity-ghost" and entity.ghost_type == "transport-belt") then
    storage.last_built_belt_direction[event.player_index] = entity.direction
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
      local dir = orient_pair(storage.to_replace, entity)
      if dir == nil then
        game.print("undergrounds not aligned")
        return
      end
      replace_with_belt(storage.to_replace, player, storage.last_built_belt_direction[event.player_index])
      replace_with_belt(entity, player, storage.last_built_belt_direction[event.player_index])
      storage.to_replace = nil
    end
  end
end
script.on_event(defines.events.on_built_entity, on_built_entity, {{filter="type", type="underground-belt"}, {filter="type", type="transport-belt"}, {filter="ghost", type="underground-belt"}, {filter="ghost", type="transport-belt"}})


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


