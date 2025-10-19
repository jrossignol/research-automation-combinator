-- Helper function to generate an icon for a digit
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

-- Helper function to generate all the icons for a tech signal
local function signal_icons(tech, tech_basename, level)
  -- Need to pull the initial icon either from the top of icons array or the icon field.
  local icons = {
    {
      icon = tech.icon or tech.icons[1].icon,
      icon_size = tech.icon_size or tech.icons[1].icon_size,
      tint = tech.icons and tech.icons[1].tint
    },
  }

  -- Handle techs with a more icons (infinite techs have a small sub-icon, or
  -- mods might use a tint layer).
  for i, orig_icon in ipairs(tech.icons or {}) do
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
    table.insert(icons, icon)
  end

  -- Special handling for infinite techs
  if tech.max_level == "infinite" then
    table.insert(icons, signal_digit_icon(tech.max_level))
  -- Add numeric identifier for techs with level, but which do not have a named
  -- tech without a level (this stops us from adding digits to the module techs)
  elseif level and tech.upgrade and not data.raw["technology"][tech_basename] then
    -- TODO: Need to properly handle values greater than 9.  For now, just use
    -- the infinite icon for those.
    table.insert(icons, signal_digit_icon(tonumber(level) < 10 and level or "infinite"))
  end

  return icons
end


-- Helper function for creating a subgroup
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

-- Make a quick lookup table of science pack "tiers" (just base it on their
-- sort order).  Also while we're here - create a subgroup for each to give some
-- sorting to the signals.
local sci_tiers = {}
local i = 0
for name, tool in pairs(data.raw.tool) do
  i = i + 1
  sci_tiers[name] = i
  subgroup(string.format("%03d", i))
end
-- Add fallback subgroups at the start and end
subgroup("000")
subgroup("999")


-- Make a reverse lookup tech table - will use this in determining how to group tech signals.
local tech_unlocks = {}
for name, tech in pairs(data.raw.technology) do
  for i, ptech in ipairs(tech.prerequisites or {}) do
    tech_unlocks[ptech] = tech_unlocks[ptech] or {}
    table.insert(tech_unlocks[ptech], name)
  end
end

-- Helper function for determining the "tier" of a tech
local tech_tiers = {}
local function tech_tier(tech)
  -- Check cache first
  log("determine tech tier of " .. tech.name)
  if not tech_tiers[tech.name] then
    -- Determine the highest tier science pack required
    local sci_tier = 0
    for i, ri in ipairs(tech.unit and tech.unit.ingredients or {}) do
      sci_tier = sci_tiers[ri[1]] > sci_tier and sci_tiers[ri[1]] or sci_tier
    end

    -- If the tier is zero then this may be a triggered tech
    if sci_tier == 0 and tech.research_trigger then
      sci_tier = 999 -- Assume max tier
      for i, dtech in ipairs(tech_unlocks[tech.name] or {}) do
        -- Recursion - Factorio won't allow a tech dependency loop...  right?
        dtech_tier = tech_tier(data.raw.technology[dtech])
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
      for i, ptech in ipairs(tech.prerequisites or {}) do
        ptech_tier = tech_tier(data.raw.technology[ptech])
        sci_tier = sci_tier < ptech_tier and sci_tier or ptech_tier
      end

      -- Reassign the tier to the cache (hopefully it changed)
      tech_tiers[tech.name] = sci_tier
    end

  end

  return tech_tiers[tech.name]
end


-- Create a signal for each technology
local tech_signals = {}
for name, tech in pairs(data.raw.technology) do
  if not tech.hidden then
    local signal = {
      type = "virtual-signal",
      name = "rac-technology-" .. tech.name,
      icons = signal_icons(tech),
      techID = tech.name
    }

    -- Need to remove the numbers from localised names.  While we're doing
    -- that, use different strings to build the names of infinite and non-infinite
    -- repeating techs.
    local tech_basename, tech_level = string.match(tech.name, "(%g+)-(%d+)")
    if not tech_basename then
      -- Reference localised names of technology for the signal names
      signal.localised_name = { "technology-name." .. tech.name }
      signal.localised_description = { "technology-description." .. tech.name }

      -- Set icons
      signal.icons = signal_icons(tech)
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

      -- Set icons with level
      signal.icons = signal_icons(tech, tech_basename, tech_level)
    end

    -- Determine the tier of this tech
    local sci_tier = tech_tier(tech)

    -- Check if this tech is one that unlocks a science pack, and instead move
    -- the tech to that subgroup for the science pack
    for i, mod in ipairs(tech.effects or {}) do
      if mod.type == "unlock-recipe" then
        local recipe = data.raw.recipe[mod.recipe]
        for j, prod in ipairs(recipe.results) do
          if prod.type == "item" and sci_tiers[prod.name] then
            sci_tier = sci_tiers[prod.name]
            signal.order = "a"
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
          pack_str = pack_str .. "-" .. string.format("%02d", sci_tiers[ri[1]])
        end
        signal.order = "c" .. pack_str
      end

      -- Add the name for final ordering
      signal.order = signal.order .. "-" .. tech.name
    end

    -- Tier determines the subgroup
    signal.subgroup = string.format("rac-technology-%03d", sci_tier)

    -- Add to our signal list
    tech_signals[#tech_signals+1] = signal
  end
end

data:extend(tech_signals)
