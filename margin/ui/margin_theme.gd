class_name MarginTheme
extends RefCounted

static var _theme: Theme = null

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	
	_theme = Theme.new()
	
	# Colors
	var col_bg_dark := Color(0.03, 0.055, 0.10, 0.92)
	var col_panel_bg := Color(0.0314, 0.0549, 0.1020, 0.85) # rgba(8, 14, 26, 0.85)
	var col_panel_alt := Color(0.055, 0.085, 0.14, 0.90)
	var col_border := Color(0.22, 0.74, 0.96, 0.62)
	var col_border_highlight := Color(0.22, 0.74, 0.96, 0.8) # Cyan aerospace accent
	var col_text_white := Color(0.95, 0.96, 0.98, 1.0)
	var col_text_dim := Color(0.65, 0.70, 0.78, 1.0)
	var col_accent_cyan := Color(0.22, 0.74, 0.96, 1.0)
	_theme.set_color("font_shadow_color", "Label", Color(0.005, 0.012, 0.028, 0.96))
	_theme.set_constant("shadow_offset_x", "Label", 1)
	_theme.set_constant("shadow_offset_y", "Label", 1)
	_theme.set_constant("shadow_outline_size", "Label", 1)
	
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

static func apply_interactive_polish(root: Node) -> void:
	if root == null:
		return
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		for child in node.get_children():
			queue.append(child)
		if node is Label or node is HSeparator or node is VSeparator:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif node is PanelContainer:
			var nm: String = node.name
			if (nm.contains("Banner") or nm.contains("Badge") or nm.contains("BuildBadge")) and not _has_interactive_descendant(node):
				(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif node is BaseButton:
			_polish_button(node as BaseButton)

static func _has_interactive_descendant(root: Node) -> bool:
	for child in root.get_children():
		if child is BaseButton or child is LineEdit or child is OptionButton or child is Slider:
			return true
		if _has_interactive_descendant(child):
			return true
	return false

static func _polish_button(btn: BaseButton) -> void:
	if btn == null:
		return
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if btn is Button and not (btn is CheckBox) and not (btn is OptionButton):
		if btn.has_theme_stylebox_override("normal") and not btn.has_theme_stylebox_override("hover"):
			var norm_box := btn.get_theme_stylebox("normal")
			if norm_box is StyleBoxFlat:
				var flat := norm_box as StyleBoxFlat
				var hover_box := flat.duplicate() as StyleBoxFlat
				hover_box.bg_color = Color(
					clampf(flat.bg_color.r + 0.08, 0.0, 1.0),
					clampf(flat.bg_color.g + 0.10, 0.0, 1.0),
					clampf(flat.bg_color.b + 0.14, 0.0, 1.0),
					clampf(maxf(flat.bg_color.a, 0.85) + 0.05, 0.0, 1.0)
				)
				hover_box.border_color = flat.border_color.lerp(Color(0.35, 0.92, 1.0, 1.0), 0.6)
				hover_box.set_border_width_all(maxi(1, flat.border_width_left))
				btn.add_theme_stylebox_override("hover", hover_box)
				if not btn.has_theme_stylebox_override("pressed"):
					var pressed_box := flat.duplicate() as StyleBoxFlat
					pressed_box.bg_color = Color(
						clampf(flat.bg_color.r * 0.72, 0.02, 1.0),
						clampf(flat.bg_color.g + 0.04, 0.04, 1.0),
						clampf(flat.bg_color.b + 0.12, 0.08, 1.0),
						0.96
					)
					pressed_box.border_color = Color(0.35, 0.95, 1.0, 1.0)
					pressed_box.set_border_width_all(maxi(2, flat.border_width_left))
					btn.add_theme_stylebox_override("pressed", pressed_box)
	if btn.has_meta("_margin_polish_wired"):
		return
	btn.set_meta("_margin_polish_wired", true)
	btn.mouse_entered.connect(func():
		if is_instance_valid(btn) and not btn.disabled:
			_tween_btn_modulate(btn, Color(1.07, 1.10, 1.15, 1.0), 0.09)
	)
	btn.mouse_exited.connect(func():
		if is_instance_valid(btn):
			_tween_btn_modulate(btn, Color.WHITE, 0.12)
	)
	btn.button_down.connect(func():
		if is_instance_valid(btn) and not btn.disabled:
			_tween_btn_modulate(btn, Color(0.84, 0.93, 1.0, 1.0), 0.06)
	)
	btn.button_up.connect(func():
		if is_instance_valid(btn) and not btn.disabled:
			var target_col: Color = Color(1.07, 1.10, 1.15, 1.0) if btn.is_hovered() else Color.WHITE
			_tween_btn_modulate(btn, target_col, 0.09)
	)

static func _tween_btn_modulate(btn: BaseButton, target: Color, dur: float) -> void:
	if not btn.is_inside_tree():
		btn.self_modulate = target
		return
	if btn.has_meta("_polish_tween"):
		var prev = btn.get_meta("_polish_tween")
		if prev is Tween and prev.is_valid():
			prev.kill()
	var tw := btn.create_tween()
	tw.tween_property(btn, "self_modulate", target, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	btn.set_meta("_polish_tween", tw)

static func build_perk_badge_label(perk: Dictionary) -> Label:
	var lbl := Label.new()
	lbl.name = "TeamPerkBadge"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = str(perk.get("badge_text", "LEAD: PROPULSION"))
	lbl.tooltip_text = str(perk.get("summary", ""))
	var col: Color = perk.get("color", Color(0.25, 0.78, 1.0))
	lbl.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.25))
	lbl.add_theme_font_size_override("font_size", 10)
	return lbl
