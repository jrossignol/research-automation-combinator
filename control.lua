require("util")

require("compatibility.picker-dollies")
require("scripts.research-automation-combinator")
require("scripts.gui")

script.on_load(function()
  register_picker_dollies()
  init_rac_data()
end)

script.on_init(function()
  register_picker_dollies()
  init_rac_data()
end)

--- On tick handler for the research automation combinator.
function on_tick()
  for _, rac in pairs(storage.research_combinators or {}) do
    if rac.entity and rac.entity.valid then
      rac:on_tick()
    end
  end
end

--- Handler for any change to research (finishing, cancelling, reversing).
--- @param event EventData.on_research_finished|EventData.on_research_reversed|EventData.on_research_cancelled
function on_research_change(event)
  for _, rac in pairs(storage.research_combinators or {}) do
    if rac.entity and rac.entity.valid then
      rac:on_research_change(event)
    end
  end
end

--- Handler for any change to the research queue (starting, finishing, cancelling, and moving research).
--- @param event EventData.on_research_finished|EventData.on_research_started|EventData.on_research_cancelled|EventData.on_research_moved
function on_research_queue_change(event)
  for _, rac in pairs(storage.research_combinators or {}) do
    if rac.entity and rac.entity.valid then
      rac:on_research_queue_change(event)
    end
  end
end

--- After selecting an area with a blueprint
--- @param event EventData.on_player_setup_blueprint
function on_player_setup_blueprint(event)
  local player = game.players[event.player_index]
	local blueprint = player.blueprint_to_setup
	if not blueprint.valid_for_read then blueprint = player.cursor_stack end
	if not blueprint or not blueprint.valid_for_read then return end

  --- @type table<uint, LuaEntity>
  local mapping = event.mapping.get()
  for index, entity in pairs(mapping) do
    -- Mark any research automation combinators as dirty (this will force them to be recreated from the combinator data)
    if entity.name == "research-automation-combinator" then
      local rac = ResearchAutomationCombinator:get_from_entity(entity)
      if rac then
        rac:mark_dirty(true)
      end
    end
  end
end


--- Handler for a new research combinator being created.
---@param event EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_space_platform_built_entity|EventData.on_entity_cloned|EventData.script_raised_built|EventData.script_raised_revive|EventData.on_entity_settings_pasted
function on_created_entity(event)
  -- Create and store research combinator details
  local entity = event.entity or event.destination
  ResearchAutomationCombinator:new(entity)
end

--- Handler for a research combinator being removed.
function on_destroyed_entity(event)
  local entity = event.entity

  -- Remove the combinator from storage
  storage.research_combinators[entity.unit_number] = nil
end

-- Creation events
script.on_event(defines.events.on_tick, on_tick)
for _, event in ipairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  defines.events.on_entity_cloned,
}) do
  script.on_event(event, on_created_entity, {{filter = "name", name = "research-automation-combinator"}})
end
script.on_event(defines.events.on_entity_settings_pasted, function(event)
  if (event.destination.name == "research-automation-combinator") then
    -- If the source event was a decider combinator, this will restore the combinator data from the object for us.
    on_created_entity(event)
  end
end)

for _, event in ipairs({
  defines.events.on_entity_died,
  defines.events.on_pre_player_mined_item,
  defines.events.on_space_platform_pre_mined,
  defines.events.on_robot_pre_mined,
  defines.events.script_raised_destroy,
}) do
  script.on_event(event, on_destroyed_entity, {
    {filter = "name", name = "research-automation-combinator"},
  })
end

script.on_event(defines.events.on_player_setup_blueprint, on_player_setup_blueprint)


-- We have two handlers for research events, one for the research queue and one for the research itself.  Some events will trigger both.
for _, event in ipairs({
  defines.events.on_research_finished,
  defines.events.on_research_cancelled,
}) do
  script.on_event(event, function(event)
    on_research_change(event)
    on_research_queue_change(event)
  end)
end

script.on_event(defines.events.on_research_reversed, on_research_change)
script.on_event(defines.events.on_research_started, on_research_queue_change)
script.on_event(defines.events.on_research_moved, on_research_queue_change)