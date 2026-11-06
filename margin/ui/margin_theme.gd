class_name MarginTheme
extends RefCounted

static var _theme: Theme = null

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	
	_theme = Theme.new()
	
	# Colors
	var col_bg_dark := Color(0.06, 0.08, 0.11, 0.92)
	var col_panel_bg := Color(0.09, 0.12, 0.16, 0.88)
	var col_panel_alt := Color(0.12, 0.16, 0.22, 0.90)
	var col_border := Color(0.22, 0.28, 0.36, 0.6)
	var col_border_highlight := Color(0.22, 0.74, 0.96, 0.8) # Cyan aerospace accent
	var col_text_white := Color(0.95, 0.96, 0.98, 1.0)
	var col_text_dim := Color(0.65, 0.70, 0.78, 1.0)
	var col_accent_cyan := Color(0.22, 0.74, 0.96, 1.0)
	
	# Base Panel Style
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = col_panel_bg
	panel_box.border_color = col_border
	panel_box.set_border_width_all(1)
	panel_box.set_corner_radius_all(6)
	panel_box.content_margin_left = 12
	panel_box.content_margin_right = 12
	panel_box.content_margin_top = 10
	panel_box.content_margin_bottom = 10
	_theme.set_stylebox("panel", "PanelContainer", panel_box)
	
	# Card Style
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = col_panel_alt
	card_box.border_color = col_border
	card_box.set_border_width_all(1)
	card_box.set_corner_radius_all(6)
	card_box.content_margin_left = 10
	card_box.content_margin_right = 10
	card_box.content_margin_top = 8
	card_box.content_margin_bottom = 8
	
	# Button Normal
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.16, 0.22, 0.85)
	btn_normal.border_color = Color(0.25, 0.32, 0.42, 0.7)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(4)
	btn_normal.content_margin_left = 12
	btn_normal.content_margin_right = 12
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8
	_theme.set_stylebox("normal", "Button", btn_normal)
	
	# Button Hover
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.18, 0.25, 0.35, 0.95)
	btn_hover.border_color = col_border_highlight
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(4)
	btn_hover.content_margin_left = 12
	btn_hover.content_margin_right = 12
	btn_hover.content_margin_top = 8
	btn_hover.content_margin_bottom = 8
	_theme.set_stylebox("hover", "Button", btn_hover)
	
	# Button Pressed
	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.08, 0.35, 0.52, 0.95)
	btn_pressed.border_color = col_border_highlight
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(4)
	btn_pressed.content_margin_left = 12
	btn_pressed.content_margin_right = 12
	btn_pressed.content_margin_top = 8
	btn_pressed.content_margin_bottom = 8
	_theme.set_stylebox("pressed", "Button", btn_pressed)
	
	# Button Disabled
	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.08, 0.10, 0.14, 0.5)
	btn_disabled.border_color = Color(0.16, 0.20, 0.26, 0.4)
	btn_disabled.set_border_width_all(1)
	btn_disabled.set_corner_radius_all(4)
	btn_disabled.content_margin_left = 12
	btn_disabled.content_margin_right = 12
	btn_disabled.content_margin_top = 8
	btn_disabled.content_margin_bottom = 8
	_theme.set_stylebox("disabled", "Button", btn_disabled)
	
	# Button Colors
	_theme.set_color("font_color", "Button", col_text_white)
	_theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
	_theme.set_color("font_pressed_color", "Button", col_accent_cyan)
	_theme.set_color("font_disabled_color", "Button", Color(0.4, 0.45, 0.52))
	
	# ProgressBar Background & Fill
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.08, 0.10, 0.14, 0.9)
	pb_bg.border_color = Color(0.2, 0.25, 0.32, 0.5)
	pb_bg.set_border_width_all(1)
	pb_bg.set_corner_radius_all(3)
	_theme.set_stylebox("background", "ProgressBar", pb_bg)
	
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = col_accent_cyan
	pb_fill.set_corner_radius_all(3)
	_theme.set_stylebox("fill", "ProgressBar", pb_fill)
	
	return _theme

static func create_card_style(is_equipped: bool, is_hover: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.set_corner_radius_all(6)
	
	if is_equipped:
		box.bg_color = Color(0.10, 0.20, 0.28, 0.92)
		box.border_color = Color(0.22, 0.74, 0.96, 0.9)
		box.set_border_width_all(2)
	elif is_hover:
		box.bg_color = Color(0.14, 0.18, 0.24, 0.92)
		box.border_color = Color(0.35, 0.45, 0.58, 0.8)
		box.set_border_width_all(1)
	else:
		box.bg_color = Color(0.09, 0.12, 0.16, 0.85)
		box.border_color = Color(0.20, 0.25, 0.32, 0.6)
		box.set_border_width_all(1)
	
	return box

static func create_pill_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color.r, color.g, color.b, 0.18)
	box.border_color = Color(color.r, color.g, color.b, 0.75)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box
