require("scripts.research-automation-combinator")

local COMPARATOR_LIST = { ">", "<", "=", "≥", "≤", "≠" }
local COMPARATOR_LIST_REVERSE = {
  [">"] = 1,
  ["<"] = 2,
  ["="] = 3,
  ["≥"] = 4,
  ["≤"] = 5,
  ["≠"] = 6,
}

--- @param player LuaPlayer
--- @param entity LuaEntity
function create_gui(player, entity)
  -- Close existing GUI
  destroy_gui()

  local main = player.gui.screen.add{
    type = "frame",
    name = "research-automation-combinator-gui",
    direction = "vertical",
    tags = {
      entity=entity.unit_number,
    },
  }
  main.auto_center = true

  local titlebar = main.add{
    type="flow",
    name="titlebar",
  }
  titlebar.drag_target = main

  titlebar.add{
    type="label",
    style="frame_title",
    caption={"entity-name.research-automation-combinator"},
    ignored_by_interaction=true,
  }
  local drag_handle = titlebar.add{
    type="empty-widget",
    style="draggable_space_header",
    ignored_by_interaction=true,
  }
  drag_handle.style.horizontally_stretchable = true
  drag_handle.style.minimal_width = 16
  drag_handle.style.minimal_height = 24

  titlebar.add{
    type = "sprite-button",
    name = "rac-close",
    style = "frame_action_button",
    sprite = "utility/close",
    tooltip = {"gui.close-instruction"},
    tags = { rac=true },
  }

  local content = main.add{
    type="frame",
    name="content",
    direction="vertical",
    style="entity_frame",
  }

  local h = content.add{
    type="flow",
    name="h",
    direction="horizontal",
    style="inset_frame_container_horizontal_flow",
  }

  local research_input_mode = h.add{
    type="frame",
    name="research_input_mode",
    style="inside_shallow_frame",
    direction="vertical",
  }

  research_input_mode.add{
    type="frame",
    style="rac_subheader_frame",
  }.add{
    type="label",
    style="subheader_caption_label",
    caption={"rac-input-label"},
  }
  local f = research_input_mode.add{
    type="frame",
    name="f",
    direction="vertical",
    style="inside_shallow_frame_with_padding_and_vertical_spacing",
  }

  f.add{
    type="checkbox",
    name="enabled_check",
    style="checkbox",
    caption={"gui-control-behavior-modes.enable-disable"},
    tooltip = {"gui-control-behavior-modes.enable-disable-description"},
    tags = { rac=true },
    state = false,
  }

  local hh = f.add{
    type="flow",
    direction="horizontal",
    name="h",
    style="rac_hflow_center",
    enabled=false,
  }
  hh.add{
    type="choose-elem-button",
    name="enabled_lhs",
    style="slot_button_in_shallow_frame",
    elem_type = "signal",
    tags = { rac=true },
  }

  hh.add{
    type="drop-down",
    name="enabled_condition",
    style="circuit_condition_comparator_dropdown",
    items = COMPARATOR_LIST,
    tags = { rac=true },
  }

  hh.add{
    type="choose-elem-button",
    name="enabled_rhs",
    style="slot_button_in_shallow_frame",
    elem_type = "signal",
    tags = { rac=true },
  }

  hh.add{
    type="label",
    style="bold_label",
    caption={"", " ", {"or"}, " "},
  }

  hh.add{
    type="textfield",
    name="enabled_rhs_const",
    style="short_number_textfield",
    numeric = true,
    allow_negative = true,
    tags = { rac=true },
  }

  f.add{
    type="line",
    style="inside_shallow_frame_with_padding_line",
  }


  f.add{
    type="checkbox",
    name="research_mode_check",
    style="checkbox",
    caption={"rac-research-mode"},
    tooltip = {"rac-research-mode-description"},
    tags = { rac=true },
    state = false,
  }
  f.add{
    type="radiobutton",
    name="queue_tech_replace",
    caption={"rac-queue-tech-replace"},
    tooltip = {"rac-queue-tech-replace-description"},
    state=false,
    tags={rac=true, radiobutton_group="queue_tech"},
  }
  f.add{
    type="radiobutton",
    name="queue_tech_front",
    caption={"rac-queue-tech-front"},
    tooltip = {"rac-queue-tech-front-description"},
    state=false,
    tags={rac=true, radiobutton_group="queue_tech"},
  }
  f.add{
    type="radiobutton",
    name="queue_tech_back",
    caption={"rac-queue-tech-back"},
    tooltip = {"rac-queue-tech-back-description"},
    state=false,
    tags={rac=true, radiobutton_group="queue_tech"},
  }

  research_input_mode.add{
    type="frame",
    style="rac_subheader_frame",
  }.add{
    type="label",
    style="subheader_caption_label",
    caption={"rac-input-output-label"},
  }

  local f2 = research_input_mode.add{
    type="frame",
    name="f2",
    direction="vertical",
    style="inside_shallow_frame_with_padding_and_vertical_spacing",
  }

  f2.add{
    type="label",
    caption={"rac-io-mode-label"},
    style="bold_label",
  }

  f2.add{
    type="radiobutton",
    name="io_mode_value",
    caption={"rac-io-mode-input-value"},
    tooltip = {"rac-io-mode-input-value-description"},
    state=true,
    tags={rac=true, radiobutton_group="io_mode"},
  }
  f2.add{
    type="radiobutton",
    name="io_mode_context",
    caption={"rac-io-mode-input-context"},
    tooltip = {"rac-io-mode-input-context-description"},
    state=false,
    tags={rac=true, radiobutton_group="io_mode"},
  }

  f2.add{
    type="line",
    style="inside_shallow_frame_with_padding_line",
  }

  f2.add{
    type="label",
    caption={"rac-output-signals"},
    style="bold_label",
  }

  f2.add{
    type="checkbox",
    name="research_get_prereq",
    style="checkbox",
    caption={"rac-research-get-prereq"},
    tooltip = {"rac-research-get-prereq-description"},
    tags = { rac=true },
    state = false,
  }
  f2.add{
    type="checkbox",
    name="research_get_successors",
    style="checkbox",
    caption={"rac-research-get-successors"},
    tooltip = {"rac-research-get-successors-description"},
    tags = { rac=true },
    state = false,
  }
  f2.add{
    type="checkbox",
    name="research_get_recipes",
    style="checkbox",
    caption={"rac-research-get-recipes"},
    tooltip = {"rac-research-get-recipes-description"},
    tags = { rac=true },
    state = false,
  }
  f2.add{
    type="checkbox",
    name="research_get_items",
    style="checkbox",
    caption={"rac-research-get-items"},
    tooltip = {"rac-research-get-items-description"},
    tags = { rac=true },
    state = false,
  }
  f2.add{
    type="checkbox",
    name="research_get_science_packs",
    style="checkbox",
    caption={"rac-research-get-science-packs"},
    tooltip = {"rac-research-get-science-packs-description"},
    tags = { rac=true },
    state = false,
  }

  local research_output_mode = h.add{
    type="frame",
    name="research_output_mode",
    style="inside_shallow_frame",
    direction="vertical",
  }

  research_output_mode.add{
    type="frame",
    style="rac_subheader_frame",
  }.add{
    type="label",
    style="subheader_caption_label",
    caption={"rac-output-label"},
  }
  f = research_output_mode.add{
    type="flow",
    name="f",
    direction="vertical",
  }
  f.style.padding = 12
  f.style.horizontally_stretchable = true

  f.add{
    type="checkbox",
    name="research_current_check",
    style="checkbox",
    caption={"rac-research-current"},
    tooltip = {"rac-research-current-description"},
    tags = { rac=true },
    state = false,
  }
  f.add{
    type="line",
    style="inside_shallow_frame_with_padding_line",
  }
  f.add{
    type="checkbox",
    name="research_current_percent",
    style="checkbox",
    caption={"rac-research-current-percent"},
    tooltip = {"rac-research-current-percent-description"},
    tags = { rac=true },
    state = false,
  }
  hh = f.add{
    type="flow",
    name="h",
    direction="horizontal",
    style="player_input_horizontal_flow",
  }
  hh.style.horizontally_stretchable = true
  hh.add{
    type="label",
    name="signal_percent_label",
    caption={"rac-research-current-percent-label"},
    tooltip = {"rac-research-current-percent-label-description"},
  }
  hh.add{
    type="empty-widget",
    style="rac_horizontal_pusher",
  }
  hh.add{
    type="choose-elem-button",
    name="signal_percent",
    style="slot_button_in_shallow_frame",
    elem_type = "signal",
    tags = { rac=true },
  }
  f.add{
    type="line",
    style="inside_shallow_frame_with_padding_line",
  }
  f.add{
    type="checkbox",
    name="research_current_value",
    style="checkbox",
    caption={"rac-research-current-value"},
    tooltip = {"rac-research-current-value-description"},
    tags = { rac=true },
    state = false,
  }
  hh = f.add{
    type="flow",
    name="h2",
    direction="horizontal",
    style="player_input_horizontal_flow",
  }
  hh.add{
    type="label",
    name="signal_current_label",
    caption={"rac-research-current-current-label"},
    tooltip = {"rac-research-current-current-label-description"},
}
  hh.add{
    type="empty-widget",
    style="rac_horizontal_pusher",
  }
  hh.add{
    type="choose-elem-button",
    name="signal_current",
    style="slot_button_in_shallow_frame",
    elem_type = "signal",
    tags = { rac=true },
  }
  hh = f.add{
    type="flow",
    name="h3",
    direction="horizontal",
    style="player_input_horizontal_flow",
  }
  hh.add{
    type="label",
    name="signal_remaining_label",
    caption={"rac-research-current-remaining-label"},
    tooltip = {"rac-research-current-remaining-label-description"},
}
  hh.add{
    type="empty-widget",
    style="rac_horizontal_pusher",
  }
  hh.add{
    type="choose-elem-button",
    name="signal_remaining",
    style="slot_button_in_shallow_frame",
    elem_type = "signal",
    tags = { rac=true },
  }
  hh = f.add{
    type="flow",
    name="h4",
    direction="horizontal",
    style="player_input_horizontal_flow",
  }
  hh.add{
    type="label",
    name="signal_total_label",
    caption={"rac-research-current-total-label"},
  }
  hh.add{
    type="empty-widget",
    style="rac_horizontal_pusher",
  }
  hh.add{
    type="choose-elem-button",
    name="signal_total",
    style="slot_button_in_shallow_frame",
    elem_type = "signal",
    tags = { rac=true },
  }
  f.add{
    type="line",
    style="inside_shallow_frame_with_padding_line",
  }

  f.add{
    type="checkbox",
    name="research_status_check",
    style="checkbox",
    caption={"rac-research-status"},
    tooltip = {"rac-research-status-description"},
    tags = { rac=true },
    state = false,
  }
  f.add{
    type="radiobutton",
    name="research_status_researched",
    caption={"rac-research-status-researched"},
    tooltip = {"rac-research-status-researched-description"},
    state=false,
    tags={rac=true, radiobutton_group="research_status"},
  }
  f.add{
    type="radiobutton",
    name="research_status_available",
    caption={"rac-research-status-available"},
    tooltip = {"rac-research-status-available-description"},
    state=false,
    tags={rac=true, radiobutton_group="research_status"},
  }
  f.add{
    type="radiobutton",
    name="research_status_unresearched",
    caption={"rac-research-status-unresearched"},
    tooltip = {"rac-research-status-unresearched-description"},
    state=false,
    tags={rac=true, radiobutton_group="research_status"},
  }

  storage.gui = main
  player.opened = main

  update_gui_from_object()
end

function destroy_gui()
  if (storage.gui and storage.gui.valid) then
    storage.gui.destroy()
    storage.gui = nil
  end
end

function update_object_from_gui()
  if not storage.gui or not storage.gui.valid then return end

  -- Get the research combinator from the GUI
  local rac = ResearchAutomationCombinator:get_from_unit_number(tonumber(storage.gui.tags.entity) or 0)
  if not rac then return end

  -- Convert input side values to class values
  local input = storage.gui.content.h.research_input_mode.f
  rac.enabled_state = input.enabled_check.state
  rac.enabled_lhs = input.h.enabled_lhs.elem_value
  rac.enabled_comparator = COMPARATOR_LIST[input.h.enabled_condition.selected_index]
  rac.enabled_rhs = input.h.enabled_rhs.elem_value
  rac.enabled_rhs_const = tonumber(input.h.enabled_rhs_const.text) or 0
  rac.set_research_mode = ((not input.research_mode_check.state) and SET_RESEARCH_MODE.NONE) or
    (input.queue_tech_replace.state and SET_RESEARCH_MODE.REPLACE_QUEUE) or
    (input.queue_tech_front.state and SET_RESEARCH_MODE.ADD_FRONT) or
    (input.queue_tech_back.state and SET_RESEARCH_MODE.ADD_BACK) or
    SET_RESEARCH_MODE.REPLACE_QUEUE

  -- Convert input/output side values to class values
  local io = storage.gui.content.h.research_input_mode.f2
  rac.get_research_prereq = io.research_get_prereq.state
  rac.get_research_successors = io.research_get_successors.state
  rac.get_research_recipes = io.research_get_recipes.state
  rac.get_research_items = io.research_get_items.state
  rac.get_research_science_packs = io.research_get_science_packs.state
  rac.io_mode = io.io_mode_context.state and 1 or 0

  -- Convert output side values to class values
  local output = storage.gui.content.h.research_output_mode.f
  rac.output_current_research = output.research_current_check.state
  rac.output_research_progress_percent = output.research_current_percent.state
  rac.output_research_progress_percent_signal = output.h.signal_percent.elem_value
  rac.output_research_progress_value = output.research_current_value.state
  rac.output_research_progress_value_csignal = output.h2.signal_current.elem_value
  rac.output_research_progress_value_rsignal = output.h3.signal_remaining.elem_value
  rac.output_research_progress_value_tsignal = output.h4.signal_total.elem_value
  rac.output_research_by_status = ((not output.research_status_check.state) and OUTPUT_RESEARCH_BY_STATUS.NONE) or
    (output.research_status_researched.state and OUTPUT_RESEARCH_BY_STATUS.RESEARCHED) or
    (output.research_status_available.state and OUTPUT_RESEARCH_BY_STATUS.AVAILABLE) or
    (output.research_status_unresearched.state and OUTPUT_RESEARCH_BY_STATUS.UNRESEARCHED) or
    OUTPUT_RESEARCH_BY_STATUS.RESEARCHED

  -- Update the combinator with the new values
  rac:update_combinator()

  -- Assume that tick settings have changed
  rac.tick_settings_changed = true
end

function update_gui_from_object()
  if not storage.gui or not storage.gui.valid then return end

  -- Get the research combinator from the GUI
  local rac = ResearchAutomationCombinator:get_from_unit_number(tonumber(storage.gui.tags.entity) or 0)
  if not rac then return end

  -- Enabled states
  storage.gui.content.h.research_input_mode.f.enabled_check.state = rac.enabled_state
  storage.gui.content.h.research_input_mode.f.h.enabled_lhs.enabled = rac.enabled_state
  storage.gui.content.h.research_input_mode.f.h.enabled_condition.enabled = rac.enabled_state
  storage.gui.content.h.research_input_mode.f.h.enabled_rhs.enabled = rac.enabled_state
  storage.gui.content.h.research_input_mode.f.h.enabled_rhs_const.enabled = rac.enabled_state

  -- Enabled details
  storage.gui.content.h.research_input_mode.f.h.enabled_lhs.elem_value = rac.enabled_lhs
  storage.gui.content.h.research_input_mode.f.h.enabled_condition.selected_index = COMPARATOR_LIST_REVERSE[rac.enabled_comparator] or 1
  storage.gui.content.h.research_input_mode.f.h.enabled_rhs.elem_value = rac.enabled_rhs
  storage.gui.content.h.research_input_mode.f.h.enabled_rhs_const.text = tostring(rac.enabled_rhs_const) or ""

  -- Set research states
  local set_research = rac.set_research_mode ~= SET_RESEARCH_MODE.NONE
  storage.gui.content.h.research_input_mode.f.research_mode_check.state = set_research
  storage.gui.content.h.research_input_mode.f.queue_tech_replace.enabled = set_research
  storage.gui.content.h.research_input_mode.f.queue_tech_front.enabled = set_research
  storage.gui.content.h.research_input_mode.f.queue_tech_back.enabled = set_research

  -- Set research details
  if set_research then
    storage.gui.content.h.research_input_mode.f.queue_tech_replace.state = rac.set_research_mode == SET_RESEARCH_MODE.REPLACE_QUEUE
    storage.gui.content.h.research_input_mode.f.queue_tech_front.state = rac.set_research_mode == SET_RESEARCH_MODE.ADD_FRONT
    storage.gui.content.h.research_input_mode.f.queue_tech_back.state = rac.set_research_mode == SET_RESEARCH_MODE.ADD_BACK
  end

  -- IO mode (for output signals)
  storage.gui.content.h.research_input_mode.f2.io_mode_value.state = rac.io_mode == 0
  storage.gui.content.h.research_input_mode.f2.io_mode_context.state = rac.io_mode ~= 0

  -- Technology input/output details
  storage.gui.content.h.research_input_mode.f2.research_get_prereq.state = rac.get_research_prereq
  storage.gui.content.h.research_input_mode.f2.research_get_successors.state = rac.get_research_successors
  storage.gui.content.h.research_input_mode.f2.research_get_recipes.state = rac.get_research_recipes
  storage.gui.content.h.research_input_mode.f2.research_get_items.state = rac.get_research_items
  storage.gui.content.h.research_input_mode.f2.research_get_science_packs.state = rac.get_research_science_packs

  -- Set output states
  storage.gui.content.h.research_output_mode.f.h.signal_percent_label.enabled = rac.output_research_progress_percent
  storage.gui.content.h.research_output_mode.f.h.signal_percent.enabled = rac.output_research_progress_percent
  storage.gui.content.h.research_output_mode.f.h2.signal_current_label.enabled = rac.output_research_progress_value
  storage.gui.content.h.research_output_mode.f.h2.signal_current.enabled = rac.output_research_progress_value
  storage.gui.content.h.research_output_mode.f.h3.signal_remaining_label.enabled = rac.output_research_progress_value
  storage.gui.content.h.research_output_mode.f.h3.signal_remaining.enabled = rac.output_research_progress_value
  storage.gui.content.h.research_output_mode.f.h4.signal_total_label.enabled = rac.output_research_progress_value
  storage.gui.content.h.research_output_mode.f.h4.signal_total.enabled = rac.output_research_progress_value

  -- Outputs
  storage.gui.content.h.research_output_mode.f.research_current_check.state = rac.output_current_research
  storage.gui.content.h.research_output_mode.f.research_current_percent.state = rac.output_research_progress_percent
  storage.gui.content.h.research_output_mode.f.h.signal_percent.elem_value = rac.output_research_progress_percent_signal
  storage.gui.content.h.research_output_mode.f.research_current_value.state = rac.output_research_progress_value
  storage.gui.content.h.research_output_mode.f.h2.signal_current.elem_value = rac.output_research_progress_value_csignal
  storage.gui.content.h.research_output_mode.f.h3.signal_remaining.elem_value = rac.output_research_progress_value_rsignal
  storage.gui.content.h.research_output_mode.f.h4.signal_total.elem_value = rac.output_research_progress_value_tsignal

  -- Research status states
  local research_by_status = rac.output_research_by_status ~= OUTPUT_RESEARCH_BY_STATUS.NONE
  storage.gui.content.h.research_output_mode.f.research_status_researched.enabled = research_by_status
  storage.gui.content.h.research_output_mode.f.research_status_available.enabled = research_by_status
  storage.gui.content.h.research_output_mode.f.research_status_unresearched.enabled = research_by_status

  -- Research status
  storage.gui.content.h.research_output_mode.f.research_status_check.state = research_by_status
  if research_by_status then
    storage.gui.content.h.research_output_mode.f.research_status_researched.state = rac.output_research_by_status == OUTPUT_RESEARCH_BY_STATUS.RESEARCHED
    storage.gui.content.h.research_output_mode.f.research_status_available.state = rac.output_research_by_status == OUTPUT_RESEARCH_BY_STATUS.AVAILABLE
    storage.gui.content.h.research_output_mode.f.research_status_unresearched.state = rac.output_research_by_status == OUTPUT_RESEARCH_BY_STATUS.UNRESEARCHED
    end
end

script.on_event(defines.events.on_gui_opened, function(event)
  if event.gui_type == defines.gui_type.entity and event.entity.name == "research-automation-combinator" then
      local player = game.get_player(event.player_index) or {}
      create_gui(player, event.entity)
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  if event.element.name == "rac-close" then
    destroy_gui()
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.gui_type == defines.gui_type.custom and event.element.name == "research-automation-combinator-gui" then
    destroy_gui()
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local elem = event.element
  if storage.gui and elem.tags and elem.tags.rac then
    if elem.type == "radiobutton" and elem.tags.radiobutton_group and elem.parent then
      for _, elem2 in ipairs(elem.parent.children) do
        if elem2 ~= elem and elem2.type == "radiobutton" and elem2.tags and elem2.tags.radiobutton_group == elem.tags.radiobutton_group then
         elem2.state = false
        end
      end
      elem.state = true
    end

    if (elem.name == "enabled_rhs") then
      elem.parent.enabled_rhs_const.text = ""
    end

    update_object_from_gui()
    update_gui_from_object() -- In case the enabled state changed
  end
end)

script.on_event(defines.events.on_gui_confirmed, function(event)
  local elem = event.element
  if storage.gui and elem.tags and elem.tags.rac then
    if (elem.name == "enabled_rhs_const") then
      elem.parent.enabled_rhs.elem_value = nil
    end
    update_object_from_gui()
  end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
  local elem = event.element
  if storage.gui and elem.tags and elem.tags.rac then
    update_object_from_gui()
  end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  local elem = event.element
  if storage.gui and elem.tags and elem.tags.rac then
    update_object_from_gui()
  end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  local elem = event.element
  if storage.gui and elem.tags and elem.tags.rac then
    update_object_from_gui()
  end
end)