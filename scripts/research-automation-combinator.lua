require "scripts.rac-util"


--- @type uint32 The version of the research automation combinator.
local RAC_VERSION = 1

--- @type DeciderCombinatorCondition
local ALWAYS_TRUE_CONDITION = {
  comparator = "≠",
  first_signal = {
    name = "signal-everything",
    type = "virtual"
  },
}

--- @type DeciderCombinatorCondition
local ALWAYS_FALSE_CONDITION = {
  comparator = "=",
  first_signal = {
    name = "signal-anything",
    type = "virtual"
  },
}

--- @enum SetResearchMode
SET_RESEARCH_MODE = {
  NONE = 0,
  REPLACE_QUEUE = 1,
  ADD_FRONT = 2,
  ADD_BACK = 3,
}

--- @enum OutputResearchByStatus
OUTPUT_RESEARCH_BY_STATUS = {
  NONE = 0,
  RESEARCHED = 1,
  AVAILABLE = 2,
  UNRESEARCHED = 3,
}

--- @enum IOMode
IO_MODE = {
  INPUT_VALUE = 0,
  CONTEXT = 1,
}

--- @enum OutputSignalIndex
local OUTPUT_SIGNAL_INDEX = {
  RESEARCH_CURRENT = 1,
  RESEARCH_PERCENT = 2,
  RESEARCH_CURRENT_VALUE = 3,
  RESEARCH_REMAINING_VALUE = 4,
  RESEARCH_TOTAL = 5,
  RESEARCH_STATUS_START = 6,
  RESEARCH_STATUS_END = 7,
  NEXT_FREE = 8,
}

--- @type table<string, LuaRecipePrototype[]> A table of recipes by technology name.
local recipes_by_tech = {}
--- @type table<string, LuaItemPrototype[]> A table of items by technology name.
local items_by_tech = {}
--- @type table<string, LuaFluidPrototype[]> A table of fluids by technology name.
local fluid_by_tech = {}
--- @type table<string, ResearchIngredient[]> A table of science packs by technology name.
local science_packs_by_tech = {}
local qualities = {}

--- Initializes the research automation combinator data.  Called when the mod is loaded.
function init_rac_data()
  -- Initialize the storage table for the research automation combinators
  storage.research_combinators = storage.research_combinators or {}

  -- Fix up the research combinator storage with proper class references
  for _, rac in pairs(storage.research_combinators) do
    if not rac.__index then
      setmetatable(rac, ResearchAutomationCombinator)
    end
  end

  -- Load quality list
  for q, _ in pairs(prototypes.quality) do
    qualities[#qualities+1] = q
  end
  table.sort(qualities)
  if (#qualities == 0) then
    qualities = { "normal" }
  end

  -- Get all technology that has unlocks
  local tech_prototypes = prototypes.get_technology_filtered{
    {filter="enabled"},
    {filter="has-effects", mode="and"},
  }

  for tech_name, tech in pairs(tech_prototypes) do
    -- Get technology recipes
    for _, effect in pairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" then
        local recipe_name = effect.recipe
        local recipe = prototypes.recipe[recipe_name]
        recipes_by_tech[tech_name] = recipes_by_tech[tech_name] or {}
        table.insert(recipes_by_tech[tech_name], recipe)

        -- Get recipe products, consider those the item unlocks
        for _, product in ipairs(recipe.products or {}) do
          if (product.type == "item") then
            local item_name = product.name
            local item = prototypes.item[item_name]
            items_by_tech[tech_name] = items_by_tech[tech_name] or {}
            table.insert(items_by_tech[tech_name], item)
          elseif (product.type == "fluid") then
            local fluid_name = product.name
            local fluid = prototypes.fluid[fluid_name]
            fluid_by_tech[tech_name] = fluid_by_tech[tech_name] or {}
            table.insert(fluid_by_tech[tech_name], fluid)
          end
        end
      end
    end

    -- Build science packs by technology (science packs required to research a tech)
    if tech.research_unit_ingredients then
      science_packs_by_tech[tech_name] = {}
      for _, ingredient in ipairs(tech.research_unit_ingredients) do
        if ingredient then
          table.insert(science_packs_by_tech[tech_name], ingredient)
        end
      end
    end
  end
end


--- Class that holds the research combinator details in an easy to use way.
--- @class ResearchAutomationCombinator
--- @field entity LuaEntity The associated decider combinator entity.
--- @field cb LuaDeciderCombinatorControlBehavior The associated decider combinator control behavior.
--- @field version uint32 The version of the research automation combinator (used for migration logic).
--- @field enabled_state boolean State of the enabled condition.
--- @field enabled_lhs SignalID? The left hand side signal of the enabled condition.
--- @field enabled_comparator string The comparator of the enabled condition.
--- @field enabled_rhs SignalID? The right hand side signal of the enabled condition.
--- @field enabled_rhs_const uint32 The constant value of the enabled condition.
--- @field set_research_mode SetResearchMode How to set the research queue based on input signals.
--- @field get_research_prereq boolean Indicates that we should return the tech prerequisites.
--- @field get_research_successors boolean Indicates that we should return the tech successors.
--- @field get_research_recipes boolean Indicates that we should return the recipes unlocked by the tech.
--- @field get_research_items boolean Indicates that we should return the items unlocked by the tech.
--- @field get_research_science_packs boolean Indicates that we should return the science packs required by the tech.
--- @field io_mode IOMode Indicates whether output values should be derived from input signals or context-based (0=input_value, 1=context).
--- @field output_current_research boolean Indicates we should output the current research.
--- @field output_research_progress_percent boolean Indicates we should output the research progress as a percentage.
--- @field output_research_progress_percent_signal SignalID? The signal used for the research progress percentage.
--- @field output_research_progress_value boolean Indicates we should output the research progress as a value.
--- @field output_research_progress_value_csignal SignalID? The signal used for the research progress current value.
--- @field output_research_progress_value_rsignal SignalID? The signal used for the research progress remaining.
--- @field output_research_progress_value_tsignal SignalID? The signal used for the research progress total.
--- @field output_research_by_status OutputResearchByStatus Indicates which research to output based on status.
--- @field previous_signals Signal[]? The signals from the previous processed tick.
--- @field tick_settings_changed boolean? Indicates whether the settings with on_tick implications have changed since the last tick.
--- @field indexes table<OutputSignalIndex, number> Indexes of output signals
--- @field cached_research_info table<OutputSignalIndex, number>? The saved research progress value (used for the research progress signal).
ResearchAutomationCombinator = {
  version = RAC_VERSION,
  enabled_state = false,
  enabled_comparator = "<",
  enabled_rhs_const = 0,
  set_research_mode = SET_RESEARCH_MODE.NONE,
  get_research_prereq = false,
  get_research_successors = false,
  get_research_recipes = false,
  get_research_items = false,
  get_research_science_packs = false,
  io_mode = IO_MODE.INPUT_VALUE,
  output_current_research = false,
  output_research_progress_percent = false,
  output_research_progress_percent_signal = {
    name = "signal-percent",
    type = "virtual",
  },
  output_research_progress_value = false,
  output_research_progress_value_csignal = {
    name = "signal-C",
    type = "virtual",
  },
  output_research_progress_value_rsignal = {
    name = "signal-R",
    type = "virtual",
  },
  output_research_progress_value_tsignal = {
    name = "signal-T",
    type = "virtual",
  },
  output_research_by_status = OUTPUT_RESEARCH_BY_STATUS.NONE,
}
ResearchAutomationCombinator.__index = ResearchAutomationCombinator

--- Creates a new ResearchAutomationCombinator object.
--- @param entity LuaEntity The associated decider combinator entity.
--- @return ResearchAutomationCombinator
function ResearchAutomationCombinator:new(entity)
  -- Setup object
  local this = {
    entity = entity,
    cb = entity.get_control_behavior(),
    indexes = {
      [OUTPUT_SIGNAL_INDEX.NEXT_FREE] = 1,
    },
  }

  --- @type table<integer, ResearchAutomationCombinator>
  storage.research_combinators[entity.unit_number] = setmetatable(this, self)

  -- If the combinator data is valid, then it likely means that this was created from a blueprint.
  if this:combinator_is_valid() then
    this:configure_from_combinator()
  end

  -- Initialize the combinator state
  this:update_combinator()

  return this
end

--- Gets the control behavior of the research automation combinator.
--- @return LuaDeciderCombinatorControlBehavior cb The control behavior of the research automation combinator.
function ResearchAutomationCombinator:get_control_behavior()
  if (not self.cb or not self.cb.valid or self.cb.entity.unit_number ~= self.entity.unit_number) then
    self.cb = self.entity.get_control_behavior()
  end
  return self.cb
end

--- Gets the ResearchAutomationCombinator from storage.
--- @param unit_number number The research automation combinator entity id.
--- @return ResearchAutomationCombinator? The research automation combinator object (if found).
function ResearchAutomationCombinator:get_from_unit_number(unit_number)
  -- Get the combinator from storage
  local rac = storage.research_combinators[unit_number]

  -- If it doesn't exist, nothing we can do with just a unit number
  if not rac then
    return nil
  -- Otherwise we need to make sure the object is correctly set up, because the metatable information
  -- gets lost as part of Factorio's serialization/deserialization process.
  elseif not rac.__index then
    setmetatable(rac, ResearchAutomationCombinator)
  end

  -- Check is the combinator is valid.  If it isn't, then we need to update the combinator.
  if not rac:combinator_is_valid() then
    rac:update_combinator()
  -- Otherwise, check the object hasn't been marked dirty.  This is done as part of blueprinting to avoid storing
  -- the object data.  An object that is dirty needs to be rebuilt from the combinator.
  elseif rac:is_dirty() then
    -- Rebuild the object from the combinator
    rac:configure_from_combinator()
  end

  return rac
end

-- Gets the ResearchAutomationCombinator from storage.
--- @param entity LuaEntity The associated decider combinator entity.
--- @return ResearchAutomationCombinator? The research automation combinator object (if found).
function ResearchAutomationCombinator:get_from_entity(entity)
  -- Check valid input
  if (not entity or not entity.unit_number) then
    return nil
  end

  -- Get the object by unit number
  local rac = ResearchAutomationCombinator:get_from_unit_number(entity.unit_number)

  -- If it doesn't exist, create a new one (will be stored by new method)
  if not rac then
    rac = ResearchAutomationCombinator:new(entity)
  end

  return rac
end

--- Checks whether the combinator is set up in a valid way.
function ResearchAutomationCombinator:combinator_is_valid()
  -- Check if the control behavior is valid and has the correct number of conditions
  --- @type LuaDeciderCombinatorControlBehavior
  local cb = self:get_control_behavior()
  if not cb then return false end
  --- @type DeciderCombinatorParameters
  local parameters = cb.parameters
  if not parameters or #parameters.conditions ~= 8 then return false end

  -- Check version is supported
  local version = parameters.conditions[3].constant
  if version > 1 then return false end

  -- Check always false condition is set up correctly
  local false_condition = parameters.conditions[2]
  if false_condition.comparator ~= "=" or (not false_condition.first_signal) or false_condition.first_signal.name ~= "signal-anything" then
    return false
  end

  return true
end

--- Checks if the object has been marked dirty (and needs to be rebuilt from the combinator)
function ResearchAutomationCombinator:is_dirty()
  -- Get control behaviour
  --- @type LuaDeciderCombinatorControlBehavior
  local cb = self:get_control_behavior()
  if not cb then return true end
  --- @type DeciderCombinatorParameters
  local parameters = cb.parameters
  if not parameters or #parameters.conditions ~= 8 then return true end

  -- Check whether our unit_number matches the configured value (check only low 32 bits and hope that's good enough...)
  local unit_check = parameters.conditions[8]
  local unit = unit_check.constant or 0
  return bit32.band(self.entity.unit_number, 0xFFFFFFFF) ~= unit
end

--- Configures the combinator based on the current state.
--- @param self ResearchAutomationCombinator The object to configure the combinator for.
function ResearchAutomationCombinator:update_combinator()
  --- @type LuaDeciderCombinatorControlBehavior
  local cb = self:get_control_behavior()

  -- Ensure the combinator has the exact right number of conditions
  while #cb.parameters.conditions < 8 do cb.add_condition({}) end
  while #cb.parameters.conditions > 8 do cb.remove_condition(#cb.parameters.conditions) end

  --- @type DeciderCombinatorCondition
  local condition = {
    comparator = self.enabled_comparator,
    first_signal = self.enabled_lhs,
    second_signal = self.enabled_rhs,
    constant = self.enabled_rhs_const,
  }

  -- First condition is for the actual enabled state that gets used by the combinator.
  if (self.enabled_state) then
    cb.set_condition(1, table.deepcopy(condition))
  else
    cb.set_condition(1, table.deepcopy(ALWAYS_TRUE_CONDITION))
    condition.first_signal_networks = { green = false }
  end

  -- Second condition is the start of the storage area, and is always false (to prevent any other conditions from affecting the output)
  cb.set_condition(2, table.deepcopy(ALWAYS_FALSE_CONDITION))
  -- Third condition is a version number, which should always be the current version when storing to the combinator
  self.version = RAC_VERSION
  cb.set_condition(3, {
    compare_type = "and",
    constant = self.version,
  })

  -- Fourth condition is for the actual enabled condition (we store it separately so even if it is
  -- unchecked in the gui we save the associated values). The setting of the green signal indicates
  -- the state of the enabled checkbox - everything else (first & second signals and constant)
  -- are as configured.
  condition.compare_type = "and"
  cb.set_condition(4, table.deepcopy(condition))

  -- Fifth condition covers the input and output options:
  --   * The constant value encodes the remaining options in a bitwise fashion:
  --     * Bit 1+2: Modify research options:
  --         00: Off
  --         01: Replace Queue
  --         10: Add to front
  --         11: Add to back
  --     * Bit 3: Get tech pre-requisites
  --     * Bit 4: Get tech successors
  --     * Bit 5: Get recipes unlocked by tech
  --     * Bit 6: Get items unlocked by tech
  --     * Bit 7: Get science packs required by tech
  --     * Bit 8: I/O Mode
  --     * Bit 9+10: Output research by status
  --         00: disabled
  --         01: researched techs
  --         10: available techs
  --         11: unresearched techs
  --     * Bit 11: Read current research
  --- @type uint32
  local mask = self.set_research_mode

  if self.get_research_prereq then
    mask = bit32.bor(mask, 0x04)
  end
  if self.get_research_successors then
    mask = bit32.bor(mask, 0x08)
  end
  if self.get_research_recipes then
    mask = bit32.bor(mask, 0x10)
  end
  if self.get_research_items then
    mask = bit32.bor(mask, 0x20)
  end
  if self.get_research_science_packs then
    mask = bit32.bor(mask, 0x40)
  end
  if self.io_mode ~= IO_MODE.INPUT_VALUE then
    mask = bit32.bor(mask, 0x80)
  end
  if (self.output_research_by_status ~= OUTPUT_RESEARCH_BY_STATUS.NONE) then
    mask = bit32.bor(mask, bit32.lshift(self.output_research_by_status, 8))
  end
  if (self.output_current_research) then
    mask = bit32.bor(mask, 0x0400)
  end

  cb.set_condition(5, {
    compare_type = "and",
    constant = mask,
  })

  -- Sixth condition is the Read Research Progress (value)
  --   * The comparator value encodes whether it is enabled or not:
  --     * = On
  --     * ≠ Off
  --   * The first_signal represents the research value signal
  --   * The second_signal represents the total research signal
  --   * The second_signal of the next condition represents the research remaining signal
  cb.set_condition(6, {
    compare_type = "and",
    comparator = self.output_research_progress_value and "=" or "≠",
    first_signal = self.output_research_progress_value_csignal,
    second_signal = self.output_research_progress_value_tsignal,
  })

  -- Seventh condition has the remaining outputs
  --   * The comparator value encodes whether Read Research Progress (%) is enabled or not:
  --     * = On
  --     * ≠ Off
  --   * The first_signal represents the percent signal
  cb.set_condition(7, {
    compare_type = "and",
    comparator = self.output_research_progress_percent and "=" or "≠",
    first_signal = self.output_research_progress_percent_signal,
    second_signal = self.output_research_progress_value_rsignal,
  })

  -- Eighth condition is used for dirty checks:
    --   * The constant encodes the unit number (low 32 bits) to help with dirty checks
  cb.set_condition(8, {
    compare_type = "and",
    constant = bit32.band(self.entity.unit_number, 0xFFFFFFFF),
  })

  -- Clear states and remove progress signals if features are disabled
  self.cached_research_info = {}
  if not self.output_research_progress_percent then
    self:remove_output(OUTPUT_SIGNAL_INDEX.RESEARCH_PERCENT, cb)
  end
  if not self.output_research_progress_value then
    self:remove_output(OUTPUT_SIGNAL_INDEX.RESEARCH_CURRENT_VALUE, cb)
    self:remove_output(OUTPUT_SIGNAL_INDEX.RESEARCH_REMAINING_VALUE, cb)
    self:remove_output(OUTPUT_SIGNAL_INDEX.RESEARCH_TOTAL, cb)
  end

  -- Also call any handlers that need to be called when the combinator is updated
  self:on_research_change(nil)
  self:on_research_queue_change(nil)
end

--- Sets up the object based on what is read from the combinator
function ResearchAutomationCombinator:configure_from_combinator()
  --- @type LuaDeciderCombinatorControlBehavior
  local cb = self:get_control_behavior()
  --- @type DeciderCombinatorParameters
  local parameters = cb.parameters

  -- Get the enabled conditions
  local enabled_cond = parameters.conditions[4]
  self.enabled_state = not (enabled_cond.first_signal_networks and (not enabled_cond.first_signal_networks.green))
  self.enabled_lhs = enabled_cond.first_signal
  self.enabled_rhs = enabled_cond.second_signal
  self.enabled_rhs_const = enabled_cond.constant or 0
  self.enabled_comparator = enabled_cond.comparator or "<"

  -- Get input conditions
  local mask = parameters.conditions[5].constant or 0
  self.set_research_mode = bit32.band(mask, 0x03)
  self.get_research_prereq = bit32.band(mask, 0x04) ~= 0
  self.get_research_successors = bit32.band(mask, 0x08) ~= 0
  self.get_research_recipes = bit32.band(mask, 0x10) ~= 0
  self.get_research_items = bit32.band(mask, 0x20) ~= 0
  self.get_research_science_packs = bit32.band(mask, 0x40) ~= 0
  self.io_mode = bit32.band(mask, 0x80) ~= 0 and 1 or 0

  -- Get output conditions
  self.output_research_by_status = bit32.rshift(bit32.band(mask, 0x0300), 8)
  self.output_current_research = bit32.band(mask, 0x0400) ~= 0

  -- Read research (value)
  local read_research_value_cond = parameters.conditions[6]
  self.output_research_progress_value = read_research_value_cond.comparator == "="
  self.output_research_progress_value_csignal = read_research_value_cond.first_signal
  self.output_research_progress_value_tsignal = read_research_value_cond.second_signal

  -- Read research (%)
  local read_research_percent_cond = parameters.conditions[7]
  self.output_research_progress_percent = read_research_percent_cond.comparator == "="
  self.output_research_progress_percent_signal = read_research_percent_cond.first_signal
  self.output_research_progress_value_rsignal = read_research_percent_cond.second_signal

  -- Position 8 contains the unit number - we store this for dirty checks
  local low_unit_number = bit32.band(self.entity.unit_number, 0xFFFFFFFF)
  local unit_check = parameters.conditions[8]
  if (unit_check.constant ~= low_unit_number) then
    unit_check.constant = low_unit_number
    cb.set_condition(8, unit_check)
  end

  -- Clear existing outputs
  for i = #parameters.outputs, 1, -1 do
    cb.remove_output(i)
  end
  self.indexes = {
    [OUTPUT_SIGNAL_INDEX.NEXT_FREE] = 1,
  }
  self.cached_research_info = {}

  -- Call handlers to make sure everything is properly updated
  self:on_research_change(nil)
  self:on_research_queue_change(nil)

  -- Assume tick settings have changed
  self.tick_settings_changed = true
end


--- On tick handler for the research automation combinator.  Needs to be speedy, since it is called every tick.
function ResearchAutomationCombinator:on_tick()
  -- Do a check to see if we need to reconfigure the combinator (little choice but to do this expensive check frequently,
  -- as there is no event for placing a blueprint on top of an entity).
  if (self.entity.unit_number + game.tick) % 60 == 0 then
    if (self:is_dirty()) then
      self:configure_from_combinator()
    end
  end

  -- Do we have anything that even needs on_tick processing?
  if (self.set_research_mode == SET_RESEARCH_MODE.NONE and
      not self.get_research_prereq and
      not self.get_research_successors and
      not self.get_research_recipes and
      not self.get_research_items and
      not self.get_research_science_packs and
      not self.output_research_progress_percent and
      not self.output_research_progress_value
  ) then
    -- Even if nothing is enabled, if settings just changed we need to rebuild outputs to clear them
    if not self.tick_settings_changed then
      return
    end
  end

  -- Next opportunity to exit early is if we have a disable condition.
  if self.enabled_state and self.enabled_lhs then
    local lhs = self.entity.get_signal(self.enabled_lhs, defines.wire_connector_id.combinator_input_green, defines.wire_connector_id.combinator_input_red)
    local rhs = self.enabled_rhs and self.entity.get_signal(self.enabled_rhs, defines.wire_connector_id.combinator_input_green, defines.wire_connector_id.combinator_input_red)
      or self.enabled_rhs_const

    -- Attempt to do this smartly.  We want to return when the condition is false.  First we'll handle cases where the signals are equal.
    if (lhs == rhs) then
      if (self.enabled_comparator == ">" or self.enabled_comparator == "<" or self.enabled_comparator == "≠") then
        return
      end
    -- If the comparator is =, then can return with one more comparison
    elseif (self.enabled_comparator == "=") then
      return
    -- Now check less than cases
    elseif (lhs < rhs) then
      if (self.enabled_comparator == ">" or self.enabled_comparator == "≥") then
        return
      end
    -- Finally we we just have the greater than cases left to check
    else
      if (self.enabled_comparator == "<" or self.enabled_comparator == "≤") then
        return
      end
    end
  end

  --- @type LuaDeciderCombinatorControlBehavior
  local cb = self:get_control_behavior()
  local parameters = cb.parameters
  if parameters == nil then
    parameters = {
      conditions = {},
      outputs = {}
    }
    cb.parameters = parameters
  end

  -- Process things that don't care about input signals first
  if (self.output_research_progress_percent and self.output_research_progress_percent_signal or
      (self.output_research_progress_value and (self.output_research_progress_value_csignal or self.output_research_progress_value_rsignal or self.output_research_progress_value_tsignal))) then
    local tech = game.forces.player.current_research
    local progress = game.forces.player.research_progress or 0
    if tech then
      local signals = {}
      if (self.output_research_progress_percent and self.output_research_progress_percent_signal) then
        signals[#signals+1] = OUTPUT_SIGNAL_INDEX.RESEARCH_PERCENT
      end
      if (self.output_research_progress_value) then
        if (self.output_research_progress_value_tsignal) then
          signals[#signals+1] = OUTPUT_SIGNAL_INDEX.RESEARCH_TOTAL
        end
        if (self.output_research_progress_value_csignal) then
          signals[#signals+1] = OUTPUT_SIGNAL_INDEX.RESEARCH_CURRENT_VALUE
        end
        if (self.output_research_progress_value_rsignal) then
          signals[#signals+1] = OUTPUT_SIGNAL_INDEX.RESEARCH_REMAINING_VALUE
        end
      end

      for _, i in ipairs(signals) do
        if (not self.cached_research_info) then
          self.cached_research_info = {}
        end

        -- Calculate current value
        local value = nil
        if (i == OUTPUT_SIGNAL_INDEX.RESEARCH_PERCENT) then
          value = math.floor(100 * progress)
        elseif ((self.entity.unit_number + game.tick) % 60 == 0 or self.cached_research_info[i] == nil) then
          -- Calculate research from formula
          local formula = tech.research_unit_count_formula
          if (formula) then
            value = helpers.evaluate_expression(formula, { L = tech.level, l = tech.level })
          else
            value = tech.research_unit_count
          end

          -- Convert to a value
          if (i == OUTPUT_SIGNAL_INDEX.RESEARCH_CURRENT_VALUE) then
            value = math.floor(value * progress)
          elseif (i == OUTPUT_SIGNAL_INDEX.RESEARCH_REMAINING_VALUE) then
            value = math.floor(value * (1 - progress))
          end
        else
          value = self.cached_research_info[i]
        end

        if (self.cached_research_info[i] ~= value) then
          self.cached_research_info[i] = value

          -- Get the existing output
          local current_index = self.indexes[i]
          local current_output = current_index and parameters.outputs[current_index] or nil

          -- Build the output table
          local signal = i == OUTPUT_SIGNAL_INDEX.RESEARCH_PERCENT and self.output_research_progress_percent_signal or
            i == OUTPUT_SIGNAL_INDEX.RESEARCH_CURRENT_VALUE and self.output_research_progress_value_csignal or
            i == OUTPUT_SIGNAL_INDEX.RESEARCH_REMAINING_VALUE and self.output_research_progress_value_rsignal or
            i == OUTPUT_SIGNAL_INDEX.RESEARCH_TOTAL and self.output_research_progress_value_tsignal or nil
          local output = {
            signal = signal,
            constant = value,
            copy_count_from_input = false,
          }

          -- Update the existing output
          if current_output then
            cb.set_output(current_index, output)
          -- Add a new output
          else
            self:add_output(i, output, cb)
          end
        end
      end
    end
  end

  -- We have pased the enabled check, next we get a list of all relevant signals, which are only the rac signals
  --- @type Signal[]
  local input_tech_signals = {}
  for _, s in ipairs(self.entity.get_signals(defines.wire_connector_id.circuit_green, defines.wire_connector_id.circuit_red) or {}) do
    if (string.sub(s.signal.name, 1, 4) == "rac-") then
      input_tech_signals[#input_tech_signals+1] = s
    end
  end

  -- Assume the most likely scenario is the signals didn't change, and so we try to check for that and return.  Also treats a change in signal order as a change.
  local changed = false
  if (not self.tick_settings_changed and self.previous_signals and #self.previous_signals == #input_tech_signals) then
    for i, s1 in ipairs(input_tech_signals) do
      local s2 = self.previous_signals[i]
      if s1.count ~= s2.count or s1.signal.name ~= s2.signal.name or s1.signal.quality ~= s2.signal.quality then
        changed = true
        break
      end
    end
  else
    changed = true
  end
  if not changed then return end
  self.tick_settings_changed = false

  -- Signals have changed, so now the goal will be to update the combinator in the simplest way possible.
  self.previous_signals = input_tech_signals

  -- Start by building the output list
  --- @type { [string]: { [string]: { [string]: integer } } }
  local output_signals = {
    item = {},
    fluid = {},
    recipe = {},
    virtual = {},
  }
  for _, s in ipairs(input_tech_signals) do
    local quality = s.signal.quality or "normal"

    -- Remove "rac-technology-" to get the tech name
    local tech_name = string.sub(s.signal.name or "", 16, -1)
    local tech = game.forces.player.technologies[tech_name]

    -- Get technology prerequisites
    if (self.get_research_prereq) then
      -- Get prerequisite for "normal" versions of technologies
      if (self.io_mode == IO_MODE.INPUT_VALUE or
          s.count == tech.prototype.level or
          tech.prototype.level == tech.prototype.max_level)
      then
        for ptech_name, ptech in pairs(tech.prerequisites or {}) do
          local signal_name = "rac-technology-" .. ptech_name
          local value = self.io_mode == IO_MODE.INPUT_VALUE and s.count or ptech.prototype.level
          output_signals["virtual"][signal_name] = output_signals["virtual"][signal_name] or {}
          output_signals["virtual"][signal_name][quality] = (output_signals["virtual"][signal_name][quality] or 0) + value
        end
      -- Handle infinite technologies
      elseif (s.count > tech.prototype.level) then
        local value = s.count - 1
        output_signals["virtual"][s.signal.name] = output_signals["virtual"][s.signal.name] or {}
        output_signals["virtual"][s.signal.name][quality] = (output_signals["virtual"][s.signal.name][quality] or 0) + value
      end

    end

    -- Get technology successors
    if (self.get_research_successors) then
      -- Get successors for "normal" versions of technologies
      if (self.io_mode == IO_MODE.INPUT_VALUE or
          s.count < tech.prototype.level or
          tech.prototype.level == tech.prototype.max_level)
      then
        for stech_name, stech in pairs(tech.successors or {}) do
          local signal_name = "rac-technology-" .. stech_name
          local value = self.io_mode == IO_MODE.INPUT_VALUE and s.count or stech.prototype.level
          output_signals["virtual"][signal_name] = output_signals["virtual"][signal_name] or {}
          output_signals["virtual"][signal_name][quality] = (output_signals["virtual"][signal_name][quality] or 0) + value
        end
      -- Handle infinite technologies
      elseif (s.count < tech.prototype.max_level) then
        local value = s.count + 1
        output_signals["virtual"][s.signal.name] = output_signals["virtual"][s.signal.name] or {}
        output_signals["virtual"][s.signal.name][quality] = (output_signals["virtual"][s.signal.name][quality] or 0) + value
      end
    end

    -- Get technology recipes
    if (self.get_research_recipes) then
      for _, recipe in ipairs(recipes_by_tech[tech_name] or {}) do
        local recipe_name = recipe.name
        output_signals["recipe"][recipe_name] = output_signals["recipe"][recipe_name] or {}
        output_signals["recipe"][recipe_name][quality] = (output_signals["recipe"][recipe_name][quality] or 0) + s.count
      end
    end

    -- Get technology items
    if (self.get_research_items) then
      for _, item in ipairs(items_by_tech[tech_name] or {}) do
        local item_name = item.name
        output_signals["item"][item_name] = output_signals["item"][item_name] or {}
        output_signals["item"][item_name][quality] = (output_signals["item"][item_name][quality] or 0) + s.count
      end

      for _, fluid in ipairs(fluid_by_tech[tech_name] or {}) do
        local fluid_name = fluid.name
        output_signals["fluid"][fluid_name] = output_signals["fluid"][fluid_name] or {}
        output_signals["fluid"][fluid_name][quality] = (output_signals["fluid"][fluid_name][quality] or 0) + s.count
      end
    end

    -- Get science packs required by technology
    if (self.get_research_science_packs) then
      for _, item in ipairs(science_packs_by_tech[tech_name] or {}) do
        local item_name = item.name
        local count = self.io_mode == 0 and s.count or item.amount
        output_signals["item"][item_name] = output_signals["item"][item_name] or {}
        output_signals["item"][item_name][quality] = (output_signals["item"][item_name][quality] or 0) + count
      end
    end
  end

  -- We have a list of signals to output, so we need to set them in the combinator.  Most are already set, so we will merge our list in with the existing ones.
  -- Removing existing empty output will make our life way easier
  if (#parameters.outputs == 1 and not parameters.outputs[1].signal) then
    cb.remove_output(1)
  end

  -- Step through our lists in parallel.  We use a sorted iterator, because although Factorio guarantees *deterministic*
  -- ordering of keys, it does not guarantee *sorted* ordering of keys.  We make the assumption that the overhead added by
  -- sorting the output signals is less significant than what we save from having to constantly rebuild the combinator output.
  local i = self.indexes[OUTPUT_SIGNAL_INDEX.NEXT_FREE] or 1
  for _, signal_type in ipairs({"fluid", "item", "recipe", "virtual"}) do
    for signal_name, qarr in sorted_iter(output_signals[signal_type] or {}) do
      for _, quality in ipairs(qualities) do
        if qarr[quality] then
          -- Loop as we may need to remove rows and retry our comparisons
          local continue = true
          while (continue) do
            continue = false
            local insert = false

            --- @type DeciderCombinatorOutput
            local current_output = parameters.outputs[i]

            if (i > #parameters.outputs or (current_output.signal.type or "item") > signal_type) then
              -- Past all existing signals (of this type), so just need to add to end (or current position)
              insert = true
            else
              local current_name = ""
              --- @type LuaQualityPrototype | string
              local current_quality = "normal"
                if (current_output.signal) then
                current_name = current_output.signal.name or ""
                current_quality = current_output.signal.quality or "normal"
              end

              if (current_name == signal_name) then
                if (current_quality == quality) then
                  if ((current_output.constant or 1) ~= qarr[quality]) then
                    -- If the signal name and quality are the same, but the count is different, then we need to update it.
                    current_output.constant = qarr[quality]
                    cb.set_output(i, current_output)
                  end
                  i = i + 1
                elseif (current_quality < quality) then
                  -- Record should not longer exist, remove
                  cb.remove_output(i)
                  continue = true
                else
                  -- Found insertion position
                  insert = true
                end
              elseif (current_name < signal_name) then
                -- Record should not longer exist, remove
                cb.remove_output(i)
                continue = true
              else
                -- Found insertion position
                insert = true
              end
            end

            if (insert) then
              local output = {
                signal = {
                  type = signal_type,
                  name = signal_name,
                  quality = quality,
                },
                constant = qarr[quality],
                copy_count_from_input = false,
              }
              cb.add_output(output, i)
              i = i + 1
            end
          end
        end
      end
    end

    --- Remove anything that is left over for this signal type
    while (i <= #parameters.outputs and parameters.outputs[i].signal and parameters.outputs[i].signal.type == signal_type) do
      table.remove(parameters.outputs, i)
      cb.remove_output(i)
    end
  end
end


--- Adds an output signal to the combinator and keeps the signal list up to date.
--- @param name OutputSignalIndex The name of the index to add.
--- @param output DeciderCombinatorOutput The output signal to add.
--- @param cb LuaDeciderCombinatorControlBehavior? The control behavior of the combinator.
--- @overload fun(index)
function ResearchAutomationCombinator:add_output(name, output, cb)
  --- Get control behavior
  --- @type LuaDeciderCombinatorControlBehavior
  cb = cb or self:get_control_behavior()

  -- Get the next free index and add the output signal to the combinator
  local index = self.indexes[OUTPUT_SIGNAL_INDEX.NEXT_FREE] or 1
  cb.add_output(output, index)

  -- Increment next free index and set the new index for the signal
  self.indexes[OUTPUT_SIGNAL_INDEX.NEXT_FREE] = index + 1
  self.indexes[name] = index
end


--- Removes the output signal from the combinator and keeps the signal list up to date.
--- @param name OutputSignalIndex The name of the index to remove.
--- @param cb LuaDeciderCombinatorControlBehavior? The control behavior of the combinator.
--- @overload fun(index_or_name)
function ResearchAutomationCombinator:remove_output(name, cb)
  -- Get the index to remove
  local index = self.indexes[name]
  if not index then return end

  --- Remove from the combinator
  --- @type LuaDeciderCombinatorControlBehavior
  cb = cb or self:get_control_behavior()
  cb.remove_output(index)

  -- Decrement the remaining indexes that were above the removed index
  for _, i  in pairs(OUTPUT_SIGNAL_INDEX) do
    if (self.indexes[i]) then
      if (self.indexes[i] == index and i ~= OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_START) then
        self.indexes[i] = nil
      elseif (self.indexes[i] > index) then
        self.indexes[i] = self.indexes[i] - 1
      end
    end
  end

  -- If we removed the last research status signal, clear it out
  if (self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_START] and
      self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_END] and
      self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_END] < self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_START]
  ) then
    self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_START] = nil
    self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_END] = nil
  end
end

--- Removes all research status outputs from the combinator and updates indexes accordingly.
--- @param cb LuaDeciderCombinatorControlBehavior? The control behavior of the combinator.
function ResearchAutomationCombinator:remove_research_status_outputs(cb)
  -- If there are no research status outputs, nothing to do
  if not self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_START] then return end

  --- Get control behavior if not provided
  --- @type LuaDeciderCombinatorControlBehavior
  cb = cb or self:get_control_behavior()
  local parameters = cb.parameters
  if not parameters then return end

  -- Calculate how many outputs we're removing
  local start = self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_START]
  local end_idx = self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_END]
  local count = end_idx - start + 1

  -- Remove the outputs in reverse order
  for i = end_idx, start, -1 do
    cb.remove_output(i)
  end

  -- Update all indexes that were after the removed section
  for _, i in pairs(OUTPUT_SIGNAL_INDEX) do
    if self.indexes[i] then
      if self.indexes[i] >= start and self.indexes[i] <= end_idx then
        -- This index was in the removed range
        if i ~= OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_START then
          self.indexes[i] = nil
        end
      elseif self.indexes[i] > end_idx then
        -- This index was after the removed range, decrease by the number of items removed
        self.indexes[i] = self.indexes[i] - count
      end
    end
  end

  -- Clear the research status range
  self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_START] = nil
  self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_END] = nil
end

--- Handler for any change to research (finishing, cancelling, reversing).
--- @param event? EventData.on_research_finished|EventData.on_research_reversed|EventData.on_research_cancelled
function ResearchAutomationCombinator:on_research_change(event)
  -- Remove existing research status outputs
  self:remove_research_status_outputs()

  if self.output_research_by_status ~= OUTPUT_RESEARCH_BY_STATUS.NONE then
    -- Make a list of all the tech that we need to output
    local techs = {}
    if (self.output_research_by_status == OUTPUT_RESEARCH_BY_STATUS.RESEARCHED) then
      for _, tech in pairs(game.forces.player.technologies) do
        if (tech.researched) then
          techs[#techs+1] = tech
        end
      end
    elseif (self.output_research_by_status == OUTPUT_RESEARCH_BY_STATUS.UNRESEARCHED) then
      for _, tech in pairs(game.forces.player.technologies) do
        if (not tech.researched) then
          techs[#techs+1] = tech
        end
      end
    elseif (self.output_research_by_status == OUTPUT_RESEARCH_BY_STATUS.AVAILABLE) then
      for _, tech in pairs(game.forces.player.technologies) do
        if (not tech.researched) then
          local available = true
          for _, ptech in pairs(tech.prerequisites or {}) do
            if not ptech.researched then
              available = false
              break
            end
          end

          if available then
            techs[#techs+1] = tech
          end
        end
      end
    end

    -- Output the techs to the combinator
    --- @type LuaDeciderCombinatorControlBehavior
    local cb = self:get_control_behavior()

    -- Add new research status outputs
    if #techs > 0 then
      local start_idx = self.indexes[OUTPUT_SIGNAL_INDEX.NEXT_FREE] or 1
      self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_START] = start_idx
      local i = start_idx

      for _, tech in ipairs(techs) do
        -- Check if the virtual signal exists (it may not if a mod was removed)
        local signal_name = "rac-technology-" .. tech.name
        if prototypes.virtual_signal[signal_name] then
          local output = {
            signal = {
              type = "virtual",
              name = signal_name,
              quality = "normal",
            },
            constant = 1,
            copy_count_from_input = false,
          }
          cb.add_output(output, i)
          i = i + 1
        end
      end

      self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_END] = start_idx + #techs - 1
      self.indexes[OUTPUT_SIGNAL_INDEX.NEXT_FREE] = self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_STATUS_END] + 1
    end
  end
end

--- Handler for any change to the research queue (starting, finishing, cancelling, and moving research).
--- @param event? EventData.on_research_finished|EventData.on_research_started|EventData.on_research_cancelled|EventData.on_research_moved
function ResearchAutomationCombinator:on_research_queue_change(event)
  local clear_research = false
  if self.output_current_research then
    local tech = game.forces.player.current_research
    if tech then
      local signal_name = "rac-technology-" .. tech.name

      --- @type LuaDeciderCombinatorControlBehavior
      local cb = self:get_control_behavior()

      -- Check if the output already exists and is correct
      local current_index = self.indexes[OUTPUT_SIGNAL_INDEX.RESEARCH_CURRENT]
      local current_output = current_index and cb.get_output(current_index) or nil
      if current_output and current_output.signal and current_output.signal.name == signal_name then
        return
      end

      -- Check if the virtual signal exists (it may not if a mod was removed)
      if prototypes.virtual_signal[signal_name] then
        local output = {
          signal = {
            type = "virtual",
            name = signal_name,
            quality = "normal",
          },
          constant = 1,
          copy_count_from_input = false,
        }

        -- Update the existing output
        if current_output then
          cb.set_output(current_index, output)
        -- Add a new output
        else
          self:add_output(OUTPUT_SIGNAL_INDEX.RESEARCH_CURRENT, output, cb)
        end
      else
        -- Signal doesn't exist, clear the output if it was set
        clear_research = true
      end
    -- No current research, so remove the output if it exists
    else
      clear_research = true
    end
  else
    clear_research = true
  end

  if clear_research then
    self:remove_output(OUTPUT_SIGNAL_INDEX.RESEARCH_CURRENT)
  end
end
