class_name LunarFrontierHUD
extends CanvasLayer

signal scan_initiated()
signal scan_cancelled()
signal safe_mode_chosen()
signal ignore_storm_chosen()
signal restart_requested()
signal main_menu_requested()
signal pause_toggled(paused: bool)

# UI Control references
var timer_label: Label
var objective_label: Label
var sample_count_label: Label
var battery_bar: ProgressBar
var battery_val_label: Label
var propellant_bar: ProgressBar
var propellant_val_label: Label
var integrity_bar: ProgressBar
var integrity_val_label: Label

# Scan prompt & progress
var prompt_container: PanelContainer
var prompt_label: Label
var scan_progress_bar: ProgressBar

# Warning banner
var warning_banner: PanelContainer
var warning_label: Label
var warning_timer: float = 0.0

# Modals
var storm_modal: PanelContainer
var victory_modal: PanelContainer
var failure_modal: PanelContainer
var pause_modal: PanelContainer

# Victory metrics
var victory_time_label: Label
var victory_battery_label: Label
var victory_fuel_label: Label
var victory_integrity_label: Label
var victory_grade_label: Label

# Failure reason
var failure_reason_label: Label

# Mobile touch controls
var touch_controls_root: Control
var touch_btn_boost: Button
var touch_btn_scan: Button

# Scanning state
var is_scanning_active: bool = false
var scan_progress: float = 0.0
var scan_duration: float = 1.8 # seconds to scan a sample
var _is_built: bool = false

func _ready() -> void:
	_ensure_built()

func _ensure_built() -> void:
	if _is_built:
		return
	_is_built = true
	_build_hud_layout()
	_build_modals()
	_build_touch_controls()

func _process(delta: float) -> void:
	if is_scanning_active:
		scan_progress += delta / scan_duration
		if scan_progress_bar:
			scan_progress_bar.value = clamp(scan_progress * 100.0, 0.0, 100.0)
		if scan_progress >= 1.0:
			is_scanning_active = false
			scan_progress = 0.0
			emit_signal("scan_initiated")
	
	if warning_timer > 0.0:
		warning_timer -= delta
		if warning_timer <= 0.0 and warning_banner:
			warning_banner.visible = false

# --- Public API for Game Controller ---

func update_timer(seconds_remaining: float) -> void:
	_ensure_built()
	var total_sec: int = int(ceil(max(0.0, seconds_remaining)))
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	timer_label.text = "%02d:%02d" % [mins, secs]

	if seconds_remaining < 30.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	elif seconds_remaining < 60.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	else:
		timer_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))

func update_resources(battery: float, propellant: float, integrity: float) -> void:
	_ensure_built()
	battery_bar.value = battery
	battery_val_label.text = "%d%%" % int(battery)
	if battery < 25.0:
		battery_val_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		battery_val_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))

	propellant_bar.value = propellant
	propellant_val_label.text = "%d%%" % int(propellant)

	integrity_bar.value = integrity
	integrity_val_label.text = "%d%%" % int(integrity)
	if integrity < 35.0:
		integrity_val_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		integrity_val_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))

func update_samples(count: int, total: int = 3) -> void:
	_ensure_built()
	sample_count_label.text = "SAMPLES: %d / %d" % [count, total]
	if count >= total:
		sample_count_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		objective_label.text = "OBJECTIVE: All 3 samples secured! Return to Lander Beacon to complete mission!"
		objective_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.6))
	else:
		sample_count_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		objective_label.text = "OBJECTIVE: Explore terrain and scan 3 volatile anomalies [%d/%d]" % [count, total]
		objective_label.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95))

func show_scan_prompt(target_name: String) -> void:
	_ensure_built()
	prompt_label.text = "TARGET IN RANGE: %s\nPRESS [E] TO SCAN" % target_name
	prompt_container.visible = true
	scan_progress_bar.value = 0.0

func hide_scan_prompt() -> void:
	_ensure_built()
	prompt_container.visible = false
	is_scanning_active = false
	scan_progress = 0.0
	scan_progress_bar.value = 0.0

func start_scanning() -> void:
	_ensure_built()
	if prompt_container.visible and not is_scanning_active:
		is_scanning_active = true
		scan_progress = 0.0

func cancel_scanning() -> void:
	_ensure_built()
	is_scanning_active = false
	scan_progress = 0.0
	scan_progress_bar.value = 0.0

func show_warning(msg: String, duration: float = 3.5) -> void:
	_ensure_built()
	warning_label.text = msg
	warning_banner.visible = true
	warning_timer = duration

func show_storm_event() -> void:
	_ensure_built()
	storm_modal.visible = true

func hide_storm_event() -> void:
	_ensure_built()
	storm_modal.visible = false

func show_victory(time_left: float, battery: float, fuel: float, integrity: float, grade: String) -> void:
	_ensure_built()
	victory_time_label.text = "Time Remaining: %0.1fs" % time_left
	victory_battery_label.text = "Battery Reserve: %d%%" % int(battery)
	victory_fuel_label.text = "Propellant Reserve: %d%%" % int(fuel)
	victory_integrity_label.text = "Vehicle Integrity: %d%%" % int(integrity)
	victory_grade_label.text = "GRADE: " + grade
	
	if grade == "S":
		victory_grade_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	elif grade == "A":
		victory_grade_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		victory_grade_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))

	victory_modal.visible = true

func show_failure(reason: String) -> void:
	_ensure_built()
	failure_reason_label.text = reason
	failure_modal.visible = true

func reset_hud() -> void:
	_ensure_built()
	victory_modal.visible = false
	failure_modal.visible = false
	storm_modal.visible = false
	pause_modal.visible = false
	prompt_container.visible = false
	warning_banner.visible = false
	is_scanning_active = false
	scan_progress = 0.0
	scan_progress_bar.value = 0.0
	update_timer(180.0)
	update_resources(100.0, 100.0, 100.0)
	update_samples(0, 3)

# --- HUD Visual Construction ---

func _build_hud_layout() -> void:
	var root: Control = Control.new()
	root.name = "HUD_Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. Top Telemetry Bar
	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 74.0

	var top_style: StyleBoxFlat = StyleBoxFlat.new()
	top_style.bg_color = Color(0.04, 0.06, 0.1, 0.88)
	top_style.border_color = Color(0.18, 0.28, 0.44, 0.65)
	top_style.border_width_bottom = 2
	top_style.content_margin_left = 24.0
	top_style.content_margin_right = 24.0
	top_style.content_margin_top = 10.0
	top_style.content_margin_bottom = 10.0
	top_bar.add_theme_stylebox_override("panel", top_style)
	root.add_child(top_bar)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(top_hbox)

	# Left Title Block
	var title_vbox: VBoxContainer = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_vbox)

	var title_label: Label = Label.new()
	title_label.text = "MARGIN: LUNAR FRONTIER"
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	title_vbox.add_child(title_label)

	var sub_label: Label = Label.new()
	sub_label.text = "MISSION: SHADOW RUN | LUNAR SOUTH POLE VOLATILE EXPLORATION"
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))
	title_vbox.add_child(sub_label)

	# Center Mission Timer
	var timer_vbox: VBoxContainer = VBoxContainer.new()
	timer_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(timer_vbox)

	var timer_hdr: Label = Label.new()
	timer_hdr.text = "MISSION COUNTDOWN"
	timer_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_hdr.add_theme_font_size_override("font_size", 10)
	timer_hdr.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))
	timer_vbox.add_child(timer_hdr)

	timer_label = Label.new()
	timer_label.text = "03:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 26)
	timer_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	timer_vbox.add_child(timer_label)

	# Right Samples & Pause
	var right_hbox: HBoxContainer = HBoxContainer.new()
	right_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_hbox.alignment = BoxContainer.ALIGNMENT_END
	top_hbox.add_child(right_hbox)

	sample_count_label = Label.new()
	sample_count_label.text = "SAMPLES: 0 / 3"
	sample_count_label.add_theme_font_size_override("font_size", 18)
	sample_count_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	right_hbox.add_child(sample_count_label)

	var pause_btn: Button = Button.new()
	pause_btn.text = "PAUSE"
	pause_btn.custom_minimum_size = Vector2(85, 34)
	pause_btn.pressed.connect(func(): emit_signal("pause_toggled", true))
	right_hbox.add_child(pause_btn)

	# 2. Objective Sub-Banner
	var obj_bar: PanelContainer = PanelContainer.new()
	obj_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	obj_bar.offset_top = 74.0
	obj_bar.offset_bottom = 104.0

	var obj_style: StyleBoxFlat = StyleBoxFlat.new()
	obj_style.bg_color = Color(0.02, 0.03, 0.06, 0.7)
	obj_style.content_margin_left = 24.0
	obj_style.content_margin_top = 4.0
	obj_style.content_margin_bottom = 4.0
	obj_bar.add_theme_stylebox_override("panel", obj_style)
	root.add_child(obj_bar)

	objective_label = Label.new()
	objective_label.text = "OBJECTIVE: Explore terrain and scan 3 volatile anomalies [0/3]"
	objective_label.add_theme_font_size_override("font_size", 12)
	objective_label.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95))
	obj_bar.add_child(objective_label)

	# 3. Vehicle Resource Telemetry Gauges (Bottom-Left)
	var gauges_panel: PanelContainer = PanelContainer.new()
	gauges_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	gauges_panel.offset_left = 24.0
	gauges_panel.offset_bottom = -24.0
	gauges_panel.offset_top = -145.0
	gauges_panel.offset_right = 290.0

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.1, 0.85)
	panel_style.border_color = Color(0.18, 0.28, 0.44, 0.7)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	gauges_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(gauges_panel)

	var gauges_vbox: VBoxContainer = VBoxContainer.new()
	gauges_panel.add_child(gauges_vbox)

	var gauge_title: Label = Label.new()
	gauge_title.text = "VEHICLE STATUS TELEMETRY"
	gauge_title.add_theme_font_size_override("font_size", 11)
	gauge_title.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))
	gauges_vbox.add_child(gauge_title)

	# Battery Gauge
	var batt_hbox: HBoxContainer = HBoxContainer.new()
	gauges_vbox.add_child(batt_hbox)
	var batt_lbl: Label = Label.new()
	batt_lbl.text = "BATTERY"
	batt_lbl.custom_minimum_size = Vector2(80, 0)
	batt_lbl.add_theme_font_size_override("font_size", 12)
	batt_hbox.add_child(batt_lbl)

	battery_bar = ProgressBar.new()
	battery_bar.custom_minimum_size = Vector2(110, 14)
	battery_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battery_bar.show_percentage = false
	battery_bar.value = 100.0
	batt_hbox.add_child(battery_bar)

	battery_val_label = Label.new()
	battery_val_label.text = "100%"
	battery_val_label.custom_minimum_size = Vector2(40, 0)
	battery_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battery_val_label.add_theme_font_size_override("font_size", 12)
	batt_hbox.add_child(battery_val_label)

	# Propellant Gauge
	var prop_hbox: HBoxContainer = HBoxContainer.new()
	gauges_vbox.add_child(prop_hbox)
	var prop_lbl: Label = Label.new()
	prop_lbl.text = "PROPELLANT"
	prop_lbl.custom_minimum_size = Vector2(80, 0)
	prop_lbl.add_theme_font_size_override("font_size", 12)
	prop_hbox.add_child(prop_lbl)

	propellant_bar = ProgressBar.new()
	propellant_bar.custom_minimum_size = Vector2(110, 14)
	propellant_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	propellant_bar.show_percentage = false
	propellant_bar.value = 100.0
	prop_hbox.add_child(propellant_bar)

	propellant_val_label = Label.new()
	propellant_val_label.text = "100%"
	propellant_val_label.custom_minimum_size = Vector2(40, 0)
	propellant_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	propellant_val_label.add_theme_font_size_override("font_size", 12)
	prop_hbox.add_child(propellant_val_label)

	# Hull Integrity Gauge
	var integ_hbox: HBoxContainer = HBoxContainer.new()
	gauges_vbox.add_child(integ_hbox)
	var integ_lbl: Label = Label.new()
	integ_lbl.text = "INTEGRITY"
	integ_lbl.custom_minimum_size = Vector2(80, 0)
	integ_lbl.add_theme_font_size_override("font_size", 12)
	integ_hbox.add_child(integ_lbl)

	integrity_bar = ProgressBar.new()
	integrity_bar.custom_minimum_size = Vector2(110, 14)
	integrity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	integrity_bar.show_percentage = false
	integrity_bar.value = 100.0
	integ_hbox.add_child(integrity_bar)

	integrity_val_label = Label.new()
	integrity_val_label.text = "100%"
	integrity_val_label.custom_minimum_size = Vector2(40, 0)
	integrity_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	integrity_val_label.add_theme_font_size_override("font_size", 12)
	integ_hbox.add_child(integrity_val_label)

	# 4. Contextual Interaction Prompt (Bottom-Center)
	prompt_container = PanelContainer.new()
	prompt_container.name = "InteractionPrompt"
	prompt_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_container.offset_bottom = -30.0
	prompt_container.offset_top = -120.0
	prompt_container.offset_left = -170.0
	prompt_container.offset_right = 170.0
	prompt_container.visible = false

	var prompt_style: StyleBoxFlat = StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.04, 0.08, 0.16, 0.92)
	prompt_style.border_color = Color(0.2, 0.75, 1.0, 0.9)
	prompt_style.border_width_left = 2
	prompt_style.border_width_top = 2
	prompt_style.border_width_right = 2
	prompt_style.border_width_bottom = 2
	prompt_style.corner_radius_top_left = 8
	prompt_style.corner_radius_top_right = 8
	prompt_style.corner_radius_bottom_right = 8
	prompt_style.corner_radius_bottom_left = 8
	prompt_style.content_margin_left = 18.0
	prompt_style.content_margin_right = 18.0
	prompt_style.content_margin_top = 10.0
	prompt_style.content_margin_bottom = 10.0
	prompt_container.add_theme_stylebox_override("panel", prompt_style)
	root.add_child(prompt_container)

	var prompt_vbox: VBoxContainer = VBoxContainer.new()
	prompt_container.add_child(prompt_vbox)

	prompt_label = Label.new()
	prompt_label.text = "TARGET IN RANGE\nHOLD [E] TO SCAN"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 13)
	prompt_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	prompt_vbox.add_child(prompt_label)

	scan_progress_bar = ProgressBar.new()
	scan_progress_bar.custom_minimum_size = Vector2(240, 14)
	scan_progress_bar.show_percentage = false
	scan_progress_bar.value = 0.0
	prompt_vbox.add_child(scan_progress_bar)

	# 5. Warning Alert Banner (Top-Center)
	warning_banner = PanelContainer.new()
	warning_banner.name = "WarningBanner"
	warning_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	warning_banner.offset_top = 115.0
	warning_banner.offset_bottom = 155.0
	warning_banner.offset_left = -220.0
	warning_banner.offset_right = 220.0
	warning_banner.visible = false

	var warn_style: StyleBoxFlat = StyleBoxFlat.new()
	warn_style.bg_color = Color(0.2, 0.04, 0.04, 0.9)
	warn_style.border_color = Color(1.0, 0.25, 0.25, 0.9)
	warn_style.border_width_left = 2
	warn_style.border_width_top = 2
	warn_style.border_width_right = 2
	warn_style.border_width_bottom = 2
	warn_style.corner_radius_top_left = 6
	warn_style.corner_radius_top_right = 6
	warn_style.corner_radius_bottom_right = 6
	warn_style.corner_radius_bottom_left = 6
	warn_style.content_margin_left = 16.0
	warn_style.content_margin_right = 16.0
	warn_style.content_margin_top = 6.0
	warn_style.content_margin_bottom = 6.0
	warning_banner.add_theme_stylebox_override("panel", warn_style)
	root.add_child(warning_banner)

	warning_label = Label.new()
	warning_label.text = "⚠️ WARNING: LOW BATTERY"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 13)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	warning_banner.add_child(warning_label)

# --- Modals (Solar Storm, Victory, Failure, Pause) ---

func _build_modals() -> void:
	# 1. Solar Storm Choice Modal
	storm_modal = PanelContainer.new()
	storm_modal.set_anchors_preset(Control.PRESET_CENTER)
	storm_modal.offset_left = -240.0
	storm_modal.offset_top = -140.0
	storm_modal.offset_right = 240.0
	storm_modal.offset_bottom = 140.0
	storm_modal.visible = false

	var storm_style = StyleBoxFlat.new()
	storm_style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	storm_style.border_color = Color(1.0, 0.6, 0.1, 0.95)
	storm_style.border_width_left = 2
	storm_style.border_width_top = 2
	storm_style.border_width_right = 2
	storm_style.border_width_bottom = 2
	storm_style.corner_radius_top_left = 8
	storm_style.corner_radius_top_right = 8
	storm_style.corner_radius_bottom_right = 8
	storm_style.corner_radius_bottom_left = 8
	storm_style.content_margin_left = 24.0
	storm_style.content_margin_right = 24.0
	storm_style.content_margin_top = 20.0
	storm_style.content_margin_bottom = 20.0
	storm_modal.add_theme_stylebox_override("panel", storm_style)
	add_child(storm_modal)

	var storm_vbox = VBoxContainer.new()
	storm_modal.add_child(storm_vbox)

	var storm_hdr = Label.new()
	storm_hdr.text = "[!] CORONAL MASS EJECTION EVENT"
	storm_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storm_hdr.add_theme_font_size_override("font_size", 16)
	storm_hdr.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	storm_vbox.add_child(storm_hdr)

	var storm_body = Label.new()
	storm_body.text = "A sudden solar proton storm has reached the lunar south pole. Spacecraft radiation detectors show dangerous ionization flux.\n\nSelect vehicle response protocol:"
	storm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	storm_body.add_theme_font_size_override("font_size", 12)
	storm_body.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	storm_vbox.add_child(storm_body)

	var storm_btn_hbox = HBoxContainer.new()
	storm_btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	storm_btn_hbox.custom_minimum_size = Vector2(0, 48)
	storm_vbox.add_child(storm_btn_hbox)

	var safe_btn = Button.new()
	safe_btn.text = "ENTER SAFE MODE\n(65% Speed, Immune to Radiation)"
	safe_btn.custom_minimum_size = Vector2(185, 42)
	safe_btn.pressed.connect(func():
		storm_modal.visible = false
		emit_signal("safe_mode_chosen")
	)
	storm_btn_hbox.add_child(safe_btn)

	var ignore_btn = Button.new()
	ignore_btn.text = "IGNORE WARNING\n(100% Speed, Heavy Drain/Damage)"
	ignore_btn.custom_minimum_size = Vector2(185, 42)
	ignore_btn.pressed.connect(func():
		storm_modal.visible = false
		emit_signal("ignore_storm_chosen")
	)
	storm_btn_hbox.add_child(ignore_btn)

	# 2. Victory Modal
	victory_modal = PanelContainer.new()
	victory_modal.set_anchors_preset(Control.PRESET_CENTER)
	victory_modal.offset_left = -220.0
	victory_modal.offset_top = -170.0
	victory_modal.offset_right = 220.0
	victory_modal.offset_bottom = 170.0
	victory_modal.visible = false

	var vic_style = StyleBoxFlat.new()
	vic_style.bg_color = Color(0.04, 0.08, 0.12, 0.96)
	vic_style.border_color = Color(0.2, 0.95, 0.5, 0.9)
	vic_style.border_width_left = 2
	vic_style.border_width_top = 2
	vic_style.border_width_right = 2
	vic_style.border_width_bottom = 2
	vic_style.corner_radius_top_left = 8
	vic_style.corner_radius_top_right = 8
	vic_style.corner_radius_bottom_right = 8
	vic_style.corner_radius_bottom_left = 8
	vic_style.content_margin_left = 24.0
	vic_style.content_margin_right = 24.0
	vic_style.content_margin_top = 20.0
	vic_style.content_margin_bottom = 20.0
	victory_modal.add_theme_stylebox_override("panel", vic_style)
	add_child(victory_modal)

	var vic_vbox = VBoxContainer.new()
	victory_modal.add_child(vic_vbox)

	var vic_hdr = Label.new()
	vic_hdr.text = "MISSION ACCOMPLISHED"
	vic_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vic_hdr.add_theme_font_size_override("font_size", 18)
	vic_hdr.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	vic_vbox.add_child(vic_hdr)

	var vic_sub = Label.new()
	vic_sub.text = "SHADOW RUN SUCCESSFUL — SAMPLES SECURED AT BASE"
	vic_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vic_sub.add_theme_font_size_override("font_size", 11)
	vic_sub.add_theme_color_override("font_color", Color(0.7, 0.85, 0.8))
	vic_vbox.add_child(vic_sub)

	victory_grade_label = Label.new()
	victory_grade_label.text = "GRADE: A"
	victory_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_grade_label.add_theme_font_size_override("font_size", 28)
	victory_grade_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vic_vbox.add_child(victory_grade_label)

	victory_time_label = Label.new()
	victory_time_label.text = "Time Remaining: 65.0s"
	victory_time_label.add_theme_font_size_override("font_size", 12)
	vic_vbox.add_child(victory_time_label)

	victory_battery_label = Label.new()
	victory_battery_label.text = "Battery Reserve: 45%"
	victory_battery_label.add_theme_font_size_override("font_size", 12)
	vic_vbox.add_child(victory_battery_label)

	victory_fuel_label = Label.new()
	victory_fuel_label.text = "Propellant Reserve: 38%"
	victory_fuel_label.add_theme_font_size_override("font_size", 12)
	vic_vbox.add_child(victory_fuel_label)

	victory_integrity_label = Label.new()
	victory_integrity_label.text = "Vehicle Integrity: 88%"
	victory_integrity_label.add_theme_font_size_override("font_size", 12)
	vic_vbox.add_child(victory_integrity_label)

	var vic_btns = HBoxContainer.new()
	vic_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vic_vbox.add_child(vic_btns)

	var play_again_btn = Button.new()
	play_again_btn.text = "PLAY AGAIN"
	play_again_btn.custom_minimum_size = Vector2(130, 36)
	play_again_btn.pressed.connect(func(): emit_signal("restart_requested"))
	vic_btns.add_child(play_again_btn)

	var menu_btn = Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(130, 36)
	menu_btn.pressed.connect(func(): emit_signal("main_menu_requested"))
	vic_btns.add_child(menu_btn)

	# 3. Failure Modal
	failure_modal = PanelContainer.new()
	failure_modal.set_anchors_preset(Control.PRESET_CENTER)
	failure_modal.offset_left = -220.0
	failure_modal.offset_top = -140.0
	failure_modal.offset_right = 220.0
	failure_modal.offset_bottom = 140.0
	failure_modal.visible = false

	var fail_style = StyleBoxFlat.new()
	fail_style.bg_color = Color(0.12, 0.04, 0.04, 0.96)
	fail_style.border_color = Color(1.0, 0.25, 0.25, 0.9)
	fail_style.border_width_left = 2
	fail_style.border_width_top = 2
	fail_style.border_width_right = 2
	fail_style.border_width_bottom = 2
	fail_style.corner_radius_top_left = 8
	fail_style.corner_radius_top_right = 8
	fail_style.corner_radius_bottom_right = 8
	fail_style.corner_radius_bottom_left = 8
	fail_style.content_margin_left = 24.0
	fail_style.content_margin_right = 24.0
	fail_style.content_margin_top = 20.0
	fail_style.content_margin_bottom = 20.0
	failure_modal.add_theme_stylebox_override("panel", fail_style)
	add_child(failure_modal)

	var fail_vbox = VBoxContainer.new()
	failure_modal.add_child(fail_vbox)

	var fail_hdr = Label.new()
	fail_hdr.text = "MISSION TERMINATED"
	fail_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fail_hdr.add_theme_font_size_override("font_size", 18)
	fail_hdr.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	fail_vbox.add_child(fail_hdr)

	failure_reason_label = Label.new()
	failure_reason_label.text = "CRITICAL BATTERY DEPLETION"
	failure_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	failure_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_reason_label.add_theme_font_size_override("font_size", 12)
	failure_reason_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8))
	fail_vbox.add_child(failure_reason_label)

	var fail_btns = HBoxContainer.new()
	fail_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	fail_btns.custom_minimum_size = Vector2(0, 48)
	fail_vbox.add_child(fail_btns)

	var retry_btn = Button.new()
	retry_btn.text = "RETRY MISSION"
	retry_btn.custom_minimum_size = Vector2(130, 36)
	retry_btn.pressed.connect(func(): emit_signal("restart_requested"))
	fail_btns.add_child(retry_btn)

	var fail_menu_btn = Button.new()
	fail_menu_btn.text = "MAIN MENU"
	fail_menu_btn.custom_minimum_size = Vector2(130, 36)
	fail_menu_btn.pressed.connect(func(): emit_signal("main_menu_requested"))
	fail_btns.add_child(fail_menu_btn)

	# 4. Pause Modal
	pause_modal = PanelContainer.new()
	pause_modal.set_anchors_preset(Control.PRESET_CENTER)
	pause_modal.offset_left = -160.0
	pause_modal.offset_top = -110.0
	pause_modal.offset_right = 160.0
	pause_modal.offset_bottom = 110.0
	pause_modal.visible = false

	var pause_style = StyleBoxFlat.new()
	pause_style.bg_color = Color(0.04, 0.06, 0.1, 0.96)
	pause_style.border_color = Color(0.25, 0.45, 0.7, 0.8)
	pause_style.border_width_left = 2
	pause_style.border_width_top = 2
	pause_style.border_width_right = 2
	pause_style.border_width_bottom = 2
	pause_style.corner_radius_top_left = 8
	pause_style.corner_radius_top_right = 8
	pause_style.corner_radius_bottom_right = 8
	pause_style.corner_radius_bottom_left = 8
	pause_style.content_margin_left = 20.0
	pause_style.content_margin_right = 20.0
	pause_style.content_margin_top = 18.0
	pause_style.content_margin_bottom = 18.0
	pause_modal.add_theme_stylebox_override("panel", pause_style)
	add_child(pause_modal)

	var pause_vbox = VBoxContainer.new()
	pause_modal.add_child(pause_vbox)

	var pause_hdr = Label.new()
	pause_hdr.text = "MISSION PAUSED"
	pause_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hdr.add_theme_font_size_override("font_size", 16)
	pause_hdr.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	pause_vbox.add_child(pause_hdr)

	var resume_btn = Button.new()
	resume_btn.text = "RESUME FLIGHT"
	resume_btn.custom_minimum_size = Vector2(180, 32)
	resume_btn.pressed.connect(func():
		pause_modal.visible = false
		emit_signal("pause_toggled", false)
	)
	pause_vbox.add_child(resume_btn)

	var pause_restart_btn = Button.new()
	pause_restart_btn.text = "RESTART MISSION"
	pause_restart_btn.custom_minimum_size = Vector2(180, 32)
	pause_restart_btn.pressed.connect(func(): emit_signal("restart_requested"))
	pause_vbox.add_child(pause_restart_btn)

	var pause_menu_btn = Button.new()
	pause_menu_btn.text = "EXIT TO MAIN MENU"
	pause_menu_btn.custom_minimum_size = Vector2(180, 32)
	pause_menu_btn.pressed.connect(func(): emit_signal("main_menu_requested"))
	pause_vbox.add_child(pause_menu_btn)

# --- Mobile Touch Controls ---

func _build_touch_controls() -> void:
	touch_controls_root = Control.new()
	touch_controls_root.name = "TouchControls"
	touch_controls_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_controls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(touch_controls_root)

	var dpad_container = Control.new()
	dpad_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	dpad_container.offset_left = 320.0
	dpad_container.offset_bottom = -24.0
	dpad_container.offset_top = -145.0
	dpad_container.offset_right = 470.0
	touch_controls_root.add_child(dpad_container)

	var btn_fwd = Button.new()
	btn_fwd.text = "▲"
	btn_fwd.position = Vector2(50, 0)
	btn_fwd.custom_minimum_size = Vector2(45, 38)
	dpad_container.add_child(btn_fwd)

	var btn_back = Button.new()
	btn_back.text = "▼"
	btn_back.position = Vector2(50, 80)
	btn_back.custom_minimum_size = Vector2(45, 38)
	dpad_container.add_child(btn_back)

	var btn_left = Button.new()
	btn_left.text = "◀"
	btn_left.position = Vector2(0, 40)
	btn_left.custom_minimum_size = Vector2(45, 38)
	dpad_container.add_child(btn_left)

	var btn_right = Button.new()
	btn_right.text = "▶"
	btn_right.position = Vector2(100, 40)
	btn_right.custom_minimum_size = Vector2(45, 38)
	dpad_container.add_child(btn_right)

	var actions_container = Control.new()
	actions_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions_container.offset_right = -24.0
	actions_container.offset_bottom = -24.0
	actions_container.offset_top = -145.0
	actions_container.offset_left = -160.0
	touch_controls_root.add_child(actions_container)

	touch_btn_boost = Button.new()
	touch_btn_boost.text = "BOOST"
	touch_btn_boost.position = Vector2(0, 10)
	touch_btn_boost.custom_minimum_size = Vector2(130, 45)
	actions_container.add_child(touch_btn_boost)

	touch_btn_scan = Button.new()
	touch_btn_scan.text = "SCAN"
	touch_btn_scan.position = Vector2(0, 65)
	touch_btn_scan.custom_minimum_size = Vector2(130, 45)
	actions_container.add_child(touch_btn_scan)

	btn_fwd.button_down.connect(func(): _set_virtual_key(KEY_W, true))
	btn_fwd.button_up.connect(func(): _set_virtual_key(KEY_W, false))
	btn_back.button_down.connect(func(): _set_virtual_key(KEY_S, true))
	btn_back.button_up.connect(func(): _set_virtual_key(KEY_S, false))
	btn_left.button_down.connect(func(): _set_virtual_key(KEY_A, true))
	btn_left.button_up.connect(func(): _set_virtual_key(KEY_A, false))
	btn_right.button_down.connect(func(): _set_virtual_key(KEY_D, true))
	btn_right.button_up.connect(func(): _set_virtual_key(KEY_D, false))

	touch_btn_boost.button_down.connect(func(): _set_virtual_key(KEY_SPACE, true))
	touch_btn_boost.button_up.connect(func(): _set_virtual_key(KEY_SPACE, false))
	touch_btn_scan.button_down.connect(func(): _set_virtual_key(KEY_E, true))
	touch_btn_scan.button_up.connect(func(): _set_virtual_key(KEY_E, false))

func _set_virtual_key(keycode: Key, pressed: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
