
-- local variables for settings, etc
local enabled
local replace_belts
local replace_undergrounds
local filter_type

local function invert_defines(id, defines_)
  for event_, id_ in pairs(defines_) do
    if id == id_ then
      return event_
    end
  end
  return id
end

---@param inv LuaInventory
local function print_inventory(inv)
  local str = ""
  for _, item in pairs(inv.get_contents()) do
    str = str..item.name..":"..item.count..","
  end
  game.print(str)
end

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
---@param cursor {name: string, quality: string, item_stack: LuaItemStack?}? 
---@param player LuaPlayer
---@param direction defines.direction?
local function replace_with_belt(entity, cursor, player, direction)
  if not entity or not entity.valid or not cursor or not player then
    print("script valid error")
    return
  end

  local position = entity.position
  direction = direction or entity.direction
  -- if entity.belt_to_ground_type == "output" then direction = flip_direction[direction] end

  local item
  local is_ghost = entity.type == "entity-ghost"
  if not is_ghost then
    item = entity.name  -- TODO: use entity.prototype.mineable_properties.products rather than entity.name
  else
    item = entity.ghost_name
  end
  local quality = entity.quality.name
  -- game.print(quality, {skip=defines.print_skip.never})
  -- game.print(cursor.quality, {skip=defines.print_skip.never})

  if item == cursor.name and quality == cursor.quality then  -- same item, no need to destroy/create, just rotate
    entity.direction = direction
    return
  end

  -- game.print(player.get_main_inventory().get_item_count({name=item, quality=quality}), {skip=defines.print_skip.never})

  -- place the regular belt
  local params = {
    name = cursor.name,  -- TODO: use place result rather than item.name
    quality = cursor.quality,
    player = player,
    force = player.force,
    position = position,
    direction = direction,
    create_build_effect_smoke = true,
    fast_replace = true,  -- preserves items?
  }
  -- If no items, remote view, or forced build, mark for deconstruction and build ghost
  -- Otherwise, mine the item (destroy then refund) and place the belt
  -- Note: player.build_from_cursor exists, but I would rather have more custom control. Also, calling build_from_cursor inside on_pre_build results in an infinite recursive call
  if cursor.item_stack == nil or storage.last_built_mode[player.index] ~= defines.build_mode.normal then
    entity.order_deconstruction(player.force, player)
    params.inner_name = params.name
    params.name = "entity-ghost"
  else
    entity.destroy{script_raised_destroy=false}
    if not is_ghost then
      player.get_main_inventory().insert({name=item, count=1, quality=quality})  -- refund the replaced entity
    end
    cursor.item_stack.count = cursor.item_stack.count - 1  -- place an item from the cursor
  end
  player.surface.create_entity(params)
  player.surface.play_sound{path="utility/build_small",position=position}

end

---@param player LuaPlayer
---@return {name: string, quality: string, item_stack: LuaItemStack?}? cursor
local function get_cursor(player)
  local cursor = nil
  if player.cursor_stack and player.cursor_stack.valid_for_read then
    cursor = {
      name = player.cursor_stack.name,
      quality = player.cursor_stack.quality.name,
      item_stack = player.cursor_stack,
    }
  elseif player.cursor_ghost then
    cursor = {
      name = player.cursor_ghost.name,
      quality = player.cursor_ghost.quality,
    }
    if type(cursor.name) ~= "string" then
      cursor.name = cursor.name.name
    end
    if not cursor.quality then
      cursor.quality = "normal"
    elseif type(cursor.quality) ~= "string" then
      cursor.quality = cursor.quality.name
    end
  end
  -- game.print(serpent.block(cursor), {skip=defines.print_skip.never})
  return cursor
end

---@param event EventData.on_pre_build
local function on_pre_build(event)
  -- game.print(invert_defines(event.name, defines.events), {skip=defines.print_skip.never})
  -- game.print(invert_defines(event.build_mode, defines.build_mode), {skip=defines.print_skip.never})
  storage.last_built_mode[event.player_index] = event.build_mode
  storage.last_built_direction[event.player_index] = event.direction
  storage.to_replace[event.player_index] = nil
  if not enabled or not (replace_belts or replace_undergrounds) then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local cursor = get_cursor(player)
  if not cursor or cursor.name:sub(-14) ~= "transport-belt" then return end  -- :sub(-14)
  local entities = player.surface.find_entities_filtered{position=event.position,type=filter_type}
  if #entities == 1 then
    replace_with_belt(entities[1], cursor, player, event.direction)
  end
end
-- script.on_event(defines.events.on_pre_build, on_pre_build)

---@param event EventData.on_built_entity
local function on_built_entity(event)
  if not enabled then return end
  local entity = event.entity
  if not entity or not event.entity.valid then
    -- game.print("invalid entity")
    return
  end
  -- if entity.type == "transport-belt" or (entity.type == "entity-ghost" and entity.ghost_type == "transport-belt") then
  --   assert(entity.direction == storage.last_built_direction[event.player_index])
  --   storage.last_built_direction[event.player_index] = entity.direction
  --   return
  -- end
  -- game.print(event.tick, {skip=defines.print_skip.never})
  -- game.print(invert_defines(event.name, defines.events), {skip=defines.print_skip.never})
  -- game.print(entity.name, {skip=defines.print_skip.never})
  -- game.print(entity.position, {skip=defines.print_skip.never})
  -- game.print(entity.belt_to_ground_type, {skip=defines.print_skip.never})
  -- print_inventory(event.consumed_items)

  local player = game.get_player(event.player_index)
  if not player then return end
  local cursor = get_cursor(player)
  if not cursor or cursor.name:sub(-14) ~= "transport-belt" then return end  -- :sub(-14)

  -- game.print(player.get_main_inventory().get_item_count({name=entity.name, quality=entity.quality}), {skip=defines.print_skip.never})

  -- replace_underground(entity, player)
  if storage.to_replace[event.player_index] == nil then
    -- store the first underground
    storage.to_replace[event.player_index] = entity
  else
    -- process both undergrounds together
    replace_with_belt(storage.to_replace[event.player_index], cursor, player, storage.last_built_direction[event.player_index])
    replace_with_belt(entity, cursor, player, storage.last_built_direction[event.player_index])
    storage.to_replace[event.player_index] = nil
  end
end
-- script.on_event(defines.events.on_built_entity, on_built_entity, {{filter="type", type="underground-belt"}, {filter="ghost", type="underground-belt"}})


-- ---@param event EventData.on_pre_player_mined_item
-- local function on_pre_player_mined_item(event)
--   game.print(invert_defines(event.name, defines.events))
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
--   game.print(invert_defines(event.name, defines.events))
--   game.print(event.entity.name)
--   print_inventory(event.buffer)
-- end
-- script.on_event(defines.events.on_player_mined_entity, on_player_mined_entity, {{filter="type", type="underground-belt"}, {filter="type", type="transport-belt"}})


-- ---@param event EventData.on_player_mined_item
-- local function on_player_mined_item(event)
--   game.print(invert_defines(event.name, defines.events))
--   game.print(event.item_stack.name..":"..event.item_stack.count)
-- end
-- script.on_event(defines.events.on_player_mined_item, on_player_mined_item)


local function reload_cache()
  -- read from settings
  enabled = settings.global["enabled"].value
  replace_belts = settings.global["replace-belts"].value
  replace_undergrounds = settings.global["replace-undergrounds"].value
  -- update filter for on_pre_build
  filter_type = {}
  if replace_belts then table.insert(filter_type, "transport-belt") end
  if replace_undergrounds then table.insert(filter_type, "underground-belt") end
  -- register events
  if not enabled then
    script.on_event(defines.events.on_built_entity, nil)
    script.on_event(defines.events.on_pre_build, nil)
  else
    script.on_event(defines.events.on_built_entity, on_built_entity, {{filter="type", type="underground-belt"}, {filter="ghost", type="underground-belt"}})
    script.on_event(defines.events.on_pre_build, on_pre_build)
  end
end

script.on_init(function()
  storage.last_built_direction = {}
  storage.last_built_mode = {}
  storage.to_replace = {}
  reload_cache()
end)

script.on_load(function()
  reload_cache()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  -- storage.last_built_direction = storage.last_built_direction or {}  -- TESTING
  -- storage.last_built_mode = storage.l_built_mode or {}
  -- storage.to_replace = storage.to_replace or {}
  reload_cache()
end)

