class_name Helios4HangarController
extends Node3D

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const Helios4Rocket3D = preload("res://margin/scripts/helios4_rocket_3d.gd")

@onready var rocket_3d: Helios4Rocket3D = %Rocket3D
@onready var orbit_cam: Camera3D = %HangarCamera

# Active Workstation Role
var active_role: String = Helios4CampaignData.ROLE_PROPULSION

# Camera Orbit State
var _cam_yaw: float = 25.0
var _cam_pitch: float = 12.0
var _cam_distance: float = 18.0
var _cam_target: Vector3 = Vector3(0.0, 7.5, 0.0)
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

# Timer State
var time_remaining: float = 600.0

# Telemetry Cache
var current_telemetry: Dictionary = {}

func _ready() -> void:
	if Helios4CampaignData.vehicle_config.is_empty():
		Helios4CampaignData.vehicle_config = Helios4CampaignData.get_default_vehicle_config()
	if Helios4CampaignData.probe_config.is_empty():
		Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()
		
	time_remaining = Helios4CampaignData.hangar_time_remaining
	active_role = Helios4CampaignData.active_role
	
	_connect_ui_signals()
	_update_camera_transform()
	_recalculate_and_refresh_ui()

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
	, CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	if Helios4CampaignData.is_timed_challenge:
		time_remaining = max(0.0, time_remaining - delta)
		Helios4CampaignData.hangar_time_remaining = time_remaining
		_update_timer_display()

func _update_timer_display() -> void:
	var timer_lbl = find_child("TimerLabel", true, false) as Label
	if timer_lbl:
		var mins = int(time_remaining) / 60
		var secs = int(time_remaining) % 60
		timer_lbl.text = "⏱ TIME: %02d:%02d" % [mins, secs]
		if time_remaining < 120.0:
			timer_lbl.add_theme_color_override("font_color", Color(0.98, 0.3, 0.3))
		else:
			timer_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	else:
		var timer_box = find_child("TimerLabel", true, false) as Label
		if timer_box:
			timer_box.text = "⏱ UNTIMED PRACTICE"

func _connect_ui_signals() -> void:
	# Role switching tabs
	var tab_prop = find_child("TabPropulsion", true, false) as Button
	if tab_prop: tab_prop.pressed.connect(func(): _switch_role(Helios4CampaignData.ROLE_PROPULSION))
	
	var tab_struct = find_child("TabStructural", true, false) as Button
	if tab_struct: tab_struct.pressed.connect(func(): _switch_role(Helios4CampaignData.ROLE_STRUCTURAL))
	
	var tab_astro = find_child("TabAstrogator", true, false) as Button
	if tab_astro: tab_astro.pressed.connect(func(): _switch_role(Helios4CampaignData.ROLE_ASTROGATOR))
	
	var tab_sys = find_child("TabSystems", true, false) as Button
	if tab_sys: tab_sys.pressed.connect(func(): _switch_role(Helios4CampaignData.ROLE_SYSTEMS))
	
	# Camera Focus Presets
	var btn_focus_full = find_child("FocusFullStackBtn", true, false) as Button
	if btn_focus_full: btn_focus_full.pressed.connect(func(): _set_camera_focus(Vector3(0, 7.5, 0), 18.0))
	
	var btn_focus_s1 = find_child("FocusStage1Btn", true, false) as Button
	if btn_focus_s1: btn_focus_s1.pressed.connect(func(): _set_camera_focus(Vector3(0, 3.5, 0), 10.0))
	
	var btn_focus_s2 = find_child("FocusStage2Btn", true, false) as Button
	if btn_focus_s2: btn_focus_s2.pressed.connect(func(): _set_camera_focus(Vector3(0, 8.5, 0), 8.0))
	
	var btn_focus_probe = find_child("FocusProbeBtn", true, false) as Button
	if btn_focus_probe: btn_focus_probe.pressed.connect(func(): _set_camera_focus(Vector3(0, 13.0, 0), 6.5))
	
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

func _setup_hardware_selector_signals() -> void:
	# Propulsion: Booster Engine
	var opt_s1_engine = find_child("OptStage1Engine", true, false) as OptionButton
	if opt_s1_engine:
		var eng = Helios4CampaignData.vehicle_config.get("stage1_engine", "booster_hydrolox_quad")
		if eng == "booster_keralox_cluster":
			opt_s1_engine.selected = 1
		elif eng == "booster_strap_on_solids":
			opt_s1_engine.selected = 2
		else:
			opt_s1_engine.selected = 0
		opt_s1_engine.item_selected.connect(func(idx):
			var v = Helios4CampaignData.vehicle_config
			match idx:
				0: # Hydrolox Quad (High efficiency)
					v["stage1_engine"] = "booster_hydrolox_quad"
					v["stage1_thrust_kn"] = 4200.0
					v["stage1_isp_s"] = 320.0
					v["vehicle_cost_m"] = 58.0
				1: # Keralox Octet (High thrust)
					v["stage1_engine"] = "booster_keralox_cluster"
					v["stage1_thrust_kn"] = 4900.0
					v["stage1_isp_s"] = 295.0
					v["vehicle_cost_m"] = 54.0
				2: # Solid + Hydrolox Core
					v["stage1_engine"] = "booster_strap_on_solids"
					v["stage1_thrust_kn"] = 5600.0
					v["stage1_isp_s"] = 280.0
					v["vehicle_cost_m"] = 62.0
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_PROPULSION,
				"Engine Selection",
				"Selected %s (Thrust: %.0f kN, Isp: %.0fs)" % [v["stage1_engine"], v["stage1_thrust_kn"], v["stage1_isp_s"]]
			)
			_recalculate_and_refresh_ui()
		)
		
	# Propulsion: Propellant Loading Slider
	var sld_fuel = find_child("SldPropellantMass", true, false) as HSlider
	if sld_fuel:
		sld_fuel.value = Helios4CampaignData.vehicle_config.get("stage1_fuel_mass_kg", 24000.0)
		sld_fuel.value_changed.connect(func(val):
			Helios4CampaignData.vehicle_config["stage1_fuel_mass_kg"] = val
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_PROPULSION,
				"Propellant Loading",
				"Adjusted stage 1 propellant load to %.0f kg" % val
			)
			_recalculate_and_refresh_ui()
		)
		
	# Structural: Grid Fins Toggle
	var chk_fins = find_child("ChkGridFins", true, false) as CheckBox
	if chk_fins:
		chk_fins.button_pressed = (Helios4CampaignData.vehicle_config.get("stage1_fins", "aero_grid_fins") != "none")
		chk_fins.toggled.connect(func(enabled):
			Helios4CampaignData.vehicle_config["stage1_fins"] = "aero_grid_fins" if enabled else "none"
			Helios4CampaignData.vehicle_config["stage1_fin_mass_kg"] = 220.0 if enabled else 0.0
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_STRUCTURAL,
				"Aerodynamic Stabilizers",
				"Aft grid fins %s (+220 kg tail mass for static margin)" % ("Enabled" if enabled else "Disabled")
			)
			_recalculate_and_refresh_ui()
		)
		
	# Structural: Hull Material
	var opt_hull = find_child("OptHullMaterial", true, false) as OptionButton
	if opt_hull:
		var struct = Helios4CampaignData.probe_config.get("bus_structure", "struct_carbon_composite")
		opt_hull.selected = 1 if struct == "struct_al_li_alloy" else 0
		opt_hull.item_selected.connect(func(idx):
			var p = Helios4CampaignData.probe_config
			match idx:
				0: # Carbon Composite Honeycomb
					p["bus_structure"] = "struct_carbon_composite"
					p["structure_mass_kg"] = 180.0
					p["structure_cost_m"] = 18.0
				1: # Aluminum-Lithium 2195 Alloy
					p["bus_structure"] = "struct_al_li_alloy"
					p["structure_mass_kg"] = 230.0
					p["structure_cost_m"] = 13.5
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_STRUCTURAL,
				"Bus Hull Material",
				"Selected %s structure (Mass: %.0f kg)" % [p["bus_structure"], p["structure_mass_kg"]]
			)
			_recalculate_and_refresh_ui()
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
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_ASTROGATOR,
				"Trajectory Optimization",
				"Selected %s transfer mode (%s cruise)" % [
					"Phased WSB" if idx == 1 else "Direct Injection",
					"135-Day" if idx == 1 else "110-Day"
				]
			)
			_recalculate_and_refresh_ui()
		)
		
	# Systems: Solar Array Area Slider
	var sld_solar = find_child("SldSolarArea", true, false) as HSlider
	if sld_solar:
		sld_solar.value = Helios4CampaignData.probe_config.get("solar_array_area_m2", 6.5)
		sld_solar.value_changed.connect(func(val):
			Helios4CampaignData.probe_config["solar_array_area_m2"] = val
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_SYSTEMS,
				"Solar Array Sizing",
				"Configured solar array area to %.1f m²" % val
			)
			_recalculate_and_refresh_ui()
		)
		
	# Systems: Rad-Hard Avionics Selection
	var opt_avionics = find_child("OptAvionics", true, false) as OptionButton
	if opt_avionics:
		var comp = Helios4CampaignData.probe_config.get("computer_type", "comp_rad_hard_quad_core")
		opt_avionics.selected = 1 if comp == "comp_dual_leon3" else 0
		opt_avionics.item_selected.connect(func(idx):
			var p = Helios4CampaignData.probe_config
			match idx:
				0: # Rad-Hard Quad Core
					p["computer_type"] = "comp_rad_hard_quad_core"
					p["avionics_power_w"] = 65.0
					p["computer_cost_m"] = 16.0
				1: # Dual Fault-TolerANT LEON3
					p["computer_type"] = "comp_dual_leon3"
					p["avionics_power_w"] = 52.0
					p["computer_cost_m"] = 12.0
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_SYSTEMS,
				"Avionics Computer",
				"Selected %s (Power: %.0f W)" % [p["computer_type"], p["avionics_power_w"]]
			)
			_recalculate_and_refresh_ui()
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
	
	# Show corresponding controls panel
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
		active_role_lbl.text = "ACTIVE WORKSTATION: %s %s [%s]" % [meta["icon"], meta["title"].to_upper(), player_name.to_upper()]
		active_role_lbl.add_theme_color_override("font_color", meta["color"])

func _recalculate_and_refresh_ui() -> void:
	current_telemetry = Helios4CampaignData.calculate_hangar_telemetry()
	
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
	_update_label("ValPowerMargin", "+%.0f W" % current_telemetry["power_margin_w"])
	_update_label("ValBudget", "$%.1fM / $%.1fM" % [current_telemetry["total_cost_m"], current_telemetry["budget_cap_m"]])
	
	# Update Launch Gate Badge
	var gate_badge = find_child("GateBadge", true, false) as Label
	var btn_review = find_child("ProceedToFRRBtn", true, false) as Button
	
	if current_telemetry["all_gate_checks_passed"]:
		if gate_badge:
			gate_badge.text = "● ALL SYSTEMS NOMINAL — GO FOR FLIGHT REVIEW"
			gate_badge.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))
		if btn_review:
			btn_review.disabled = false
			btn_review.text = "PROCEED TO FLIGHT READINESS REVIEW →"
	else:
		if gate_badge:
			gate_badge.text = "▲ ENGINEERING CHECKS PENDING — RESOLVE RED/AMBER WARNINGS"
			gate_badge.add_theme_color_override("font_color", Color(0.98, 0.55, 0.15))
		if btn_review:
			btn_review.disabled = false # Allow player to enter review to view detailed role audit
			btn_review.text = "INSPECT FLIGHT READINESS REVIEW →"

func _update_label(node_name: String, text_val: String) -> void:
	var lbl = find_child(node_name, true, false) as Label
	if lbl:
		lbl.text = text_val

func _set_camera_focus(target: Vector3, dist: float) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "_cam_target", target, 0.4)
	tween.tween_property(self, "_cam_distance", dist, 0.4)
	tween.finished.connect(_update_camera_transform)

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
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = clamp(_cam_distance - 0.8, 4.0, 32.0)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = clamp(_cam_distance + 0.8, 4.0, 32.0)
			_update_camera_transform()
	elif event is InputEventMouseMotion and _is_dragging:
		var delta = event.relative
		_cam_yaw -= delta.x * 0.4
		_cam_pitch = clamp(_cam_pitch + delta.y * 0.4, -30.0, 75.0)
		_update_camera_transform()

func _on_proceed_to_review_pressed() -> void:
	print("[Hangar] Transitioning to Flight Readiness Review Gate")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.ENGINEERING_REVIEW, get_tree())
