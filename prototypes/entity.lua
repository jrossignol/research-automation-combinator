---@type data.DeciderCombinatorPrototype
local combinator = table.deepcopy(data.raw["decider-combinator"]["decider-combinator"])
combinator.name = "research-automation-combinator"
combinator.icons = data.raw.item["research-automation-combinator"].icons
combinator.icon = nil
combinator.minable.result = "research-automation-combinator"
combinator.fast_replaceable_group = "research-automation-combinator"
combinator.icon_size = nil
if combinator.sprites.sheets then
  for _, sheet in ipairs(combinator.sprites.sheets) do
    sheet.tint = { 66, 206, 245, 255 }
  end
elseif combinator.sprites.sheet then
  combinator.sprites.sheet.tint = { 66, 206, 245, 255 }
else
  combinator.sprites.north.tint = { 66, 206, 245, 255 }
  combinator.sprites.east.tint = { 66, 206, 245, 255 }
  combinator.sprites.south.tint = { 66, 206, 245, 255 }
  combinator.sprites.west.tint = { 66, 206, 245, 255 }
end

-- Hide the default alt-info from the decider combinator
combinator.flags = combinator.flags or {}
table.insert(combinator.flags, ("hide-alt-info"))

data:extend({combinator})