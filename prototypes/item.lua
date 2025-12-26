---@type data.ItemPrototype
local item = table.deepcopy(data.raw.item["decider-combinator"])
item.name = "research-automation-combinator"
item.place_result = "research-automation-combinator"
item.order = "c[combinators]-c[research-automation-combinator]"
item.icon = "__research-automation-combinator__/graphics/icons/research-automation-combinator.png"
item.icon_size = 64

data:extend({item})