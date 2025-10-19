local styles = data.raw["gui-style"].default

styles.rac_hflow_center = {
  type = "horizontal_flow_style",
  vertical_align = "center",
}

styles.rac_subheader_frame = {
  type = "frame_style",
  parent = "subheader_frame",
  horizontally_stretchable = "on",
}

styles.rac_horizontal_pusher = {
  type = "empty_widget_style",
  horizontally_stretchable = "on",
}