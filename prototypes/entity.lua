---@type data.DeciderCombinatorPrototype
local combinator = table.deepcopy(data.raw["decider-combinator"]["decider-combinator"])
combinator.name = "research-automation-combinator"
combinator.icons = data.raw.item["research-automation-combinator"].icons
combinator.icon = data.raw.item["research-automation-combinator"].icon
combinator.minable.result = "research-automation-combinator"
combinator.fast_replaceable_group = "research-automation-combinator"

-- Use custom sprites with tinting
if combinator.sprites.sheets then
  log("[RAC] Setting multiple sheet sprites for research-automation-combinator")
  for _, sheet in ipairs(combinator.sprites.sheets) do
    sheet.filename = "__research-automation-combinator__/graphics/entity/research-automation-combinator.png"
  end
elseif combinator.sprites.sheet then
  log("[RAC] Setting single sheet sprite for research-automation-combinator")
  combinator.sprites.sheet.filename = "__research-automation-combinator__/graphics/entity/research-automation-combinator.png"
else
  log("[RAC] Setting individual direction sprites for research-automation-combinator")
  combinator.sprites.north.layers[1].filename = "__research-automation-combinator__/graphics/entity/research-automation-combinator.png"
  combinator.sprites.east.layers[1].filename = "__research-automation-combinator__/graphics/entity/research-automation-combinator.png"
  combinator.sprites.south.layers[1].filename = "__research-automation-combinator__/graphics/entity/research-automation-combinator.png"
  combinator.sprites.west.layers[1].filename = "__research-automation-combinator__/graphics/entity/research-automation-combinator.png"
end

-- Hide the default alt-info from the decider combinator
combinator.flags = combinator.flags or {}
table.insert(combinator.flags, ("hide-alt-info"))

-- Set the less symbol sprites to the display sprite
combinator.less_symbol_sprites.east.filename = "__research-automation-combinator__/graphics/entity/rac-display.png"
combinator.less_symbol_sprites.east.x = 0
combinator.less_symbol_sprites.east.y = 0
combinator.less_symbol_sprites.west.filename = "__research-automation-combinator__/graphics/entity/rac-display.png"
combinator.less_symbol_sprites.west.x = 0
combinator.less_symbol_sprites.west.y = 0
combinator.less_symbol_sprites.north.filename = "__research-automation-combinator__/graphics/entity/rac-display.png"
combinator.less_symbol_sprites.north.x = 0
combinator.less_symbol_sprites.north.y = 0
combinator.less_symbol_sprites.south.filename = "__research-automation-combinator__/graphics/entity/rac-display.png"
combinator.less_symbol_sprites.south.x = 0
combinator.less_symbol_sprites.south.y = 0

-- Set the rest of the symbol sprites to match
combinator.equal_symbol_sprites = combinator.less_symbol_sprites
combinator.greater_symbol_sprites = combinator.less_symbol_sprites
combinator.not_equal_symbol_sprites = combinator.less_symbol_sprites
combinator.less_or_equal_symbol_sprites = combinator.less_symbol_sprites
combinator.greater_or_equal_symbol_sprites = combinator.less_symbol_sprites

data:extend({combinator})