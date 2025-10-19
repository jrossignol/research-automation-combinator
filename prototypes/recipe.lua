---@type data.TechnologyPrototype?
local tech = data.raw.technology["circuit-network"]
if tech then
  tech.effects[#tech.effects+1] = {
    type = "unlock-recipe",
    recipe = "research-automation-combinator"
  }
end

---@type data.RecipePrototype
local recipe = table.deepcopy(data.raw.recipe["decider-combinator"])
recipe.name = "research-automation-combinator"
recipe.results = {{type="item", name="research-automation-combinator", amount=1}}

data:extend({recipe})