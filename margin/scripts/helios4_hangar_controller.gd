class_name Helios4HangarController
extends Node3D

# ==============================================================================
# MARGIN: HELIOS-4 CINEMATIC ASSEMBLY HANGAR CONTROLLER
# Implements reference-driven interactive 3D engineering (01_helios4_hangar.png):
# - 360-degree free orbit and zoom camera around central launch vehicle
# - Direct component inventory selection with 3D camera focusing & holographic callouts
# - Dynamic live telemetry: Mass, Delta-V, TWR, Aerodynamic Static Margin, Power, Budget
# - 4 Specialist Role Workstations matching bottom cards (Propulsion, Structural, Astrogator, Systems)
# - Interactive hardware configuration: Engines, Propellant load, Grid fins, Bus structure, Solar area, Avionics
# - Zero emoji tofu: all icons drawn procedurally with Helios4HUDWidgets!
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const Helios4Rocket3D = preload("res://margin/scripts/helios4_rocket_3d.gd")
const Helios4HUDWidgets = preload("res://margin/scripts/helios4_hud_widgets.gd")

@onready var rocket_3d: Helios4Rocket3D = %Rocket3D
@onready var orbit_cam: Camera3D = %HangarCamera

# Active Workstation Role
var active_role: String = Helios4CampaignData.ROLE_PROPULSION
var active_component_id: String = "stage1_engine"

# Camera Orbit State (Default cinematic 3/4 angle)
var _cam_yaw: float = 20.0
var _cam_pitch: float = 6.0
var _cam_distance: float = 17.5
var _cam_target: Vector3 = Vector3(0.0, 7.5, 0.0)
var _is_dragging: bool = false
var _is_right_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

# Timer State
var time_remaining: float = 600.0

# Telemetry Cache
var current_telemetry: Dictionary = {}

# Custom Procedural HUD Widgets
var dial_gauge: Helios4HUDWidgets.DialGauge = null
var radar_widget: Helios4HUDWidgets.RadarScope = null
var sparkline_aero: Helios4HUDWidgets.SparklineWave = null
var sparkline_power: Helios4HUDWidgets.SparklineWave = null
var readiness_bars: Helios4HUDWidgets.ReadinessBars = null
var destination_checklist: DestinationChecklist = null
var scratch_builder: ScratchBuilder = null

func _ready() -> void:
	var hangar_ui := find_child("RootUI", true, false) as Control
	if hangar_ui:
		hangar_ui.theme = MarginTheme.get_theme()
	if Helios4CampaignData.vehicle_config.is_empty():
		Helios4CampaignData.vehicle_config = Helios4CampaignData.get_default_vehicle_config()
	if Helios4CampaignData.probe_config.is_empty():
		Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()

	time_remaining = Helios4CampaignData.hangar_time_remaining
	active_role = Helios4CampaignData.active_role

	_setup_procedural_widgets()
	_setup_destination_checklist()
	_setup_scratch_builder()
	_setup_inventory_grid()
	_connect_ui_signals()
	_switch_role(active_role)
	_setup_team_perk_badge()
	_update_camera_transform()
	_recalculate_and_refresh_ui()
	if hangar_ui:
		MarginTheme.apply_interactive_polish(hangar_ui)
		Sfx.attach_hud_toggle(hangar_ui)

	# Print UI coordinates for automated QA and CDP browser verification
	get_tree().process_frame.connect(func():
		var btn = find_child("ProceedToFRRBtn", true, false)
		if btn: print("[Hangar] ProceedToFRRBtn global_rect: ", btn.get_global_rect(), " center: ", btn.get_global_rect().get_center())
		var tab_prop = find_child("TabPropulsion", true, false)
		if tab_prop: print("[Hangar] TabPropulsion center: ", tab_prop.get_global_rect().get_center())
		var tab_struct = find_child("TabStructural", true, false)
		if tab_struct: print("[Hangar] TabStructural center: ", tab_struct.get_global_rect().get_center())
		var tab_astro = find_child("TabAstrogator", true, false)
		if tab_astro: print("[Hangar] TabAstrogator center: ", tab_astro.get_global_rect().get_center())
		var tab_sys = find_child("TabSystems", true, false)
		if tab_sys: print("[Hangar] TabSystems center: ", tab_sys.get_global_rect().get_center())
		var btn_probe = find_child("FocusProbeBtn", true, false)
		if btn_probe: print("[Hangar] FocusProbeBtn center: ", btn_probe.get_global_rect().get_center())
		var btn_eng = find_child("InvBtn_stage1_engine", true, false)
		if btn_eng: print("[Hangar] InvBtn_stage1_engine center: ", btn_eng.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	if Helios4CampaignData.is_timed_challenge:
		time_remaining = max(0.0, time_remaining - delta)
		Helios4CampaignData.hangar_time_remaining = time_remaining
		_update_timer_display()

func _setup_procedural_widgets() -> void:
	# 1. Circular Dial Gauge in Right Telemetry HUD
	var dial_container = find_child("DialGaugeHolder", true, false)
	if dial_container:
		dial_gauge = Helios4HUDWidgets.DialGauge.new()
		dial_gauge.custom_minimum_size = Vector2(76, 76)
		dial_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dial_gauge.size_flags_vertical = Control.SIZE_EXPAND_FILL
		dial_container.add_child(dial_gauge)

	# 2. Radar Scope in Structural Bottom Card
	var radar_holder = find_child("RadarScopeHolder", true, false)
	if radar_holder:
		radar_widget = Helios4HUDWidgets.RadarScope.new()
		radar_widget.custom_minimum_size = Vector2(48, 48)
		radar_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		radar_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
		radar_holder.add_child(radar_widget)

	# 3. Telemetry Sparkline Waveform (Aero)
	var spark_aero_holder = find_child("SparklineAeroHolder", true, false)
	if spark_aero_holder:
		sparkline_aero = Helios4HUDWidgets.SparklineWave.new()
		sparkline_aero.color = Color(0.3, 0.9, 0.6, 0.85)
		sparkline_aero.custom_minimum_size = Vector2(80, 24)
		spark_aero_holder.add_child(sparkline_aero)

	# 4. Telemetry Sparkline Waveform (Power)
	var spark_pwr_holder = find_child("SparklinePowerHolder", true, false)
	if spark_pwr_holder:
		sparkline_power = Helios4HUDWidgets.SparklineWave.new()
		sparkline_power.color = Color(1.0, 0.75, 0.2, 0.85)
		sparkline_power.custom_minimum_size = Vector2(80, 24)
		spark_pwr_holder.add_child(sparkline_power)

	# 5. Readiness Progress Bars (3 horizontal striped bars with checkmarks & 90% pips)
	var bars_holder = find_child("ReadinessBarsHolder", true, false)
	if bars_holder:
		readiness_bars = Helios4HUDWidgets.ReadinessBars.new()
		readiness_bars.custom_minimum_size = Vector2(160, 48)
		readiness_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readiness_bars.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bars_holder.add_child(readiness_bars)

	# 6. Specialist Vector Icons in Bottom Cards
	var wrench_holder = find_child("WrenchIconHolder", true, false)
	if wrench_holder:
		var w_icon = Helios4HUDWidgets.SpecialistIcon.new()
		w_icon.role_type = "wrench"
		w_icon.icon_color = Color(0.98, 0.65, 0.12)
		w_icon.custom_minimum_size = Vector2(36, 36)
		wrench_holder.add_child(w_icon)

	var planet_holder = find_child("PlanetIconHolder", true, false)
	if planet_holder:
		var p_icon = Helios4HUDWidgets.SpecialistIcon.new()
		p_icon.role_type = "planetary"
		p_icon.icon_color = Color(0.95, 0.4, 0.5)
		p_icon.custom_minimum_size = Vector2(36, 36)
		planet_holder.add_child(p_icon)

	var elec_holder = find_child("ElecIconHolder", true, false)
	if elec_holder:
		var e_icon = Helios4HUDWidgets.SpecialistIcon.new()
		e_icon.role_type = "electrical"
		e_icon.icon_color = Color(0.2, 0.85, 1.0)
		e_icon.custom_minimum_size = Vector2(36, 36)
		elec_holder.add_child(e_icon)

	# 7. Left Vertical Toolbar Icons (Sliders, Tools, Box, Rocket, Target, Eye, Layers)
	var tool_strip = find_child("ToolStripVBox", true, false)
	if tool_strip:
		var tools = ["sliders", "tools", "box", "rocket", "target", "eye", "layers"]
		for idx in range(tools.size()):
			var t_icon = Helios4HUDWidgets.ToolStripIcon.new()
			t_icon.tool_type = tools[idx]
			t_icon.is_active = (idx == 1) # Tools active by default
			t_icon.custom_minimum_size = Vector2(24, 24)
			tool_strip.add_child(t_icon)

func _setup_inventory_grid() -> void:
	var inv_container = find_child("InventoryGrid", true, false)
	if not inv_container:
		return

	var icon_mapping = {
		"stage1_engine": "cluster",
		"booster_tank": "tank",
		"interstage_truss": "truss",
		"vacuum_engine": "engine",
		"grid_fins": "fins",
		"probe_bus": "bus",
		"solar_wings": "solar",
		"high_gain_dish": "dish",
		"mag_boom": "boom",
		"avionics": "avionics",
		"copv_tanks": "tank",
		"fairing": "truss",
		"faraday": "dish",
		"rcs": "engine"
	}

	for child in inv_container.get_children():
		if child is Button:
			var comp_id = child.name.replace("InvBtn_", "")
			child.pressed.connect(func(): _select_component(comp_id))

func _select_component(comp_id: String) -> void:
	active_component_id = comp_id
	Sfx.part_attach()
	print("[Hangar] Selected component: ", comp_id)

	# Update visual highlights on inventory buttons
	var inv_container = find_child("InventoryGrid", true, false)
	if inv_container:
		for btn in inv_container.get_children():
			if btn is Button:
				var is_active = (btn.name == "InvBtn_" + comp_id)
				btn.flat = !is_active

	# Camera focus and 3D callout matching component
	match comp_id:
		"engine_cluster", "stage1_engine", "rcs":
			_set_camera_focus(Vector3(0.0, 1.8, 0.0), 10.5)
			if rocket_3d: rocket_3d.highlight_subsystem("propulsion_engines")
			_switch_role(Helios4CampaignData.ROLE_PROPULSION)
		"booster_tank", "propellant_load", "copv_tanks":
			_set_camera_focus(Vector3(0.0, 4.2, 0.0), 11.5)
			if rocket_3d: rocket_3d.highlight_subsystem("propulsion_engines")
			_switch_role(Helios4CampaignData.ROLE_PROPULSION)
		"grid_fins":
			_set_camera_focus(Vector3(0.0, 2.0, 0.0), 9.5)
			if rocket_3d: rocket_3d.highlight_subsystem("grid_fins")
			_switch_role(Helios4CampaignData.ROLE_STRUCTURAL)
		"interstage_truss", "vacuum_engine":
			_set_camera_focus(Vector3(0.0, 7.2, 0.0), 9.5)
			if rocket_3d: rocket_3d.highlight_subsystem("interstage_vacuum")
			_switch_role(Helios4CampaignData.ROLE_ASTROGATOR)
		"solar_wings":
			_set_camera_focus(Vector3(0.0, 11.8, 0.0), 8.5)
			if rocket_3d: rocket_3d.highlight_subsystem("solar_wings")
			_switch_role(Helios4CampaignData.ROLE_SYSTEMS)
		"probe_bus", "gold_mli", "avionics":
			_set_camera_focus(Vector3(0.0, 11.8, 0.0), 8.0)
			if rocket_3d: rocket_3d.highlight_subsystem("probe_bus")
			_switch_role(Helios4CampaignData.ROLE_SYSTEMS)
		"high_gain_dish", "mag_boom", "faraday":
			_set_camera_focus(Vector3(0.0, 12.2, 0.0), 8.5)
			if rocket_3d: rocket_3d.highlight_subsystem("probe_bus")
			_switch_role(Helios4CampaignData.ROLE_SYSTEMS)
		"fairing":
			_set_camera_focus(Vector3(0.0, 11.0, 0.0), 10.0)
			if rocket_3d: rocket_3d.update_fairing_pose(not rocket_3d.fairing_open)
		_:
			_set_camera_focus(Vector3(0.0, 7.5, 0.0), 17.5)

func _update_timer_display() -> void:
	var timer_lbl = find_child("TimerLabel", true, false) as Label
	if timer_lbl:
		var mins = int(time_remaining) / 60
		var secs = int(time_remaining) % 60
		timer_lbl.text = "TIME: %02d:%02d" % [mins, secs]
		if time_remaining < 120.0:
			timer_lbl.add_theme_color_override("font_color", Color(0.98, 0.3, 0.3))
		else:
			timer_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))

func _connect_ui_signals() -> void:
	# Role switching tabs & bottom cards
	var tab_prop = find_child("TabPropulsion", true, false) as Button
	if tab_prop: tab_prop.pressed.connect(func(): _switch_role(Helios4CampaignData.ROLE_PROPULSION))

	var tab_struct = find_child("TabStructural", true, false) as Button
	if tab_struct: tab_struct.pressed.connect(func(): _switch_role(Helios4CampaignData.ROLE_STRUCTURAL))

	var tab_astro = find_child("TabAstrogator", true, false) as Button
	if tab_astro: tab_astro.pressed.connect(func(): _switch_role(Helios4CampaignData.ROLE_ASTROGATOR))

	var tab_sys = find_child("TabSystems", true, false) as Button
	if tab_sys: tab_sys.pressed.connect(func(): _switch_role(Helios4CampaignData.ROLE_SYSTEMS))

	var baseline_btn = find_child("BaselinePresetBtn", true, false) as Button
	if baseline_btn:
		baseline_btn.pressed.connect(_apply_educational_baseline)

		# Camera Focus Presets
	var btn_focus_full = find_child("FocusFullStackBtn", true, false) as Button
	if btn_focus_full: btn_focus_full.pressed.connect(func(): _set_camera_focus(Vector3(0, 7.5, 0), 17.5))

	var btn_focus_s1 = find_child("FocusStage1Btn", true, false) as Button
	if btn_focus_s1: btn_focus_s1.pressed.connect(func(): _set_camera_focus(Vector3(0, 3.4, 0), 11.5))

	var btn_focus_s2 = find_child("FocusStage2Btn", true, false) as Button
	if btn_focus_s2: btn_focus_s2.pressed.connect(func(): _set_camera_focus(Vector3(0, 7.2, 0), 9.5))

	var btn_focus_probe = find_child("FocusProbeBtn", true, false) as Button
	if btn_focus_probe: btn_focus_probe.pressed.connect(func(): _set_camera_focus(Vector3(0, 11.8, 0), 7.5))

	# Fairing Split Toggle
	var btn_fairing = find_child("ToggleFairingBtn", true, false) as Button
	if btn_fairing:
		btn_fairing.pressed.connect(func():
			if rocket_3d:
				rocket_3d.update_fairing_pose(not rocket_3d.fairing_open)
				btn_fairing.text = "FAIRING: OPEN" if rocket_3d.fairing_open else "FAIRING: CLOSED"
		)

	# Flight Readiness Review Proceed Button
	var btn_review = find_child("ProceedToFRRBtn", true, false) as Button
	if btn_review:
		btn_review.pressed.connect(_on_proceed_to_review_pressed)

	# Back to Team Assignment
	var btn_back = find_child("BackToTeamBtn", true, false) as Button
	if btn_back:
		btn_back.pressed.connect(func():
			Helios4CampaignData.load_stage(Helios4CampaignData.Stage.TEAM_ASSIGNMENT, get_tree())
		)

	# Connect role workstation interactive hardware selectors
	_setup_hardware_selector_signals()

func _apply_educational_baseline() -> void:
	Helios4CampaignData.vehicle_config = Helios4CampaignData.get_default_vehicle_config().duplicate(true)
	Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config().duplicate(true)
	Helios4CampaignData.is_launch_authorized = false
	Helios4CampaignData.record_team_decision(Helios4CampaignData.ROLE_ASTROGATOR, "Educational Baseline Preset", "Loaded the game’s NASA-inspired reference configuration; this is not an official NASA design.")
	var controls := [
		["OptStage1Engine", 0], ["SldPropellantLoad", 1.0], ["ChkGridFins", true],
		["OptHullMaterial", 0], ["OptTrajectoryMode", 0], ["SldSolarArea", 6.5], ["OptAvionics", 0]
	]
	for entry in controls:
		var control := find_child(entry[0], true, false) as Control
		if control:
			control.set_block_signals(true)
			if control is OptionButton:
				control.select(entry[1])
			elif control is Range:
				control.value = entry[1]
			elif control is BaseButton:
				control.button_pressed = entry[1]
			control.set_block_signals(false)
	if rocket_3d and rocket_3d.grid_fins_node:
		rocket_3d.grid_fins_node.visible = true
	_set_camera_focus(Vector3(0.0, 7.5, 0.0), 17.5)
	if rocket_3d:
		rocket_3d.animate_part_pulse("full_stack")
		rocket_3d.highlight_subsystem("")
	Helios4CampaignData.save_campaign_state()
	_recalculate_and_refresh_ui()

func _setup_hardware_selector_signals() -> void:
	# Propulsion: Booster Engine
	var opt_s1_engine = find_child("OptStage1Engine", true, false) as OptionButton
	if opt_s1_engine:
		var eng = Helios4CampaignData.vehicle_config.get("stage1_engine", "booster_hydrolox_quad")
		if eng == "booster_keralox_cluster":
			opt_s1_engine.selected = 1
		elif eng == "booster_undersized_twin":
			opt_s1_engine.selected = 2
		else:
			opt_s1_engine.selected = 0
		opt_s1_engine.item_selected.connect(func(idx):
			var v = Helios4CampaignData.vehicle_config
			match idx:
				0:
					v["stage1_engine"] = "booster_hydrolox_quad"
					v["stage1_thrust_kn"] = 480.0
					v["stage1_isp_s"] = 320.0
					v["vehicle_cost_m"] = 48.0
				1:
					v["stage1_engine"] = "booster_keralox_cluster"
					v["stage1_thrust_kn"] = 560.0
					v["stage1_isp_s"] = 295.0
					v["vehicle_cost_m"] = 44.0
				2:
					v["stage1_engine"] = "booster_undersized_twin"
					v["stage1_thrust_kn"] = 280.0
					v["stage1_isp_s"] = 310.0
					v["vehicle_cost_m"] = 32.0
			Helios4CampaignData.is_launch_authorized = false
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_PROPULSION,
				"Booster Engine Selection",
				"Selected %s (Thrust: %.0f kN, Isp: %.0f s)" % [v["stage1_engine"], v["stage1_thrust_kn"], v["stage1_isp_s"]]
			)
			Helios4CampaignData.save_campaign_state()
			_recalculate_and_refresh_ui()
			_on_part_swapped("propulsion_engines", Vector3(0.0, 2.8, 0.0), 10.5)
		)

	# Propulsion: Propellant Loading
	var sld_prop = find_child("SldPropellantLoad", true, false) as HSlider
	if sld_prop:
		sld_prop.value = Helios4CampaignData.vehicle_config.get("propellant_load_factor", 1.0)
		sld_prop.value_changed.connect(func(val):
			Helios4CampaignData.vehicle_config["propellant_load_factor"] = val
			Helios4CampaignData.is_launch_authorized = false
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_PROPULSION,
				"Propellant Loading",
				"Adjusted Stage 1 propellant fraction to %.2f" % val
			)
			Helios4CampaignData.save_campaign_state()
			_recalculate_and_refresh_ui()
			if rocket_3d: rocket_3d.highlight_subsystem("propulsion_engines")
		)

	# Structural: Grid Fins
	var chk_fins = find_child("ChkGridFins", true, false) as CheckBox
	if chk_fins:
		chk_fins.button_pressed = Helios4CampaignData.vehicle_config.get("has_grid_fins", true)
		chk_fins.toggled.connect(func(pressed):
			Helios4CampaignData.vehicle_config["has_grid_fins"] = pressed
			Helios4CampaignData.vehicle_config["stage1_fins"] = "aero_grid_fins" if pressed else "none"
			Helios4CampaignData.is_launch_authorized = false
			if rocket_3d and rocket_3d.grid_fins_node:
				rocket_3d.grid_fins_node.visible = pressed
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_STRUCTURAL,
				"Aerodynamic Stabilizers",
				"Toggled 4x Titanium Grid Fins: %s" % ("ENABLED" if pressed else "REMOVED")
			)
			Helios4CampaignData.save_campaign_state()
			_recalculate_and_refresh_ui()
			_on_part_swapped("grid_fins", Vector3(0.0, 2.0, 0.0), 9.5)
		)

	# Structural: Hull Material
	var opt_hull = find_child("OptHullMaterial", true, false) as OptionButton
	if opt_hull:
		var struct = Helios4CampaignData.probe_config.get("bus_structure", "struct_carbon_composite")
		opt_hull.selected = 1 if struct == "struct_al_li_alloy" else 0
		opt_hull.item_selected.connect(func(idx):
			var p = Helios4CampaignData.probe_config
			match idx:
				0:
					p["bus_structure"] = "struct_carbon_composite"
					p["structure_mass_kg"] = 180.0
					p["structure_cost_m"] = 18.0
				1:
					p["bus_structure"] = "struct_al_li_alloy"
					p["structure_mass_kg"] = 230.0
					p["structure_cost_m"] = 13.5
			Helios4CampaignData.is_launch_authorized = false
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_STRUCTURAL,
				"Bus Hull Material",
				"Selected %s structure (Mass: %.0f kg)" % [p["bus_structure"], p["structure_mass_kg"]]
			)
			Helios4CampaignData.save_campaign_state()
			_recalculate_and_refresh_ui()
			_on_part_swapped("probe_bus", Vector3(0.0, 11.8, 0.0), 8.2)
		)

	# Astrogator: Trajectory Mode
	var opt_traj = find_child("OptTrajectoryMode", true, false) as OptionButton
	if opt_traj:
		var mode = Helios4CampaignData.vehicle_config.get("trajectory_mode", "direct_injection")
		opt_traj.selected = 1 if mode == "phased_wsb" else 0
		opt_traj.item_selected.connect(func(idx):
			var v = Helios4CampaignData.vehicle_config
			var m = "phased_wsb" if idx == 1 else "direct_injection"
			v["trajectory_mode"] = m
			Helios4CampaignData.is_launch_authorized = false
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_ASTROGATOR,
				"Trajectory Optimization",
				"Selected %s transfer mode (%s cruise)" % [
					"Phased WSB" if idx == 1 else "Direct Injection",
					"135-Day" if idx == 1 else "110-Day"
				]
			)
			Helios4CampaignData.save_campaign_state()
			_recalculate_and_refresh_ui()
			_on_part_swapped("interstage_vacuum", Vector3(0.0, 7.2, 0.0), 10.5)
		)

	# Systems: Solar Array Area Slider
	var sld_solar = find_child("SldSolarArea", true, false) as HSlider
	if sld_solar:
		sld_solar.value = Helios4CampaignData.probe_config.get("solar_array_area_m2", 6.5)
		sld_solar.value_changed.connect(func(val):
			Helios4CampaignData.probe_config["solar_array_area_m2"] = val
			Helios4CampaignData.is_launch_authorized = false
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_SYSTEMS,
				"Solar Array Sizing",
				"Configured solar array area to %.1f m²" % val
			)
			Helios4CampaignData.save_campaign_state()
			_recalculate_and_refresh_ui()
			if rocket_3d:
				rocket_3d.highlight_subsystem("solar_wings")
				rocket_3d.animate_part_pulse("solar_wings")
		)

	# Systems: Rad-Hard Avionics Selection
	var opt_avionics = find_child("OptAvionics", true, false) as OptionButton
	if opt_avionics:
		var comp = Helios4CampaignData.probe_config.get("computer_type", "comp_rad_hard_quad_core")
		opt_avionics.selected = 1 if comp == "comp_dual_leon3" else 0
		opt_avionics.item_selected.connect(func(idx):
			var p = Helios4CampaignData.probe_config
			match idx:
				0:
					p["computer_type"] = "comp_rad_hard_quad_core"
					p["avionics_power_w"] = 65.0
					p["computer_cost_m"] = 16.0
				1:
					p["computer_type"] = "comp_dual_leon3"
					p["avionics_power_w"] = 52.0
					p["computer_cost_m"] = 12.0
			Helios4CampaignData.is_launch_authorized = false
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_SYSTEMS,
				"Avionics Computer",
				"Selected %s (Power: %.0f W)" % [p["computer_type"], p["avionics_power_w"]]
			)
			Helios4CampaignData.save_campaign_state()
			_recalculate_and_refresh_ui()
			_on_part_swapped("probe_bus", Vector3(0.0, 11.8, 0.0), 8.2)
		)

func _switch_role(role_id: String) -> void:
	active_role = role_id
	Helios4CampaignData.active_role = role_id

	# Update active tab styling
	var tab_prop = find_child("TabPropulsion", true, false) as Button
	var tab_struct = find_child("TabStructural", true, false) as Button
	var tab_astro = find_child("TabAstrogator", true, false) as Button
	var tab_sys = find_child("TabSystems", true, false) as Button

	if tab_prop: tab_prop.button_pressed = (role_id == Helios4CampaignData.ROLE_PROPULSION)
	if tab_struct: tab_struct.button_pressed = (role_id == Helios4CampaignData.ROLE_STRUCTURAL)
	if tab_astro: tab_astro.button_pressed = (role_id == Helios4CampaignData.ROLE_ASTROGATOR)
	if tab_sys: tab_sys.button_pressed = (role_id == Helios4CampaignData.ROLE_SYSTEMS)

	# Show corresponding controls panel in right telemetry sidebar
	var panel_prop = find_child("ControlsPropulsion", true, false)
	var panel_struct = find_child("ControlsStructural", true, false)
	var panel_astro = find_child("ControlsAstrogator", true, false)
	var panel_sys = find_child("ControlsSystems", true, false)

	if panel_prop: panel_prop.visible = (role_id == Helios4CampaignData.ROLE_PROPULSION)
	if panel_struct: panel_struct.visible = (role_id == Helios4CampaignData.ROLE_STRUCTURAL)
	if panel_astro: panel_astro.visible = (role_id == Helios4CampaignData.ROLE_ASTROGATOR)
	if panel_sys: panel_sys.visible = (role_id == Helios4CampaignData.ROLE_SYSTEMS)

	var active_role_lbl = find_child("ActiveRoleBanner", true, false) as Label
	if active_role_lbl:
		var meta = Helios4CampaignData.ROLE_METADATA[role_id]
		var player_name = Helios4CampaignData.team_player_names.get(role_id, "Specialist")
		active_role_lbl.text = "%s [%s]" % [meta["title"].to_upper(), player_name.to_upper()]
		active_role_lbl.add_theme_color_override("font_color", meta["color"])

func _setup_scratch_builder() -> void:
	var root_ui := find_child("RootUI", true, false) as Control
	if root_ui == null:
		return
	scratch_builder = ScratchBuilder.new()
	scratch_builder.name = "ScratchBuilder"
	scratch_builder.custom_minimum_size = Vector2(300, 0)
	scratch_builder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scratch_builder.position = Vector2(16, 120)
	scratch_builder.size = Vector2(300, 0)
	scratch_builder.build_changed.connect(_on_scratch_build_changed)
	root_ui.add_child(scratch_builder)

func _on_scratch_build_changed() -> void:
	# Rebuild the 3D vehicle and refresh every readout against the new config.
	if rocket_3d and rocket_3d.has_method("rebuild_vehicle"):
		rocket_3d.rebuild_vehicle()
		# Snap animation: the new part pops into place.
		if rocket_3d.probe_node:
			var tw := create_tween()
			tw.tween_property(rocket_3d.probe_node, "scale", Vector3.ONE * 0.86, 0.08)
			tw.tween_property(rocket_3d.probe_node, "scale", Vector3.ONE, 0.16)
	_recalculate_and_refresh_ui()
	if destination_checklist != null:
		destination_checklist.refresh()

func _setup_destination_checklist() -> void:
	var root_ui := find_child("RootUI", true, false) as Control
	if root_ui == null:
		return
	destination_checklist = DestinationChecklist.new()
	destination_checklist.name = "DestinationChecklist"
	destination_checklist.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	destination_checklist.position = Vector2(-300, 120)
	destination_checklist.custom_minimum_size = Vector2(280, 0)
	destination_checklist.size = Vector2(280, 0)
	root_ui.add_child(destination_checklist)

func _recalculate_and_refresh_ui() -> void:
	current_telemetry = Helios4CampaignData.calculate_hangar_telemetry()
	if destination_checklist != null:
		destination_checklist.refresh()

	# Update HUD Labels
	_update_label("ValWetMass", "%.0f kg" % current_telemetry["liftoff_wet_mass_kg"])
	_update_label("ValDryMass", "%.0f kg" % (current_telemetry["liftoff_wet_mass_kg"] - current_telemetry["stage1_fuel_mass_kg"] - current_telemetry["stage2_fuel_mass_kg"] - current_telemetry["probe_propellant_mass_kg"]))
	_update_label("ValPropMass", "%.0f kg" % (current_telemetry["stage1_fuel_mass_kg"] + current_telemetry["stage2_fuel_mass_kg"] + current_telemetry["probe_propellant_mass_kg"]))

	_update_label("ValDeltaVS1", "%.0f m/s" % current_telemetry["delta_v_stage1"])
	_update_label("ValDeltaVS2", "%.0f m/s" % current_telemetry["delta_v_stage2"])
	_update_label("ValDeltaVProbe", "%.0f m/s" % current_telemetry["delta_v_probe"])
	_update_label("ValDeltaVTotal", "%.0f m/s" % current_telemetry["total_mission_delta_v"])

	_update_label("ValTWR", "%.2f" % current_telemetry["liftoff_twr"])
	_update_label("ValStaticMargin", "+%.2f calibers" % current_telemetry["static_margin_calibers"])
	_update_label("ValPowerMargin", "%+.0f W" % current_telemetry["power_margin_w"])
	_update_label("ValBudget", "$%.1fM / $%.1fM" % [current_telemetry["total_cost_m"], current_telemetry["budget_cap_m"]])

	# Update Circular Dial Gauge (Delta-V target ~ 11,000 m/s)
	if dial_gauge:
		var dv_ratio = clamp(current_telemetry["total_mission_delta_v"] / 12000.0, 0.0, 1.0)
		dial_gauge.value = dv_ratio
		dial_gauge.label_top = "Δ"
		dial_gauge.label_bottom = "%.0f m/s" % current_telemetry["total_mission_delta_v"]

	# Update Bottom Center Readiness Progress Bars (Values normalized)
	if readiness_bars:
		var mass_val: float = clamp(1.0 - current_telemetry["probe_wet_mass_kg"] / 1250.0, 0.0, 1.0)
		var pwr_val: float = clamp(current_telemetry["power_margin_w"] / 2600.0, 0.0, 1.0)
		var dv_val: float = clamp(current_telemetry["total_launch_delta_v"] / max(current_telemetry["req_launch_dv"], 1.0), 0.0, 1.0)
		var thermal_mass: float = Helios4CampaignData.probe_config.get("thermal_mass_kg", 18.0)
		var thermal_val: float = clamp(thermal_mass / 30.0, 0.0, 1.0) # Explicit game proxy: thermal-control hardware mass reserve.
		var budget_val: float = clamp(1.0 - current_telemetry["total_cost_m"] / max(current_telemetry["budget_cap_m"], 1.0), 0.0, 1.0)
		readiness_bars.values = [mass_val, pwr_val, dv_val, thermal_val, budget_val]

	# Update Launch Gate Badge
	var gate_badge = find_child("GateBadge", true, false) as Label
	var btn_review = find_child("ProceedToFRRBtn", true, false) as Button

	if current_telemetry["all_gate_checks_passed"]:
		if gate_badge:
			gate_badge.text = "NOMINAL - GO FOR REVIEW"
			gate_badge.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))
		if btn_review:
			btn_review.disabled = false
			btn_review.text = "PROCEED TO FLIGHT READINESS REVIEW"
	else:
		if gate_badge:
			gate_badge.text = "PENDING - REVIEW / WAIVER"
			gate_badge.add_theme_color_override("font_color", Color(0.98, 0.55, 0.15))
		if btn_review:
			btn_review.disabled = false
			btn_review.text = "INSPECT FLIGHT READINESS REVIEW"

func _update_label(node_name: String, text_val: String) -> void:
	var lbl = find_child(node_name, true, false) as Label
	if lbl:
		lbl.text = text_val

func _set_camera_focus(target: Vector3, dist: float) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "_cam_target", target, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_cam_distance", dist, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(_step: float): _update_camera_transform(), 0.0, 1.0, 0.42)
	tween.finished.connect(_update_camera_transform)

func _on_part_swapped(subsystem_id: String, focus_target: Vector3, focus_dist: float) -> void:
	_set_camera_focus(focus_target, focus_dist)
	if rocket_3d:
		rocket_3d.highlight_subsystem(subsystem_id)
		rocket_3d.animate_part_pulse(subsystem_id)

func _setup_team_perk_badge() -> void:
	var root_ui := find_child("RootUI", true, false) as Control
	if not root_ui or root_ui.has_node("TeamPerkBadgePanel"):
		return
	var perk := Helios4CampaignData.get_active_team_perk()
	var panel := PanelContainer.new()
	panel.name = "TeamPerkBadgePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -195.0
	panel.offset_top = 48.0
	panel.offset_right = 195.0
	panel.offset_bottom = 74.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var col: Color = perk.get("color", Color(0.25, 0.78, 1.0))
	panel.add_theme_stylebox_override("panel", MarginTheme.create_pill_style(col))
	var lbl := MarginTheme.build_perk_badge_label(perk)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	root_ui.add_child(panel)

func _update_camera_transform() -> void:
	if not orbit_cam:
		return
	var yaw_rad = deg_to_rad(_cam_yaw)
	var pitch_rad = deg_to_rad(_cam_pitch)

	var offset = Vector3(
		cos(pitch_rad) * sin(yaw_rad),
		sin(pitch_rad),
		cos(pitch_rad) * cos(yaw_rad)
	) * _cam_distance

	orbit_cam.position = _cam_target + offset
	orbit_cam.look_at(_cam_target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			_drag_start = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_is_right_dragging = event.pressed
			_drag_start = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = clamp(_cam_distance - 0.75, 4.0, 32.0)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = clamp(_cam_distance + 0.75, 4.0, 32.0)
			_update_camera_transform()
	elif event is InputEventMouseMotion:
		if _is_dragging:
			var delta = event.relative
			_cam_yaw -= delta.x * 0.35
			_cam_pitch = clamp(_cam_pitch + delta.y * 0.35, -25.0, 75.0)
			_update_camera_transform()
		elif _is_right_dragging:
			var delta = event.relative
			_cam_distance = clamp(_cam_distance + delta.y * 0.08, 4.0, 32.0)
			_update_camera_transform()

func _on_proceed_to_review_pressed() -> void:
	print("[Hangar] Transitioning to Flight Readiness Review Gate")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.ENGINEERING_REVIEW, get_tree())
