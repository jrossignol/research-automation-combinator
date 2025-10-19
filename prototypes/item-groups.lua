-- Use the research productivity sprite if we can, otherwise just chemical science will do
local sprite = data.raw.technology["research-productivity"] and "__space-age__/graphics/technology/research-productivity.png" or "__base__/graphics/technology/chemical-science-pack.png"

-- Create a new item group for technology signals
data:extend({
  {
    type = "item-group",
    name = "rac-technology",
    order = "s",
    icons = {
      {
        icon = sprite,
        icon_size = 256,
      },
    },
  },
})
