--- Update from output_current_research boolean to output_research_mode integer
if storage.research_combinators then
  for _, rac in pairs(storage.research_combinators) do
    if rac.output_current_research ~= nil then
      -- Set output_research_mode to match the previous output_current_research
      rac.output_research_mode = rac.output_current_research and OUTPUT_RESEARCH_MODE.CURRENT or OUTPUT_RESEARCH_MODE.NONE
      -- Remove the old output_current_research value
      rac.output_current_research = nil
    end
  end
end
