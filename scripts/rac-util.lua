function sorted_iter(t)
  local i = {}
  for k in next, t do
    table.insert(i, k)
  end
  table.sort(i, function(a,b) return a > b end)
  return function()
    local k = table.remove(i)
    if k ~= nil then
      return k, t[k]
    end
  end
end