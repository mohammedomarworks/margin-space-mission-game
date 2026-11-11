class_name ObjectiveBanner
extends PanelContainer

# ==============================================================================
# MARGIN — ACTIVE OBJECTIVE HUD BANNER
# Prominent top-centre banner that always tells the player exactly what to do
# next: "STEP 2 / 4", the instruction, and a glowing action button bound to a
# keyboard shortcut. Emits action_pressed when the player commits.
#
# The banner is deliberately loud: this is the fix for "players get confused
# after launch". There is never a moment where the game does not say what the
# next action is.
# ==============================================================================

signal action_pressed

var _step_label: Label = null
var _title_label: Label = null
var _hint_label: Label = null
var _action_btn: Button = null
var _pulse_tween: Tween = null
var _current_step: int = 0
var _current_total: int = 4


func _ready() -> void:
	theme = MarginTheme.get_theme()
	_build()


func _build() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.14, 0.94)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.30, 0.75, 1.0)
	sb.set_content_margin_all(8)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(top)

	_step_label = Label.new()
	_step_label.name = "ObjectiveStepLabel"
	_step_label.text = "STEP 1 / 4"
	_step_label.add_theme_font_size_override("font_size", 13)
	_step_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	top.add_child(_step_label)

	_title_label = Label.new()
	_title_label.name = "ObjectiveTitleLabel"
	_title_label.text = "PREPARE FOR LAUNCH"
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0))
	top.add_child(_title_label)

	_action_btn = Button.new()
	_action_btn.name = "ObjectiveActionBtn"
	_action_btn.text = "▶ START"
	_action_btn.custom_minimum_size = Vector2(0, 34)
	_action_btn.add_theme_font_size_override("font_size", 14)
	_action_btn.focus_mode = Control.FOCUS_NONE
	_action_btn.pressed.connect(func() -> void:
		Sfx.ui_click()
		action_pressed.emit()
	)
	vb.add_child(_action_btn)

	_hint_label = Label.new()
	_hint_label.name = "ObjectiveHintLabel"
	_hint_label.text = "Press [SPACE] to continue"
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.add_theme_color_override("font_color", Color(0.60, 0.74, 0.88))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_hint_label)


# step is 1-based; total is the number of steps in this stage.
func set_objective(step: int, total: int, title: String, action_text: String,
		hint: String = "", accent: Color = Color(0.30, 0.75, 1.0)) -> void:
	_current_step = step
	_current_total = total

	if _step_label:
		_step_label.text = "STEP %d / %d" % [step, total]
	if _title_label:
		_title_label.text = title
	if _action_btn:
		_action_btn.text = action_text
		_action_btn.visible = action_text != ""
	if _hint_label:
		_hint_label.text = hint
		_hint_label.visible = hint != ""

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.14, 0.94)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = accent
	sb.set_content_margin_all(8)
	add_theme_stylebox_override("panel", sb)

	# Pulse the action button so the eye lands on it immediately
	if _action_btn and _action_btn.visible:
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill()
		_action_btn.modulate = Color(1, 1, 1, 1)
		_pulse_tween = create_tween()
		_pulse_tween.set_loops()
		_pulse_tween.tween_property(_action_btn, "modulate",
			Color(accent.r * 1.3, accent.g * 1.3, accent.b * 1.3, 1.0), 0.55)
		_pulse_tween.tween_property(_action_btn, "modulate",
			Color(1, 1, 1, 0.92), 0.55)


func set_action_enabled(enabled: bool) -> void:
	if _action_btn:
		_action_btn.disabled = not enabled


func get_action_button() -> Button:
	return _action_btn


func get_step() -> int:
	return _current_step
