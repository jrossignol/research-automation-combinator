function register_picker_dollies()
  if remote.interfaces["PickerDollies"] then
      remote.call("PickerDollies", "add_oblong_name", "research-automation-combinator")
  end
end