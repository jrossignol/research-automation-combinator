---@type data.ItemPrototype
local item = table.deepcopy(data.raw.item["decider-combinator"])
item.name = "research-automation-combinator"
item.place_result = "research-automation-combinator"
item.order = "c[combinators]-c[research-automation-combinator]"
item.icons = {
  {
    icon = item.icon,
    icon_size = 64,
    tint = { 66, 206, 245, 255 },
  }
}
item.icon = nil
item.icon_size = nil

data:extend({item})