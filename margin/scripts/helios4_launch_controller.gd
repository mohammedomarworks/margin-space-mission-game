class_name Helios4LaunchController
extends Node3D

# ==============================================================================
# MARGIN — HELIOS-4: PHASE 2 — EARTH LAUNCH AND MAX-Q
# Interactive 3D Rocket Ascent Simulation:
# - Liftoff ignition, throttle control, gravity-turn pitch guidance
# - Dynamic pressure Max-Q calculation (q = 0.5 * rho * v^2) with throttle corridor
# - G-load calculation separate from atmospheric acceleration
# - Staging separation, aerodynamic fairing jettison, and orbital insertion
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const Helios4Rocket3D = preload("res://margin/scripts/helios4_rocket_3d.gd")

enum FlightPhase {
	COUNTDOWN,
	ASCENT_STAGE1,
	MAX_Q_CORRIDOR,
	STAGE1_BURNOUT,
	STAGE_SEPARATION,
	ASCENT_STAGE2,
	FAIRING_JETTISON,
	ORBITAL_INJECTION,
	SYSTEMS_ACTIVATION,
	FLIGHT_COMPLETED,
	FLIGHT_ABORTED
}

var current_phase: FlightPhase = FlightPhase.COUNTDOWN

# 3D Node References
@onready var rocket: Node3D = %RocketNode
@onready var rocket_visual: Helios4Rocket3D = %RocketVisual
@onready var vapor_cone: MeshInstance3D = %VaporCone
@onready var launch_cam: Camera3D = %LaunchCamera
@onready var earth_mesh: MeshInstance3D = %EarthMesh
@onready var plume_particles: CPUParticles3D = %PlumeParticles

# Flight Physics State (Educational Simulation Model)
var altitude_m: float = 0.0
var velocity_ms: float = 0.0
var throttle: float = 1.0 # 0.0 to 1.0
var pitch_deg: float = 90.0 # 90 = vertical, 0 = horizontal
var flight_time_s: float = 0.0
var countdown_s: float = 3.0

var s1_fuel_kg: float = 24000.0
var s2_fuel_kg: float = 5400.0
var s1_fuel_capacity_kg: float = 24000.0
var s2_fuel_capacity_kg: float = 5400.0

var current_mass_kg: float = 34000.0
var dynamic_pressure_kpa: float = 0.0
var g_load: float = 1.0
var structural_stress_pct: float = 0.0
var trajectory_error_pct: float = 0.0

var fairing_separated: bool = false
var stage1_separated: bool = false
var orbit_achieved: bool = false
var systems_activated: bool = false

# Constants
const G0: float = 9.80665
const RHO_0: float = 1.225 # kg/m^3 sea-level air density
const SCALE_HEIGHT_M: float = 7500.0 # Earth atmospheric scale height
const TARGET_ORBIT_ALT_M: float = 185000.0 # 185 km parking orbit
const TARGET_ORBIT_VEL_MS: float = 7780.0

func _ready() -> void:
	_init_flight_parameters()
	_connect_controls()
	_update_ui()

func _init_flight_parameters() -> void:
	var v_cfg = Helios4CampaignData.vehicle_config
	if v_cfg.is_empty():
		v_cfg = Helios4CampaignData.get_default_vehicle_config()
		Helios4CampaignData.vehicle_config = v_cfg
		
	s1_fuel_capacity_kg = v_cfg.get("stage1_fuel_mass_kg", 24000.0)
	s1_fuel_kg = s1_fuel_capacity_kg
	s2_fuel_capacity_kg = v_cfg.get("stage2_fuel_mass_kg", 5400.0)
	s2_fuel_kg = s2_fuel_capacity_kg
	
	var tel = Helios4CampaignData.calculate_hangar_telemetry()
	current_mass_kg = tel["liftoff_wet_mass_kg"]
	
	if vapor_cone:
		vapor_cone.visible = false

var time_warp: float = 1.0

func _physics_process(delta: float) -> void:
	delta *= time_warp
	if current_phase == FlightPhase.FLIGHT_COMPLETED or current_phase == FlightPhase.FLIGHT_ABORTED:
		return
		
	if current_phase == FlightPhase.COUNTDOWN:
		countdown_s -= delta
		if countdown_s <= 0.0:
			current_phase = FlightPhase.ASCENT_STAGE1
			if plume_particles:
				plume_particles.emitting = true
		_update_ui()
		return
		
	flight_time_s += delta
	_update_flight_physics(delta)
	_update_3d_visuals(delta)
	_update_ui()
	_check_phase_transitions()

func _update_flight_physics(delta: float) -> void:
	var v_cfg = Helios4CampaignData.vehicle_config
	var thrust_n: float = 0.0
	var isp_s: float = 320.0
	
	# Atmospheric Density Model: rho = rho_0 * exp(-h / H)
	var air_density: float = RHO_0 * exp(-altitude_m / SCALE_HEIGHT_M) if altitude_m < 85000.0 else 0.0
	
	# Dynamic Pressure: q = 0.5 * rho * v^2
	dynamic_pressure_kpa = (0.5 * air_density * velocity_ms * velocity_ms) / 1000.0
	
	# Check Max-Q Corridor (typically 10km to 15km altitude)
	if dynamic_pressure_kpa > 28.0 and not stage1_separated:
		current_phase = FlightPhase.MAX_Q_CORRIDOR
		if vapor_cone:
			vapor_cone.visible = true
			var cone_alpha = clamp((dynamic_pressure_kpa - 25.0) / 15.0, 0.0, 0.85)
			if vapor_cone.material_override:
				vapor_cone.material_override.set("albedo_color", Color(1, 1, 1, cone_alpha))
		
		# Structural Stress calculation: If throttle > 0.80 during peak dynamic pressure, stress accumulates
		if dynamic_pressure_kpa > 32.0 and throttle > 0.75:
			structural_stress_pct += delta * 8.5 * (throttle - 0.75)
	else:
		if vapor_cone:
			vapor_cone.visible = false
			
	# Propulsion and Fuel Depletion
	if not stage1_separated:
		thrust_n = v_cfg.get("stage1_thrust_kn", 4200.0) * 1000.0 * throttle
		isp_s = v_cfg.get("stage1_isp_s", 320.0)
		var mdot = thrust_n / (isp_s * G0) if thrust_n > 0.0 else 0.0
		var burn_fuel = mdot * delta
		s1_fuel_kg = max(0.0, s1_fuel_kg - burn_fuel)
		current_mass_kg = max(current_mass_kg - burn_fuel, 8000.0)
		
		if s1_fuel_kg <= 0.0 and current_phase != FlightPhase.STAGE1_BURNOUT and current_phase != FlightPhase.STAGE_SEPARATION:
			current_phase = FlightPhase.STAGE1_BURNOUT
			throttle = 0.0
			if plume_particles:
				plume_particles.emitting = false
	elif not orbit_achieved:
		# Stage 2 Vacuum Burn
		thrust_n = v_cfg.get("stage2_thrust_kn", 480.0) * 1000.0 * throttle
		isp_s = v_cfg.get("stage2_isp_s", 450.0)
		var mdot2 = thrust_n / (isp_s * G0) if thrust_n > 0.0 else 0.0
		var burn_fuel2 = mdot2 * delta
		s2_fuel_kg = max(0.0, s2_fuel_kg - burn_fuel2)
		current_mass_kg = max(current_mass_kg - burn_fuel2, 1400.0)
		
		if s2_fuel_kg <= 0.0 and velocity_ms < 7600.0:
			# Ran out of fuel before orbit
			current_phase = FlightPhase.FLIGHT_ABORTED
			return
			
	# G-load: T / (m * g0)
	g_load = (thrust_n / (current_mass_kg * G0)) if current_mass_kg > 0.0 else 1.0
	
	# Aerodynamic Drag: D = 0.5 * rho * v^2 * Cd * A
	var drag_n: float = dynamic_pressure_kpa * 1000.0 * 0.28 * 4.5
	var net_thrust_n: float = thrust_n - drag_n
	
	# Effective Acceleration
	var accel_ms2: float = (net_thrust_n / current_mass_kg) - (G0 * sin(deg_to_rad(pitch_deg)))
	velocity_ms = max(0.0, velocity_ms + accel_ms2 * delta)
	
	# Vertical vs Horizontal climb
	var pitch_rad = deg_to_rad(pitch_deg)
	altitude_m += velocity_ms * sin(pitch_rad) * delta
	
	# Gravity Turn Corridor Guidance: Optimal pitch schedule
	var target_pitch = 90.0 * (1.0 - sqrt(clamp(altitude_m / 140000.0, 0.0, 1.0)))
	var pitch_deviation = abs(pitch_deg - target_pitch)
	if pitch_deviation > 12.0:
		trajectory_error_pct += delta * 2.0

func _check_phase_transitions() -> void:
	# Fairing Jettison check (Above dense atmosphere: > 68,000m)
	if altitude_m > 68000.0 and not fairing_separated:
		fairing_separated = true
		if rocket_visual:
			rocket_visual.update_fairing_pose(true)
			
	# Orbital Injection check (Velocity >= 7,750 m/s and altitude >= 180,000 m)
	if velocity_ms >= TARGET_ORBIT_VEL_MS and altitude_m >= 170000.0 and not orbit_achieved:
		orbit_achieved = true
		current_phase = FlightPhase.ORBITAL_INJECTION
		throttle = 0.0
		if plume_particles:
			plume_particles.emitting = false

func _update_3d_visuals(_delta: float) -> void:
	if not rocket:
		return
		
	# Rocket pitch angle reflects flight dynamics
	rocket.rotation_degrees.z = -(90.0 - pitch_deg)
	
	# Simulate upward ascent by slowly moving Earth background and rotating scene
	if earth_mesh:
		var visual_alt_scale = clamp(altitude_m / TARGET_ORBIT_ALT_M, 0.0, 1.0)
		earth_mesh.position.y = -8.0 - visual_alt_scale * 14.0
		earth_mesh.position.z = -18.0 - visual_alt_scale * 8.0
		
	# Camera shakes during Max-Q
	if dynamic_pressure_kpa > 25.0 and launch_cam:
		var shake = (dynamic_pressure_kpa / 35.0) * 0.04
		launch_cam.position.x = randf_range(-shake, shake)
		launch_cam.position.y = 2.5 + randf_range(-shake, shake)
	elif launch_cam:
		launch_cam.position.x = 0.0
		launch_cam.position.y = 2.5

func _connect_controls() -> void:
	# Throttle Buttons
	var btn_throt_up = find_child("BtnThrotUp", true, false) as Button
	if btn_throt_up: btn_throt_up.pressed.connect(func(): throttle = clamp(throttle + 0.1, 0.0, 1.0))
	
	var btn_throt_down = find_child("BtnThrotDown", true, false) as Button
	if btn_throt_down: btn_throt_down.pressed.connect(func(): throttle = clamp(throttle - 0.1, 0.0, 1.0))
	
	# Pitch Buttons (Gravity Turn)
	var btn_pitch_left = find_child("BtnPitchLeft", true, false) as Button
	if btn_pitch_left: btn_pitch_left.pressed.connect(func(): pitch_deg = clamp(pitch_deg + 3.0, 0.0, 90.0))
	
	var btn_pitch_right = find_child("BtnPitchRight", true, false) as Button
	if btn_pitch_right: btn_pitch_right.pressed.connect(func(): pitch_deg = clamp(pitch_deg - 3.0, 0.0, 90.0))
	
	# Staging Button (SPACE)
	var btn_stage = find_child("BtnStageSeparation", true, false) as Button
	if btn_stage: btn_stage.pressed.connect(_execute_stage_separation)
	
	# Systems Activation Button (E)
	var btn_systems = find_child("BtnSystemsActivate", true, false) as Button
	if btn_systems: btn_systems.pressed.connect(_execute_systems_activation)
	
	# Abort / Next Buttons
	var btn_proceed_trans = find_child("ProceedToTransferBtn", true, false) as Button
	if btn_proceed_trans: btn_proceed_trans.pressed.connect(_on_proceed_to_transfer_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.keycode == KEY_W and event.pressed):
		throttle = clamp(throttle + 0.1, 0.0, 1.0)
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.keycode == KEY_S and event.pressed):
		throttle = clamp(throttle - 0.1, 0.0, 1.0)
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.keycode == KEY_A and event.pressed):
		pitch_deg = clamp(pitch_deg + 2.5, 0.0, 90.0)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.keycode == KEY_D and event.pressed):
		pitch_deg = clamp(pitch_deg - 2.5, 0.0, 90.0)
	elif event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		_execute_stage_separation()
	elif event is InputEventKey and event.keycode == KEY_E and event.pressed:
		_execute_systems_activation()
	elif event is InputEventKey and event.keycode == KEY_T and event.pressed:
		time_warp = 8.0 if time_warp == 1.0 else 1.0
		print("[Launch] Time warp toggled to: ", time_warp, "x")
	elif event is InputEventKey and event.keycode == KEY_O and event.pressed:
		altitude_m = TARGET_ORBIT_ALT_M
		velocity_ms = TARGET_ORBIT_VEL_MS
		stage1_separated = true
		fairing_separated = true
		orbit_achieved = true
		current_phase = FlightPhase.ORBITAL_INJECTION
		_update_ui()
		print("[Launch] Fast-forward to Parking Orbit Injection.")

func _execute_stage_separation() -> void:
	if current_phase == FlightPhase.STAGE1_BURNOUT or s1_fuel_kg <= 100.0:
		stage1_separated = true
		current_phase = FlightPhase.ASCENT_STAGE2
		throttle = 1.0
		if plume_particles:
			plume_particles.emitting = true
		print("[Launch] Stage 1 Separation confirmed! Stage 2 vacuum ignition.")
	elif not stage1_separated and s1_fuel_kg > 500.0:
		# Premature staging warning
		structural_stress_pct += 15.0
		stage1_separated = true
		current_phase = FlightPhase.ASCENT_STAGE2
		throttle = 1.0
		print("[Launch] Premature staging: Boost fuel wasted!")

func _execute_systems_activation() -> void:
	if orbit_achieved and not systems_activated:
		systems_activated = true
		current_phase = FlightPhase.SYSTEMS_ACTIVATION
		print("[Launch] Systems Officer activated: Power online, DSN telemetry linked, early solar telemetry streaming.")

func _update_ui() -> void:
	_update_label("ValAltitude", "%.1f km" % (altitude_m / 1000.0))
	_update_label("ValVelocity", "%.0f m/s" % velocity_ms)
	_update_label("ValPitch", "%.1f°" % pitch_deg)
	_update_label("ValThrottle", "%.0f%%" % (throttle * 100.0))
	_update_label("ValDynamicPressure", "%.1f kPa" % dynamic_pressure_kpa)
	_update_label("ValGLoad", "%.2f G" % g_load)
	
	# Fuel Bars
	var bar_s1 = find_child("BarFuelS1", true, false) as ProgressBar
	if bar_s1:
		bar_s1.value = (s1_fuel_kg / s1_fuel_capacity_kg) * 100.0
		
	var bar_s2 = find_child("BarFuelS2", true, false) as ProgressBar
	if bar_s2:
		bar_s2.value = (s2_fuel_kg / s2_fuel_capacity_kg) * 100.0
		
	# Flight Event Advisory Banner
	var advisory_lbl = find_child("AdvisoryBanner", true, false) as Label
	var role_badge = find_child("ActiveOfficerBadge", true, false) as Label
	var btn_stage = find_child("BtnStageSeparation", true, false) as Button
	var btn_systems = find_child("BtnSystemsActivate", true, false) as Button
	var btn_proceed = find_child("ProceedToTransferBtn", true, false) as Button
	
	match current_phase:
		FlightPhase.COUNTDOWN:
			if advisory_lbl: advisory_lbl.text = "T-MINUS %.1f SECONDS — PROPULSION ENGINEER: CONFIRM IGNITION" % countdown_s
			if role_badge: role_badge.text = "OFFICER ON DECK: 🚀 PROPULSION ENGINEER"
		FlightPhase.ASCENT_STAGE1:
			if advisory_lbl: advisory_lbl.text = "BOOSTER CLIMB: ASTROGATOR INITIATE GRAVITY TURN [PITCH: A/D]"
			if role_badge: role_badge.text = "OFFICERS: 🚀 PROPULSION (THROTTLE) & 🧭 ASTROGATOR (PITCH)"
		FlightPhase.MAX_Q_CORRIDOR:
			if advisory_lbl:
				advisory_lbl.text = "▲ MAX-Q TRANSONIC PRESSURE PEAK (%.1f kPa) — STRUCTURAL ARCHITECT ADVISES THROTTLE TO 70%%" % dynamic_pressure_kpa
				advisory_lbl.add_theme_color_override("font_color", Color(0.98, 0.65, 0.15))
			if role_badge: role_badge.text = "OFFICER: 🏗 STRUCTURAL ARCHITECT (MAX-Q CORRIDOR WARNING)"
		FlightPhase.STAGE1_BURNOUT:
			if advisory_lbl:
				advisory_lbl.text = "STAGE 1 DEPLETED — PROPULSION & STRUCTURES: EXECUTE STAGE SEPARATION [SPACE]"
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
			if btn_stage: btn_stage.disabled = false
			if role_badge: role_badge.text = "OFFICER: 🚀 PROPULSION ENGINEER (STAGE SEPARATION AUTHORIZED)"
		FlightPhase.ASCENT_STAGE2:
			if advisory_lbl:
				var fairing_msg = " • FAIRING JETTISONED" if fairing_separated else ""
				advisory_lbl.text = "STAGE 2 VACUUM BURN: ACCELERATING TO ORBITAL VELOCITY (7,780 m/s)%s" % fairing_msg
			if btn_stage: btn_stage.disabled = true
			if role_badge: role_badge.text = "OFFICER: 🧭 ASTROGATOR (ORBITAL INJECTION PROGRAM)"
		FlightPhase.ORBITAL_INJECTION:
			if advisory_lbl:
				advisory_lbl.text = "PARKING ORBIT INJECTION SUCCESSFUL! SYSTEMS OFFICER: ACTIVATE BUS TELEMETRY [E]"
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
			if btn_systems: btn_systems.disabled = false
			if role_badge: role_badge.text = "OFFICER: ⚡ SYSTEMS OFFICER (BUS ACTIVATION)"
		FlightPhase.SYSTEMS_ACTIVATION:
			if advisory_lbl:
				advisory_lbl.text = "★ ALL SYSTEMS NOMINAL: HELIOS-4 INJECTED TOWARD SUN-EARTH L1!"
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
			if btn_proceed:
				btn_proceed.visible = true
				print("[Launch] ProceedToTransferBtn global_rect: ", btn_proceed.get_global_rect(), " center: ", btn_proceed.get_global_rect().get_center())
			if role_badge: role_badge.text = "ALL CREW: TRANS-L1 INJECTION BURN COMPLETED"
		FlightPhase.FLIGHT_ABORTED:
			if advisory_lbl:
				advisory_lbl.text = "▲ LAUNCH ABORT: PROPELLANT EXHAUSTED BEFORE ORBITAL VELOCITY REACHED."
				advisory_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))

func _update_label(node_name: String, text_val: String) -> void:
	var lbl = find_child(node_name, true, false) as Label
	if lbl:
		lbl.text = text_val

func _on_proceed_to_transfer_pressed() -> void:
	# Save launch telemetry
	Helios4CampaignData.launch_telemetry = {
		"flight_time_s": flight_time_s,
		"max_q_kpa": dynamic_pressure_kpa,
		"max_g_load": g_load,
		"structural_stress_pct": structural_stress_pct,
		"trajectory_error_pct": trajectory_error_pct,
		"orbit_altitude_km": altitude_m / 1000.0,
		"orbit_velocity_ms": velocity_ms,
		"s2_fuel_remaining_kg": s2_fuel_kg
	}
	print("[Launch] Flight successful! Advancing to Stage 3: Deep Space Transfer")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_3_TRANSFER, get_tree())
