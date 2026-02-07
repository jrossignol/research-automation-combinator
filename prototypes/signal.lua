-- Exported module for signal creation
local signal_module = {}

--- Science pack tier lookup table
local sci_tiers = {}

--- Reverse lookup tech table
local tech_unlocks = {}

--- Helper function to generate an icon for a digit
--- @param digit string The digit to generate the icon for.
--- @return data.IconData iconData The icon data for the digit.
local function signal_digit_icon(digit)
  return {
    icon = "__research-automation-combinator__/graphics/icons/" .. digit .. ".png",
    icon_size = 32,
    shift = { 9, -12 },
    scale = 0.5,
    tint = { 66, 206, 245, 255 },
    floating = true
  }
end

--- Helper function to generate all the icons for a tech signal and add them to the signal.
--- @param signal data.VirtualSignalPrototype The signal to add icons to
--- @param tech data.TechnologyPrototype The technology to generate icons for.
--- @param tech_basename string|nil The base name of the technology (without level), if applicable.
--- @param level string|nil The level of the technology, if applicable.
local function add_signal_icons(signal, tech, tech_basename, level)
  -- Pull the initial icon from the icon field if available
  if (not tech.icons or #tech.icons == 0) then
    if not tech.icon then
      -- Tech has no icon, let fix_signal_icons handle it
      return
    end
    signal.icons = {
      {
        icon = tech.icon,
        icon_size = tech.icon_size,
        tint = tech.icons
      },
    }
  else
    signal.icons = {}
  end

  -- Handle techs with a more icons (infinite techs have a small sub-icon, or
  -- mods might use a tint layer).
  for _, orig_icon in ipairs(tech.icons or {}) do
    -- Initial copy of tech
    local icon = {}
    for k,v in pairs(orig_icon) do
      icon[k] = v
    end

    -- Rescale floating icons
    if icon.floating and icon.icon_size then
      local scale_factor = 32 / icon.icon_size
      icon.scale = icon.scale and icon.scale * scale_factor
      icon.shift = icon.shift and { icon.shift[1] * scale_factor, icon.shift[2] * scale_factor }
    end

    -- Append into the icons
    table.insert(signal.icons, icon)
  end

  -- Special handling for infinite techs
  if tech.max_level == "infinite" then
    table.insert(signal.icons, signal_digit_icon(tostring(tech.max_level)))
  -- Add numeric identifier for techs with level, but which do not have a named
  -- tech without a level (this stops us from adding digits to the module techs)
  elseif level and tech.upgrade and not data.raw["technology"][tech_basename] then
    -- TODO: Need to properly handle values greater than 9.  For now, just use
    -- the infinite icon for those.
    table.insert(signal.icons, signal_digit_icon(tonumber(level) < 10 and level or "infinite"))
  end

  -- Set the signals's icon_size only if icons[1].icon_size is nil
  if signal.icons[1] and not signal.icons[1].icon_size and tech.icon_size then
    signal.icon_size = tech.icon_size
  end
end

--- Helper function for creating a subgroup with the given name.  Extends data with the created subgroup.
--- @param name string The name of the subgroup to create.
local function subgroup(name)
  data:extend({
    {
      type = "item-subgroup",
      group = "rac-technology",
      name = "rac-technology-" .. name,
      order = name,
    },
  })
end

--- Initializes the science tier lookup table
local function init_sci_tiers()
  sci_tiers = {}
  local i = 0
  for name, tool in pairs(data.raw.tool) do
    i = i + 1
    sci_tiers[name] = i
  end
end

--- Initializes the technology unlocks lookup table
local function init_tech_unlocks()
  tech_unlocks = {}
  for name, tech in pairs(data.raw.technology) do
    for _, ptech in ipairs(tech.prerequisites or {}) do
      tech_unlocks[ptech] = tech_unlocks[ptech] or {}
      table.insert(tech_unlocks[ptech], name)
    end
  end
end

--- Creates all subgroups (called during data-updates)
local function init_all_subgroups()
  local i = 0
  for name, tool in pairs(data.raw.tool) do
    i = i + 1
    subgroup(string.format("%03d", i))
  end
  -- Add fallback subgroups at the start and end
  subgroup("000")
  subgroup("999")
end

--- Adds missing subgroups if they don't already exist (called during data-final-fixes)
local function init_missing_subgroups()
  -- Check which science pack subgroups are missing
  for name, tool in pairs(data.raw.tool) do
    local subgroup_name = "rac-technology-" .. string.format("%03d", sci_tiers[name] or 0)
    if not data.raw["item-subgroup"][subgroup_name] then
      subgroup(string.format("%03d", sci_tiers[name] or 0))
    end
  end

  -- Check fallback subgroups
  if not data.raw["item-subgroup"]["rac-technology-000"] then
    subgroup("000")
  end
  if not data.raw["item-subgroup"]["rac-technology-999"] then
    subgroup("999")
  end
end

--- @type table<string, number> Cache of technology tiers
local tech_tiers = {}

-- Helper function for determining the "tier" of a tech
--- @param tech data.TechnologyPrototype The technology to determine the tier for.
--- @param seen table|nil Map of visited techs to prevent infinite recursion
--- @return number tier The tier of the associated tech.
local function tech_tier(tech, seen)
  seen = seen or {}
  
  -- Not a real tech, return 0
  if (tech == nil) then
    return 0
  end

  -- Check if we've already visited this tech (cycle detection)
  if seen[tech.name] then
    log("[RAC] Cycle detected at tech: " .. tech.name)
    return 999
  end

  -- Check cache first
  if not tech_tiers[tech.name] then
    -- Mark this tech as visited
    seen[tech.name] = true

    -- Determine the highest tier science pack required
    local sci_tier = 0
    for _, ri in ipairs(tech.unit and tech.unit.ingredients or {}) do
      sci_tier = sci_tiers[ri[1]] > sci_tier and sci_tiers[ri[1]] or sci_tier
    end

    -- If the tier is zero then this may be a triggered tech
    if sci_tier == 0 and tech.research_trigger then
      sci_tier = 999 -- Assume max tier
      for _, dtech in ipairs(tech_unlocks[tech.name] or {}) do
        -- Recursion - We check for tech dependency loops here
        dtech_tier = tech_tier(data.raw.technology[dtech], seen)
        -- Take the minimum of all the dependent techs' tiers
        sci_tier = sci_tier < dtech_tier and sci_tier or dtech_tier
      end
    end

    -- Assign the tier to the cache
    tech_tiers[tech.name] = sci_tier

    -- If we ended up with tier 999, do one last check to try to find one by
    -- going the other way down the dependency tree.  We do this after
    -- assigning a value, or else this could become an infinite loop.
    if sci_tier == 999 then
      for _, ptech in ipairs(tech.prerequisites or {}) do
        ptech_tier = tech_tier(data.raw.technology[ptech], seen)
        sci_tier = sci_tier < ptech_tier and sci_tier or ptech_tier
      end

      -- Reassign the tier to the cache (hopefully it changed)
      tech_tiers[tech.name] = sci_tier
    end

  end

  return tech_tiers[tech.name]
end

-- Helper function to create a signal for a technology
--- @param tech data.TechnologyPrototype The technology to create a signal for.
--- @return data.VirtualSignalPrototype virtualSignal The signal for the associated tech.
local function create_tech_signal(tech)

  if tech.name == "muluna-aluminum-processing" then
    log("Creating signal for " .. tech.name)
  end

  --- @type data.VirtualSignalPrototype
  local signal = {
    type = "virtual-signal",
    name = "rac-technology-" .. tech.name,
    icons = {},
    techID = tech.name
  }
  add_signal_icons(signal, tech)

  -- Need to remove the numbers from localised names.  While we're doing
  -- that, use different strings to build the names of infinite and non-infinite
  -- repeating techs.
  local tech_basename, tech_level = string.match(tech.name, "(%g+)-(%d+)")
  if not tech_basename then
    -- Reference localised names of technology for the signal names
    signal.localised_name = tech.localised_name or { "technology-name." .. tech.name }
    signal.localised_description = tech.localised_description or { "technology-description." .. tech.name }
    add_signal_icons(signal, tech)
  else
    -- Use the form "<tech> <number>" or "<tech> <number>+" depending on whether
    -- the tech is infinite or just numbered.
    local tech_str = "rac-numbered-tech"
    if tech.max_level == "infinite" then
      tech_str = "rac-infinite-tech"
    end

    -- Need to reference the correctly localised string (without the extra digit)
    signal.localised_name = { tech_str, { "technology-name." .. tech_basename }, tech_level }
    signal.localised_description = { "technology-description." .. tech_basename }
    add_signal_icons(signal, tech, tech_basename, tech_level)
  end

  -- Determine the tier of this tech
  local sci_tier = tech_tier(tech)

  -- Check if this tech is one that unlocks a science pack, and instead move
  -- the tech to that subgroup for the science pack
  for i, mod in ipairs(tech.effects or {}) do
    if mod.type == "unlock-recipe" then
      local recipe = data.raw.recipe[mod.recipe]
      if recipe then
        for j, prod in ipairs(recipe.results) do
          if prod.type == "item" and sci_tiers[prod.name] then
            sci_tier = sci_tiers[prod.name]
            signal.order = "a"
          end
        end
      end
    end
  end

  -- If no order determined yet, use science packs, then name to determine ordering
  if not signal.order then
    -- Trigger techs first
    if not tech.unit then
      signal.order = "b"
    else
      local pack_str = ""
      for i, ri in ipairs(tech.unit and tech.unit.ingredients or {}) do
        pack_str = pack_str .. "-" .. string.format("%02d", sci_tiers[ri[1]] or 0)
      end
      signal.order = "c" .. pack_str
    end

    -- Add the name for final ordering
    signal.order = signal.order .. "-" .. tech.name
  end

  -- Tier determines the subgroup
  signal.subgroup = string.format("rac-technology-%03d", sci_tier)

  return signal
end

--- Creates signals for all technologies (called during data-updates)
function signal_module.create_initial_signals()
  -- Initialize lookup tables
  init_sci_tiers()
  init_tech_unlocks()
  init_all_subgroups()
  
  local tech_signals = {}

  for name, tech in pairs(data.raw.technology) do
    if not tech.hidden then
      local signal = create_tech_signal(tech)
      table.insert(tech_signals, signal)
    end
  end

  if #tech_signals > 0 then
    log("[RAC] Signal creation summary: Created " .. #tech_signals .. " virtual signals for technologies")
  end

  data:extend(tech_signals)
end

--- Creates signals for any missing technologies (called during data-final-fixes)
function signal_module.create_missing_signals()
  -- Initialize lookup tables in case they were not initialized by create_initial_signals
  init_sci_tiers()
  init_tech_unlocks()
  init_missing_subgroups()

  local missing_signals = {}
  local signal_count = 0

  for tech_name, tech in pairs(data.raw.technology) do
    if not tech.hidden then
      local signal_name = "rac-technology-" .. tech_name

      -- Check if signal already exists
      if not data.raw["virtual-signal"][signal_name] then
        signal_count = signal_count + 1
        local signal = create_tech_signal(tech)
        table.insert(missing_signals, signal)
      end
    end
  end

  if signal_count > 0 then
    log("[RAC] data-final-fixes: Found and creating " .. signal_count .. " missing virtual signals")
    data:extend(missing_signals)
  else
    log("[RAC] data-final-fixes: All expected signals already exist, no fixes needed")
  end
end

--- Removes signals for any technologies that no longer exist (called during data-final-fixes)
function signal_module.remove_extra_signals()
  local signals_to_remove = {}
  local signal_count = 0

  for signal_name, signal in pairs(data.raw["virtual-signal"]) do
    -- Check if this is a RAC technology signal
    if string.sub(signal_name, 1, 15) == "rac-technology-" then
      -- Extract the technology name
      local tech_name = string.sub(signal_name, 16)

      -- Check if the corresponding technology exists
      if not data.raw.technology[tech_name] then
        signal_count = signal_count + 1
        table.insert(signals_to_remove, signal_name)
      end
    end
  end

  if signal_count > 0 then
    log("[RAC] data-final-fixes: Found and removing " .. signal_count .. " orphaned virtual signals")
    for _, signal_name in ipairs(signals_to_remove) do
      data.raw["virtual-signal"][signal_name] = nil
    end
  else
    log("[RAC] data-final-fixes: No orphaned signals to remove")
  end
end

--- Fixes signals with missing or invalid icon information (called during data-final-fixes)
function signal_module.fix_signal_icons()
  local placeholder_icon = {
    icon = "__base__/graphics/icons/signal/signal-science-pack.png",
    icon_size = 256,
  }

  local fixed_count = 0

  for signal_name, signal in pairs(data.raw["virtual-signal"]) do
    -- Check if this is a RAC technology signal
    if string.sub(signal_name, 1, 15) == "rac-technology-" then
      -- Check if signal has missing or empty icons
      if not signal.icons or #signal.icons == 0 then
        local tech_name = string.sub(signal_name, 16)
        local tech = data.raw.technology[tech_name]

        if tech then
          -- Try to regenerate icons from the technology
          add_signal_icons(signal, tech)

          -- If still missing icons, add placeholder
          if not signal.icons or #signal.icons == 0 then
            signal.icons = { placeholder_icon }
            fixed_count = fixed_count + 1
            log("[RAC] data-final-fixes: Added placeholder icon for signal: " .. signal_name)
          end
        end
      end
    end
  end
end

return signal_module
