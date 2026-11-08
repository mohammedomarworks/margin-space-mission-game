class_name Helios4DeepSpaceController
extends Node3D

# ==============================================================================
# MARGIN — HELIOS-4: PART 3 — DEEP SPACE TRANSFER & SOLAR CRISIS
# Continuous 3D Interplanetary Spaceflight Simulation
# 
# Flow:
# 1. PARKING ORBIT -> Trans-L1 Deep Space Injection Burn (TLI)
# 2. CRUISE & TIME WARP (1x, 10x, 100x, 1000x)
# 3. MID-COURSE CORRECTION (MCC-1) & Trajectory Guidance
# 4. PRECURSOR SOLAR PARTICLE EVENT (SEP) CRISIS (Active Region AR-4890)
# 5. TACTICAL CRISIS DECISION MATRIX (Safe Mode, Instruments, Comms/Power)
# 6. DYNAMIC STORM PROPAGATION & RELATIVISTIC PROTON FLUX
# 7. MULTI-STEP SPACECRAFT RECOVERY
# 8. L1 APPROACH READY (Advance to Part 4)
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const SpacecraftMaterials = preload("res://margin/materials/spacecraft_materials.gd")

# Sub-Phases
enum SubPhase {
	PARKING_ORBIT,
	INJECTION_BURN,
	CRUISE_EARLY,
	MIDCOURSE_CORRECTION,
	CRUISE_MID,
	SOLAR_CRISIS_ALERT,
	CRISIS_SIMULATION,
	SPACECRAFT_RECOVERY,
	L1_APPROACH_READY
}

# Camera Modes (Pure perspectives — 0 simulation time/physics impact)
enum CamMode {
	CHASE_3_4 = 0,
	WIDE_TRAJECTORY = 1,
	SUNWARD_SENSORS = 2,
	EARTH_DISH = 3,
	CRISIS_TACTICAL = 4
}

var current_subphase: SubPhase = SubPhase.PARKING_ORBIT
var current_cam_mode: CamMode = CamMode.CHASE_3_4
var is_sim_paused: bool = false

# 3D Node References
@onready var probe_node: Node3D = %ProbeNode
@onready var sun_node: Node3D = %SunNode
@onready var sun_mesh: MeshInstance3D = %SunMesh
@onready var sun_corona: MeshInstance3D = %SunCorona
@onready var sun_light: DirectionalLight3D = %SunLight
@onready var crisis_storm_light: DirectionalLight3D = %CrisisStormLight
@onready var solar_flare_particles: CPUParticles3D = %SolarFlareParticles
@onready var proton_stream_particles: CPUParticles3D = %ProtonStreamParticles
@onready var earth_node: Node3D = %EarthNode
@onready var earth_mesh: MeshInstance3D = %EarthMesh
@onready var earth_atmosphere: MeshInstance3D = %EarthAtmosphere
@onready var trajectory_arc: MeshInstance3D = %TrajectoryArc
@onready var deep_space_cam: Camera3D = %DeepSpaceCamera

# Spacecraft Sub-Meshes (built dynamically & procedural)
var bus_mesh: MeshInstance3D
var solar_wing_left: MeshInstance3D
var solar_wing_right: MeshInstance3D
var dish_reflector: MeshInstance3D
var mag_boom: MeshInstance3D
var faraday_cup: MeshInstance3D
var engine_exhaust: CPUParticles3D
var rcs_particles: CPUParticles3D

# Camera target interpolation
var _cam_offset_target: Vector3 = Vector3(4.2, 1.8, 5.0)
var _cam_look_target: Vector3 = Vector3(0.0, 0.4, 0.0)

# Time Acceleration
var time_warp_factors: Array = [1.0, 10.0, 100.0, 1000.0]
var current_warp_idx: int = 0
var warp_factor: float:
	get:
		if is_sim_paused: return 0.0
		return time_warp_factors[current_warp_idx]

# --- SHARED SPACECRAFT STATE (Inherited from Hangar and Launch) ---
const TARGET_L1_DISTANCE_KM: float = 1500000.0
const G0: float = 9.80665

var distance_km: float = 165.0 # starts at 165 km Earth parking orbit
var velocity_kms: float = 7.75 # km/s in parking orbit
var mission_elapsed_days: float = 0.0
var mission_elapsed_hours: float = 0.0
var trajectory_mode: String = "direct_injection" # direct (110d) or phased_wsb (135d)
var target_cruise_days: float = 110.0

var probe_dry_mass_kg: float = 338.4
var probe_propellant_kg: float = 320.0
var probe_isp_s: float = 315.0
var probe_wet_mass_kg: float:
	get: return probe_dry_mass_kg + probe_propellant_kg

var available_delta_v_ms: float:
	get:
		if probe_dry_mass_kg <= 0.0 or probe_wet_mass_kg <= probe_dry_mass_kg:
			return 0.0
		return probe_isp_s * G0 * log(probe_wet_mass_kg / probe_dry_mass_kg)

# Electrical & Battery
var solar_array_area_m2: float = 6.5
var solar_efficiency: float = 0.31
var battery_capacity_wh: float = 1200.0
var battery_charge_wh: float = 1200.0
var base_avionics_power_w: float = 65.0
var adcs_power_w: float = 35.0
var thermal_power_w: float = 25.0
var comms_power_w: float = 45.0
var solar_alignment_deg: float = 12.0 # degrees off normal

# Instrument Telemetry & Health
var instruments_health: Dictionary = {
	"faraday_cup": 100.0,
	"magnetometer": 100.0,
	"radiation_monitor": 100.0
}
var instruments_active: Dictionary = {
	"faraday_cup": true,
	"magnetometer": true,
	"radiation_monitor": true
}

# Navigation & Trajectory Accuracy
var trajectory_accuracy_pct: float = 99.2
var dsn_signal_db: float = 32.0 # decreases with distance (32 dB to 4.2 dB)

# Crisis Specific Tracking
var is_in_safe_mode: bool = false
var storm_elapsed_hours: float = 0.0
var storm_duration_hours: float = 18.0
var storm_peak_proton_flux_pfu: float = 2450.0
var current_proton_flux_pfu: float = 0.0
var accumulated_radiation_dose_rad: float = 0.0
var equipment_degradation_pct: float = 0.0
var science_bonus_pts: float = 0.0

# Crisis Tactical Decisions
var crisis_choice_safemode: int = 1 # 1: Full Safe, 2: Partial, 3: Continue Science
var crisis_choice_instruments: int = 1 # 1: Safe Optics, 2: Prioritize SEP, 3: Full Suite
var crisis_choice_comms: int = 1 # 1: Low-power Carrier, 2: High-rate DSN, 3: Memory Buffer
var crisis_decisions_committed: bool = false

# Recovery Sub-step
var recovery_step: int = 0 # 0: Diagnostics, 1: Instruments, 2: Comms, 3: Attitude, 4: Done

# Staging & Burn Timers
var burn_timer_s: float = 0.0
var burn_duration_s: float = 4.0
var is_thruster_firing: bool = false

# UI References
@onready var lbl_phase: Label = %LblObjectivePhase
@onready var lbl_status: Label = %LblObjectiveStatus
@onready var lbl_primary: Label = %LblObjectivePrimary
@onready var lbl_action: Label = %LblObjectiveAction
@onready var lbl_next: Label = %LblObjectiveNext
@onready var lbl_controls: Label = %LblObjectiveControls

@onready var val_met: Label = %ValMET
@onready var val_distance: Label = %ValDistance
@onready var val_velocity: Label = %ValVelocity
@onready var val_battery: Label = %ValBattery
@onready var val_power: Label = %ValPower
@onready var val_dsn: Label = %ValDSN

@onready var bar_progress: ProgressBar = %BarDistanceProgress
@onready var val_fuel: Label = %ValFuelRemaining
@onready var bar_fuel: ProgressBar = %BarFuelProgress
@onready var val_delta_v: Label = %ValDeltaV
@onready var val_traj_accuracy: Label = %ValTrajAccuracy
@onready var val_rad_dose: Label = %ValRadDose
@onready var val_inst_health: Label = %ValInstHealth

@onready var tactical_crisis_panel: Control = %TacticalCrisisPanel
@onready var reticle_overlay: Control = %ReticleOverlay
@onready var advisory_banner: Label = %AdvisoryBanner
@onready var sim_pause_banner: Control = %SimPauseBanner

@onready var btn_primary_action: Button = %BtnPrimaryAction
@onready var btn_secondary_action: Button = %BtnSecondaryAction
@onready var btn_pause: Button = %BtnPauseSim

# Tactical Choice Button References
@onready var btn_safe_opt1: Button = %BtnSafeOpt1
@onready var btn_safe_opt2: Button = %BtnSafeOpt2
@onready var btn_safe_opt3: Button = %BtnSafeOpt3
@onready var btn_inst_opt1: Button = %BtnInstOpt1
@onready var btn_inst_opt2: Button = %BtnInstOpt2
@onready var btn_inst_opt3: Button = %BtnInstOpt3
@onready var btn_comm_opt1: Button = %BtnCommOpt1
@onready var btn_comm_opt2: Button = %BtnCommOpt2
@onready var btn_comm_opt3: Button = %BtnCommOpt3
@onready var btn_commit_crisis: Button = %BtnCommitCrisis

# Time warp buttons
@onready var btn_warp_1x: Button = %BtnWarp1x
@onready var btn_warp_10x: Button = %BtnWarp10x
@onready var btn_warp_100x: Button = %BtnWarp100x
@onready var btn_warp_1000x: Button = %BtnWarp1000x

func _ready() -> void:
	_inherit_campaign_state()
	_build_spacecraft_model()
	_build_3d_trajectory()
	_connect_ui_signals()
	_set_camera_mode(CamMode.CHASE_3_4)
	_update_flight_guidance()
	_update_telemetry_ui()
	
	if sim_pause_banner:
		sim_pause_banner.visible = false
	if tactical_crisis_panel:
		tactical_crisis_panel.visible = false
		
	# Post coordinate logging for test automation
	get_tree().process_frame.connect(_log_ui_coordinates, CONNECT_ONE_SHOT)

func _inherit_campaign_state() -> void:
	var p_cfg = Helios4CampaignData.probe_config
	var v_cfg = Helios4CampaignData.vehicle_config
	var l_tel = Helios4CampaignData.launch_telemetry
	
	if not p_cfg.is_empty():
		probe_propellant_kg = p_cfg.get("propellant_mass_kg", 320.0)
		probe_isp_s = p_cfg.get("probe_isp_s", 315.0)
		solar_array_area_m2 = p_cfg.get("solar_array_area_m2", 6.5)
		solar_efficiency = p_cfg.get("solar_efficiency", 0.31)
		battery_capacity_wh = p_cfg.get("battery_capacity_wh", 1200.0)
		battery_charge_wh = battery_capacity_wh
		base_avionics_power_w = p_cfg.get("avionics_power_w", 65.0)
		
		var dry_m = (
			p_cfg.get("structure_mass_kg", 180.0) +
			p_cfg.get("propellant_dry_mass_kg", 55.0) +
			p_cfg.get("solar_mass_kg", 45.0) +
			p_cfg.get("battery_mass_kg", 28.0) +
			p_cfg.get("computer_mass_kg", 24.0) +
			p_cfg.get("adcs_mass_kg", 26.0) +
			p_cfg.get("thermal_mass_kg", 18.0) +
			p_cfg.get("comms_mass_kg", 22.0)
		)
		var inst_m = 0.0
		for k in p_cfg.get("instruments", {}):
			inst_m += p_cfg["instruments"][k].get("mass_kg", 0.0)
		dry_m += inst_m
		dry_m += dry_m * 0.04 # harness
		probe_dry_mass_kg = dry_m
		
	if not v_cfg.is_empty():
		trajectory_mode = v_cfg.get("trajectory_mode", "direct_injection")
		target_cruise_days = 135.0 if trajectory_mode == "phased_wsb" else 110.0
		
	if not l_tel.is_empty():
		distance_km = l_tel.get("orbit_altitude_km", 165.0)
		velocity_kms = l_tel.get("orbit_velocity_ms", 7750.0) / 1000.0

	# Check if jumping directly into Phase 4 (Crisis)
	if Helios4CampaignData.current_stage == Helios4CampaignData.Stage.PHASE_4_CRISIS or name == "Helios4Crisis":
		current_subphase = SubPhase.SOLAR_CRISIS_ALERT
		distance_km = 750000.0
		mission_elapsed_days = 58.5
		velocity_kms = 3.65
		trajectory_accuracy_pct = 99.4
		if probe_propellant_kg > 295.0:
			probe_propellant_kg = 295.0 # Account for TLI and MCC
	else:
		current_subphase = SubPhase.PARKING_ORBIT
		distance_km = 165.0
		velocity_kms = 7.75

func _build_spacecraft_model() -> void:
	if not probe_node:
		return
	for c in probe_node.get_children():
		c.queue_free()
		
	# 1. Main Octagonal / Cubic Bus (Wrapped in Gold MLI with Silver accents)
	bus_mesh = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(1.4, 1.4, 1.6)
	bus_mesh.mesh = b_box
	bus_mesh.material_override = SpacecraftMaterials.get_mat("gold_mli")
	probe_node.add_child(bus_mesh)
	
	# Anti-sun Silver radiator panels
	var rad := MeshInstance3D.new()
	var r_box := BoxMesh.new()
	r_box.size = Vector3(1.35, 1.35, 0.04)
	rad.mesh = r_box
	rad.position = Vector3(0.0, 0.0, 0.81)
	rad.material_override = SpacecraftMaterials.get_mat("radiator_white")
	probe_node.add_child(rad)
	
	# 2. Dual Solar Array Wings (Matching Reference 03 & 04)
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var w_box := BoxMesh.new()
		w_box.size = Vector3(2.4, 0.95, 0.05)
		wing.mesh = w_box
		wing.position = Vector3(side * 2.0, 0.0, 0.0)
		wing.material_override = SpacecraftMaterials.get_mat("solar_panel")
		probe_node.add_child(wing)
		if side < 0:
			solar_wing_left = wing
		else:
			solar_wing_right = wing
			
		# Solar panel back reinforcement
		var w_back := MeshInstance3D.new()
		var wb_box := BoxMesh.new()
		wb_box.size = Vector3(2.42, 0.97, 0.02)
		w_back.mesh = wb_box
		w_back.position = Vector3(side * 2.0, 0.0, -0.035)
		w_back.material_override = SpacecraftMaterials.get_mat("solar_back")
		probe_node.add_child(w_back)
		
	# 3. High-Gain Parabolic Dish (Mounted on top, pointing Earthward)
	var dish_pivot := Node3D.new()
	dish_pivot.name = "DishPivot"
	dish_pivot.position = Vector3(0.0, 0.9, 0.3)
	dish_pivot.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	probe_node.add_child(dish_pivot)
	
	dish_reflector = MeshInstance3D.new()
	var d_sph = SphereMesh.new()
	d_sph.radius = 0.65
	d_sph.height = 0.32
	dish_reflector.mesh = d_sph
	dish_reflector.material_override = SpacecraftMaterials.get_mat("antenna_reflector")
	dish_pivot.add_child(dish_reflector)
	
	# Tripod Feed Horn
	var feed := MeshInstance3D.new()
	var f_cyl := CylinderMesh.new()
	f_cyl.top_radius = 0.03
	f_cyl.bottom_radius = 0.05
	f_cyl.height = 0.45
	feed.mesh = f_cyl
	feed.position = Vector3(0.0, 0.0, 0.35)
	feed.material_override = SpacecraftMaterials.get_mat("antenna_feed")
	dish_pivot.add_child(feed)
	
	# 4. Long Deployable Magnetometer Boom (Pointing Sunward)
	mag_boom = MeshInstance3D.new()
	var m_cyl = CylinderMesh.new()
	m_cyl.top_radius = 0.035
	m_cyl.bottom_radius = 0.045
	m_cyl.height = 3.8
	mag_boom.mesh = m_cyl
	mag_boom.position = Vector3(0.4, 0.5, -2.1)
	mag_boom.rotation_degrees = Vector3(68.0, 15.0, 0.0)
	mag_boom.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
	probe_node.add_child(mag_boom)
	
	# Gold Sensor Head at boom tip
	var mag_head := MeshInstance3D.new()
	var mh_box := BoxMesh.new()
	mh_box.size = Vector3(0.22, 0.22, 0.22)
	mag_head.mesh = mh_box
	mag_head.position = Vector3(0.0, 1.95, 0.0)
	mag_head.material_override = SpacecraftMaterials.get_mat("gold_mli")
	mag_boom.add_child(mag_head)
	
	# 5. Faraday Cup Solar Wind Plasma Analyzer
	faraday_cup = MeshInstance3D.new()
	var fc_cyl = CylinderMesh.new()
	fc_cyl.top_radius = 0.12
	fc_cyl.bottom_radius = 0.08
	fc_cyl.height = 0.26
	faraday_cup.mesh = fc_cyl
	faraday_cup.position = Vector3(-0.45, 0.75, -0.75)
	faraday_cup.rotation_degrees = Vector3(40.0, -25.0, 0.0)
	faraday_cup.material_override = SpacecraftMaterials.get_mat("sensor_lens")
	probe_node.add_child(faraday_cup)
	
	# 6. Main Apogee Propulsion Engine Bell (Aft base)
	var engine := MeshInstance3D.new()
	var e_cyl := CylinderMesh.new()
	e_cyl.top_radius = 0.16
	e_cyl.bottom_radius = 0.32
	e_cyl.height = 0.5
	engine.mesh = e_cyl
	engine.position = Vector3(0.0, -0.95, 0.0)
	engine.material_override = SpacecraftMaterials.get_mat("rocket_inconel_bell")
	probe_node.add_child(engine)
	
	# Engine Exhaust CPUParticles3D
	engine_exhaust = CPUParticles3D.new()
	engine_exhaust.name = "EngineExhaust"
	engine_exhaust.emitting = false
	engine_exhaust.amount = 64
	engine_exhaust.lifetime = 0.35
	engine_exhaust.speed_scale = 1.8
	engine_exhaust.direction = Vector3(0.0, -1.0, 0.0)
	engine_exhaust.spread = 12.0
	engine_exhaust.initial_velocity_min = 12.0
	engine_exhaust.initial_velocity_max = 18.0
	engine_exhaust.color = Color(0.4, 0.8, 1.0, 0.8)
	engine_exhaust.material_override = SpacecraftMaterials.get_mat("vacuum_plume_blue")
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.08
	p_mesh.height = 0.16
	engine_exhaust.mesh = p_mesh
	engine_exhaust.position = Vector3(0.0, -1.25, 0.0)
	probe_node.add_child(engine_exhaust)
	
	# RCS Thruster Plumes
	rcs_particles = CPUParticles3D.new()
	rcs_particles.name = "RCSParticles"
	rcs_particles.emitting = false
	rcs_particles.amount = 24
	rcs_particles.lifetime = 0.2
	rcs_particles.direction = Vector3(1.0, 0.0, 0.0)
	rcs_particles.spread = 20.0
	rcs_particles.initial_velocity_min = 4.0
	rcs_particles.initial_velocity_max = 6.0
	rcs_particles.material_override = SpacecraftMaterials.get_mat("rcs_plume_white")
	var r_mesh = SphereMesh.new()
	r_mesh.radius = 0.04
	r_mesh.height = 0.08
	rcs_particles.mesh = r_mesh
	rcs_particles.position = Vector3(0.7, -0.6, 0.0)
	probe_node.add_child(rcs_particles)

func _build_3d_trajectory() -> void:
	if not trajectory_arc:
		return
		
	var im := ImmediateMesh.new()
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, SpacecraftMaterials.get_mat("trajectory_line_cyan"))
	
	# Generate educational curved transfer arc from Earth to Sun-Earth L1
	var steps = 40
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		# Arc curves from Earth (+X, +Z) through saddle point toward L1 (-X, -Z)
		var x = lerp(20.0, -35.0, t) + sin(t * PI) * 8.0
		var y = sin(t * PI) * 2.5
		var z = lerp(35.0, -45.0, t) - sin(t * PI) * 5.0
		im.surface_add_vertex(Vector3(x, y, z))
		
	im.surface_end()
	trajectory_arc.mesh = im

func _connect_ui_signals() -> void:
	if btn_primary_action:
		btn_primary_action.pressed.connect(_on_primary_action_pressed)
	if btn_secondary_action:
		btn_secondary_action.pressed.connect(_on_secondary_action_pressed)
	if btn_pause:
		btn_pause.pressed.connect(_toggle_simulation_pause)
		
	# Time Warp Ribbon
	if btn_warp_1x: btn_warp_1x.pressed.connect(func(): _set_time_warp(0))
	if btn_warp_10x: btn_warp_10x.pressed.connect(func(): _set_time_warp(1))
	if btn_warp_100x: btn_warp_100x.pressed.connect(func(): _set_time_warp(2))
	if btn_warp_1000x: btn_warp_1000x.pressed.connect(func(): _set_time_warp(3))
	
	# Camera Ribbon
	_connect_cam_btn("BtnCamChase", CamMode.CHASE_3_4)
	_connect_cam_btn("BtnCamWide", CamMode.WIDE_TRAJECTORY)
	_connect_cam_btn("BtnCamSunward", CamMode.SUNWARD_SENSORS)
	_connect_cam_btn("BtnCamEarth", CamMode.EARTH_DISH)
	_connect_cam_btn("BtnCamCrisis", CamMode.CRISIS_TACTICAL)
	
	# Tactical Decision Buttons
	if btn_safe_opt1: btn_safe_opt1.pressed.connect(func(): _select_crisis_option(1, 1))
	if btn_safe_opt2: btn_safe_opt2.pressed.connect(func(): _select_crisis_option(1, 2))
	if btn_safe_opt3: btn_safe_opt3.pressed.connect(func(): _select_crisis_option(1, 3))
	
	if btn_inst_opt1: btn_inst_opt1.pressed.connect(func(): _select_crisis_option(2, 1))
	if btn_inst_opt2: btn_inst_opt2.pressed.connect(func(): _select_crisis_option(2, 2))
	if btn_inst_opt3: btn_inst_opt3.pressed.connect(func(): _select_crisis_option(2, 3))
	
	if btn_comm_opt1: btn_comm_opt1.pressed.connect(func(): _select_crisis_option(3, 1))
	if btn_comm_opt2: btn_comm_opt2.pressed.connect(func(): _select_crisis_option(3, 2))
	if btn_comm_opt3: btn_comm_opt3.pressed.connect(func(): _select_crisis_option(3, 3))
	
	if btn_commit_crisis:
		btn_commit_crisis.pressed.connect(_on_commit_crisis_pressed)

func _connect_cam_btn(btn_name: String, mode: CamMode) -> void:
	var btn = find_child(btn_name, true, false) as Button
	if btn:
		btn.pressed.connect(func(): _set_camera_mode(mode))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key_ev = event as InputEventKey
	match key_ev.keycode:
		KEY_SPACE:
			if btn_primary_action and not btn_primary_action.disabled and btn_primary_action.visible:
				_on_primary_action_pressed()
		KEY_C:
			# Cycle camera modes
			var next_mode = (int(current_cam_mode) + 1) % 5
			_set_camera_mode(next_mode as CamMode)
		KEY_1:
			_set_camera_mode(CamMode.CHASE_3_4)
		KEY_2:
			_set_camera_mode(CamMode.WIDE_TRAJECTORY)
		KEY_3:
			_set_camera_mode(CamMode.SUNWARD_SENSORS)
		KEY_4:
			_set_camera_mode(CamMode.EARTH_DISH)
		KEY_5:
			_set_camera_mode(CamMode.CRISIS_TACTICAL)
		KEY_P:
			_toggle_simulation_pause()
		KEY_Z:
			_set_time_warp(0) # 1x
		KEY_X:
			_set_time_warp(1) # 10x
		KEY_V:
			_set_time_warp(2) # 100x
		KEY_B:
			_set_time_warp(3) # 1000x

func _process(delta: float) -> void:
	_update_camera(delta)
	
	if is_sim_paused:
		return
		
	# Scale delta by time warp
	var effective_dt = delta * warp_factor
	
	# Process active sub-phase simulation
	match current_subphase:
		SubPhase.PARKING_ORBIT:
			# Spacecraft slow orbit rotation around Earth
			if probe_node:
				probe_node.rotation.y += 0.05 * delta
		
		SubPhase.INJECTION_BURN:
			_process_injection_burn(delta)
			
		SubPhase.CRUISE_EARLY:
			_process_cruise_progression(effective_dt)
			if distance_km >= 300000.0:
				_enter_midcourse_correction()
				
		SubPhase.MIDCOURSE_CORRECTION:
			# Waiting for player maneuver execution
			if is_thruster_firing:
				_process_mcc_burn(delta)
				
		SubPhase.CRUISE_MID:
			_process_cruise_progression(effective_dt)
			if distance_km >= 750000.0:
				_enter_solar_crisis()
				
		SubPhase.SOLAR_CRISIS_ALERT:
			# Waiting for tactical response choices
			_animate_solar_storm_visuals(delta)
			
		SubPhase.CRISIS_SIMULATION:
			_process_crisis_simulation(effective_dt)
			_animate_solar_storm_visuals(delta)
			
		SubPhase.SPACECRAFT_RECOVERY:
			# Waiting for player step-by-step recovery actions
			_process_power_and_systems(effective_dt)
			
		SubPhase.L1_APPROACH_READY:
			_process_cruise_progression(effective_dt * 0.2)
			
	_update_celestial_transforms()
	_update_telemetry_ui()

# --- SIMULATION ENGINES ---

func _process_injection_burn(dt: float) -> void:
	burn_timer_s += dt
	is_thruster_firing = true
	if engine_exhaust: engine_exhaust.emitting = true
	
	# Consume fuel & apply acceleration
	# TLI burn delta-V ~ 3,180 m/s over 4s simulation display
	var burn_rate_kgs = 22.0 # kg/s
	var fuel_spent = min(probe_propellant_kg, burn_rate_kgs * dt)
	probe_propellant_kg -= fuel_spent
	
	velocity_kms = lerp(7.75, 10.95, clamp(burn_timer_s / burn_duration_s, 0.0, 1.0))
	distance_km += velocity_kms * dt * 15.0 # initial escape surge
	
	if burn_timer_s >= burn_duration_s:
		is_thruster_firing = false
		if engine_exhaust: engine_exhaust.emitting = false
		current_subphase = SubPhase.CRUISE_EARLY
		_set_time_warp(1) # Auto set to 10x
		Helios4CampaignData.record_team_decision(
			Helios4CampaignData.ROLE_PROPULSION,
			"Deep Space Trans-L1 Injection",
			"Trans-L1 Injection Burn Completed. Hyperbolic escape velocity 10.95 km/s achieved."
		)
		_show_advisory("★ TRANS-L1 INJECTION COMPLETE! HELIOS-4 on interplanetary trajectory sunward.")
		_update_flight_guidance()

func _process_cruise_progression(dt: float) -> void:
	# Speed settles to interplanetary cruise ~ 3.8 km/s
	velocity_kms = clamp(velocity_kms - 0.0001 * dt, 3.2, 4.2)
	
	# Advance distance (1 second = dt seconds of cruise; educational scale factor 100 km/s per sim-sec)
	var d_dist = velocity_kms * dt * 80.0
	distance_km += d_dist
	
	# Calculate mission elapsed time
	var d_days = (d_dist / TARGET_L1_DISTANCE_KM) * target_cruise_days
	mission_elapsed_days += d_days
	mission_elapsed_hours = fmod(mission_elapsed_days * 24.0, 24.0)
	
	_process_power_and_systems(dt)
	
	# DSN Carrier Signal (inverse square law from Earth)
	var progress = clamp(distance_km / TARGET_L1_DISTANCE_KM, 0.0, 1.0)
	dsn_signal_db = max(4.2, 32.0 - (progress * 27.8))

func _process_power_and_systems(dt: float) -> void:
	# Solar Constant S(d): 1361 W/m² at Earth (1 AU), 1388 W/m² at L1 (0.99 AU)
	var progress = clamp(distance_km / TARGET_L1_DISTANCE_KM, 0.0, 1.0)
	var solar_flux = lerp(1361.0, 1388.0, progress)
	
	# Solar Generation = Area * Efficiency * Flux * cos(alignment)
	var cos_align = cos(deg_to_rad(solar_alignment_deg))
	var gen_w = solar_array_area_m2 * solar_efficiency * solar_flux * cos_align
	
	if is_in_safe_mode:
		gen_w *= 0.75 # arrays canted to edge or minimal illumination
		
	# Power Load Calculation
	var inst_load_w = 0.0
	if instruments_active["faraday_cup"]: inst_load_w += 18.0
	if instruments_active["magnetometer"]: inst_load_w += 12.0
	if instruments_active["radiation_monitor"]: inst_load_w += 15.0
	
	var total_load_w = base_avionics_power_w + adcs_power_w + thermal_power_w + comms_power_w + inst_load_w
	if is_in_safe_mode:
		total_load_w = 45.0 + 15.0 + 20.0 + 15.0 # reduced safe load
		
	var net_w = gen_w - total_load_w
	
	# Battery charge integration (Wh)
	var dt_hours = dt / 3600.0
	battery_charge_wh = clamp(battery_charge_wh + (net_w * dt_hours), 0.0, battery_capacity_wh)

func _enter_midcourse_correction() -> void:
	current_subphase = SubPhase.MIDCOURSE_CORRECTION
	_set_time_warp(0) # Drop to 1x for manual maneuver
	trajectory_accuracy_pct = 84.2 # Simulated trajectory drift off L1 saddle point
	_show_advisory("▲ ASTROGATOR ALERT: Trajectory drift detected at 300,000 km. MCC-1 burn required.")
	_update_flight_guidance()

func _process_mcc_burn(dt: float) -> void:
	burn_timer_s += dt
	if rcs_particles: rcs_particles.emitting = true
	
	# Apply fine RCS trim
	if burn_timer_s >= 2.5:
		is_thruster_firing = false
		if rcs_particles: rcs_particles.emitting = false
		current_subphase = SubPhase.CRUISE_MID
		_set_time_warp(2) # Speed up to 100x for cruise to crisis
		_show_advisory("★ MCC-1 BURN EXECUTED: Trajectory accuracy restored to %.1f%%." % trajectory_accuracy_pct)
		_update_flight_guidance()

func _enter_solar_crisis() -> void:
	current_subphase = SubPhase.SOLAR_CRISIS_ALERT
	_set_time_warp(0) # Halt warp
	_set_camera_mode(CamMode.CRISIS_TACTICAL)
	
	current_proton_flux_pfu = 1200.0
	_show_advisory("▲ SPACE WEATHER ALERT: Solar Energetic Particle (SEP) flux detected from Active Region AR-4890!")
	if tactical_crisis_panel:
		tactical_crisis_panel.visible = true
	_update_flight_guidance()

func _process_crisis_simulation(dt: float) -> void:
	storm_elapsed_hours += dt * 0.5 # Storm progresses
	
	# Proton Flux bell curve: peaks around hour 6, subsides by hour 18
	var storm_norm = clamp(storm_elapsed_hours / storm_duration_hours, 0.0, 1.0)
	var flux_factor = sin(storm_norm * PI)
	current_proton_flux_pfu = max(10.0, storm_peak_proton_flux_pfu * flux_factor)
	
	# Accumulated Radiation Dose (rads)
	# Rad-hard avionics absorbs dose at controlled rate
	var p_cfg = Helios4CampaignData.probe_config
	var is_rad_hard = (p_cfg.get("computer_type", "") == "comp_rad_hard_quad_core")
	var dose_rate = (current_proton_flux_pfu / 500.0) * (0.6 if is_rad_hard else 1.2) * (dt / 10.0)
	accumulated_radiation_dose_rad += dose_rate
	
	_process_power_and_systems(dt)
	
	# Check if storm has cleared
	if storm_elapsed_hours >= storm_duration_hours:
		current_subphase = SubPhase.SPACECRAFT_RECOVERY
		current_proton_flux_pfu = 8.5
		if tactical_crisis_panel:
			tactical_crisis_panel.visible = false
		_show_advisory("★ SOLAR STORM SUBSIDED: Proton flux below hazard limit. Begin spacecraft recovery.")
		_update_flight_guidance()

func _animate_solar_storm_visuals(dt: float) -> void:
	# Crisis storm light surges in amber intensity
	if crisis_storm_light:
		var pulse = 2.5 + sin(Time.get_ticks_msec() * 0.004) * 0.8
		crisis_storm_light.light_energy = pulse
		crisis_storm_light.visible = true
		
	if solar_flare_particles:
		solar_flare_particles.emitting = true
	if proton_stream_particles:
		proton_stream_particles.emitting = true

func _update_celestial_transforms() -> void:
	var progress = clamp(distance_km / TARGET_L1_DISTANCE_KM, 0.0, 1.0)
	
	# Earth recedes in rear (+Z direction)
	if earth_node:
		earth_node.position.z = 25.0 + progress * 95.0
		earth_node.position.x = 18.0 + progress * 15.0
		var earth_scale = max(0.2, 1.0 - progress * 0.75)
		earth_node.scale = Vector3.ONE * earth_scale
		
	# Sun grows slightly brighter ahead
	if sun_node:
		var sun_scale = 1.0 + progress * 0.25
		sun_node.scale = Vector3.ONE * sun_scale

# --- CAMERA SYSTEM (Zero Velocity Lag, Pure Perspective) ---

func _set_camera_mode(mode: CamMode) -> void:
	current_cam_mode = mode
	match mode:
		CamMode.CHASE_3_4:
			_cam_offset_target = Vector3(4.2, 1.8, 5.0)
			_cam_look_target = Vector3(0.0, 0.4, 0.0)
		CamMode.WIDE_TRAJECTORY:
			_cam_offset_target = Vector3(14.0, 6.0, 16.0)
			_cam_look_target = Vector3(-4.0, 1.0, -2.0)
		CamMode.SUNWARD_SENSORS:
			_cam_offset_target = Vector3(-1.2, 0.6, 1.8)
			_cam_look_target = Vector3(-8.0, 2.0, -12.0)
		CamMode.EARTH_DISH:
			_cam_offset_target = Vector3(0.8, 1.2, -2.4)
			_cam_look_target = Vector3(6.0, -1.0, 10.0)
		CamMode.CRISIS_TACTICAL:
			_cam_offset_target = Vector3(3.4, 1.3, 4.0)
			_cam_look_target = Vector3(0.0, 0.3, 0.0)
			
	_update_cam_buttons_visual()

func _update_camera(dt: float) -> void:
	if not deep_space_cam or not probe_node:
		return
		
	var target_cam_pos = probe_node.global_position + _cam_offset_target
	deep_space_cam.global_position = deep_space_cam.global_position.lerp(target_cam_pos, clamp(dt * 8.0, 0.0, 1.0))
	
	var target_look = probe_node.global_position + _cam_look_target
	deep_space_cam.look_at(target_look, Vector3.UP)

func _update_cam_buttons_visual() -> void:
	var btn_names = ["BtnCamChase", "BtnCamWide", "BtnCamSunward", "BtnCamEarth", "BtnCamCrisis"]
	for i in range(btn_names.size()):
		var b = find_child(btn_names[i], true, false) as Button
		if b:
			if i == int(current_cam_mode):
				b.modulate = Color(0.35, 0.95, 1.0)
			else:
				b.modulate = Color(0.7, 0.75, 0.8)

# --- USER INTERACTION & TACTICAL DECISIONS ---

func _set_time_warp(idx: int) -> void:
	current_warp_idx = clamp(idx, 0, time_warp_factors.size() - 1)
	var warp_btns = [btn_warp_1x, btn_warp_10x, btn_warp_100x, btn_warp_1000x]
	for i in range(warp_btns.size()):
		if warp_btns[i]:
			warp_btns[i].modulate = Color(0.35, 1.0, 0.55) if (i == current_warp_idx) else Color(0.7, 0.75, 0.8)

func _toggle_simulation_pause() -> void:
	is_sim_paused = not is_sim_paused
	if sim_pause_banner:
		sim_pause_banner.visible = is_sim_paused
	if btn_pause:
		btn_pause.text = "▶ RESUME" if is_sim_paused else "⏸ PAUSE"

func _select_crisis_option(card_idx: int, option_idx: int) -> void:
	match card_idx:
		1: # Safe Mode
			crisis_choice_safemode = option_idx
			_highlight_choice_btns([btn_safe_opt1, btn_safe_opt2, btn_safe_opt3], option_idx)
		2: # Instruments
			crisis_choice_instruments = option_idx
			_highlight_choice_btns([btn_inst_opt1, btn_inst_opt2, btn_inst_opt3], option_idx)
		3: # Comms & Power
			crisis_choice_comms = option_idx
			_highlight_choice_btns([btn_comm_opt1, btn_comm_opt2, btn_comm_opt3], option_idx)

func _highlight_choice_btns(btns: Array, active_idx: int) -> void:
	for i in range(btns.size()):
		if btns[i]:
			if (i + 1) == active_idx:
				btns[i].modulate = Color(1.0, 0.95, 0.4)
			else:
				btns[i].modulate = Color(0.65, 0.7, 0.8)

func _on_commit_crisis_pressed() -> void:
	crisis_decisions_committed = true
	
	# Apply Consequences of Decision 1: Safe Mode
	match crisis_choice_safemode:
		1: # Full Safe Mode
			is_in_safe_mode = true
			equipment_degradation_pct += 0.0
			science_bonus_pts -= 10.0
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_SYSTEMS,
				"Spacecraft Safe Mode",
				"Full Safe Mode Executed: Vulnerable optics de-energized. Zero equipment degradation."
			)
		2: # Partial Protection
			is_in_safe_mode = false
			equipment_degradation_pct += 5.0
			science_bonus_pts += 10.0
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_SYSTEMS,
				"Spacecraft Safe Mode",
				"Partial Protection Selected: Non-optical sensors kept active. Minor 5% degradation."
			)
		3: # Continue Science
			is_in_safe_mode = false
			equipment_degradation_pct += 18.0
			science_bonus_pts += 25.0
			Helios4CampaignData.record_team_decision(
				Helios4CampaignData.ROLE_SYSTEMS,
				"Spacecraft Safe Mode",
				"Continue Science Authorized: Full payload active through peak storm. 18% wear, +25 science pts."
			)
			
	# Apply Consequences of Decision 2: Instruments
	match crisis_choice_instruments:
		1: # Safe Optics
			instruments_active["faraday_cup"] = false
			instruments_active["magnetometer"] = true
			instruments_active["radiation_monitor"] = true
			instruments_health["faraday_cup"] = 100.0
		2: # Prioritize SEP
			instruments_active["faraday_cup"] = false
			instruments_active["magnetometer"] = false
			instruments_active["radiation_monitor"] = true
			science_bonus_pts += 15.0
		3: # Full Suite
			instruments_active["faraday_cup"] = true
			instruments_active["magnetometer"] = true
			instruments_active["radiation_monitor"] = true
			instruments_health["faraday_cup"] = 82.0 # damaged by storm
			science_bonus_pts += 30.0
			
	# Apply Consequences of Decision 3: Comms & Power
	match crisis_choice_comms:
		1: # Low power carrier
			comms_power_w = 15.0
		2: # High-rate dish
			comms_power_w = 45.0
			science_bonus_pts += 8.0
		3: # Memory buffer
			comms_power_w = 5.0
			
	current_subphase = SubPhase.CRISIS_SIMULATION
	_set_time_warp(1) # Run simulation through storm
	_show_advisory("★ CRISIS TACTICS COMMITTED: Running spacecraft storm survival simulation...")
	_update_flight_guidance()

func _on_primary_action_pressed() -> void:
	match current_subphase:
		SubPhase.PARKING_ORBIT:
			# Authorize Trans-L1 Injection Burn
			current_subphase = SubPhase.INJECTION_BURN
			burn_timer_s = 0.0
			_show_advisory("🚀 TLI IGNITION: Hyperbolic escape burn initiated toward Sun-Earth L1.")
			_update_flight_guidance()
			
		SubPhase.MIDCOURSE_CORRECTION:
			# Execute MCC-1 Burn
			# Calibrated burn: 16.2 kg fuel, restores accuracy to 99.6%
			if probe_propellant_kg >= 16.2:
				probe_propellant_kg -= 16.2
				trajectory_accuracy_pct = 99.6
				is_thruster_firing = true
				burn_timer_s = 0.0
				Helios4CampaignData.record_team_decision(
					Helios4CampaignData.ROLE_ASTROGATOR,
					"Trajectory Correction",
					"MCC-1 Burn Executed (-16.2 kg). Trajectory locked to L1 Halo entry corridor (99.6%)."
				)
				_show_advisory("🧭 MCC-1 BURN EXECUTED: Trajectory accuracy locked to 99.6%.")
				_update_flight_guidance()
				
		SubPhase.SOLAR_CRISIS_ALERT:
			_on_commit_crisis_pressed()
			
		SubPhase.SPACECRAFT_RECOVERY:
			_advance_recovery_step()
			
		SubPhase.L1_APPROACH_READY:
			_on_proceed_to_l1_arrival()

func _on_secondary_action_pressed() -> void:
	match current_subphase:
		SubPhase.CRUISE_EARLY, SubPhase.CRUISE_MID:
			# Align Solar Arrays Sunward
			solar_alignment_deg = 0.0
			_show_advisory("⚡ SYSTEMS: Solar wings aligned normal to Sun. Illumination efficiency 100%.")
			_update_flight_guidance()

func _advance_recovery_step() -> void:
	recovery_step += 1
	match recovery_step:
		1: # Restore Instruments
			instruments_active["faraday_cup"] = true
			instruments_active["magnetometer"] = true
			instruments_active["radiation_monitor"] = true
			is_in_safe_mode = false
			_show_advisory("⚡ RECOVERY: Eligible instruments powered up and verified.")
		2: # Restore Comms
			comms_power_w = 45.0
			_show_advisory("📡 RECOVERY: High-gain dish re-acquired Goldstone DSN carrier lock.")
		3: # Attitude Trim
			solar_alignment_deg = 0.0
			_show_advisory("🧭 RECOVERY: RCS attitude trim pulse fired. 3-axis pointing stabilized.")
		4: # Recovery Complete -> L1 Approach Ready
			current_subphase = SubPhase.L1_APPROACH_READY
			distance_km = 1485000.0 # Reached L1 threshold
			mission_elapsed_days = target_cruise_days
			_show_advisory("★ L1 APPROACH READY: Spacecraft verified for Sun-Earth L1 Halo-Orbit Insertion!")
	_update_flight_guidance()

func _on_proceed_to_l1_arrival() -> void:
	# Save authoritative transfer & crisis telemetry
	Helios4CampaignData.transfer_telemetry = {
		"distance_km": distance_km,
		"cruise_days": mission_elapsed_days,
		"trajectory_accuracy_pct": trajectory_accuracy_pct,
		"propellant_remaining_kg": probe_propellant_kg,
		"available_delta_v_ms": available_delta_v_ms,
		"battery_charge_wh": battery_charge_wh,
		"accumulated_dose_rad": accumulated_radiation_dose_rad
	}
	Helios4CampaignData.crisis_results = {
		"equipment_degradation_pct": equipment_degradation_pct,
		"science_bonus_pts": science_bonus_pts,
		"faraday_cup_health": instruments_health["faraday_cup"],
		"storm_peak_flux_pfu": storm_peak_proton_flux_pfu
	}
	Helios4CampaignData.save_campaign_state()
	
	print("[DeepSpace] Transfer & Crisis verified! Advancing to Stage 5: L1 Halo Insertion")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_5_L1_INSERTION, get_tree())

# --- HUD & FLIGHT GUIDANCE UPDATES ---

func _update_flight_guidance() -> void:
	if not lbl_phase:
		return
		
	match current_subphase:
		SubPhase.PARKING_ORBIT:
			lbl_phase.text = "PHASE 3A: EARTH PARKING ORBIT"
			lbl_status.text = "ORBITAL VELOCITY: 7.75 km/s • PERIGEE: 165 km"
			lbl_primary.text = "PRIMARY: Authorize Trans-L1 Deep Space Injection Burn (TLI)"
			lbl_action.text = "ACTION: Press [Space] or click EXECUTE INJECTION BURN to escape Earth orbit"
			lbl_next.text = "NEXT: Hyperbolic Escape Surge & Earth Departure"
			lbl_controls.text = "CONTROLS: [Space] Ignite Burn · [C] Switch Camera · [P] Pause"
			btn_primary_action.text = "🚀 EXECUTE INJECTION BURN"
			btn_primary_action.visible = true
			btn_primary_action.disabled = false
			btn_secondary_action.visible = false
			
		SubPhase.INJECTION_BURN:
			lbl_phase.text = "PHASE 3A: TRANS-L1 INJECTION BURN"
			lbl_status.text = "MAIN ENGINE FIRING: Accelerating to 10.95 km/s..."
			lbl_primary.text = "PRIMARY: Execute hyperbolic escape burn toward Sun-Earth L1"
			lbl_action.text = "ACTION: Hold attitude nominal during stage burn"
			lbl_next.text = "NEXT: Engine Cutoff & Interplanetary Coast"
			lbl_controls.text = "CONTROLS: Burn executing automatically"
			btn_primary_action.text = "🔥 FIRING APOGEE ENGINE..."
			btn_primary_action.disabled = true
			
		SubPhase.CRUISE_EARLY:
			lbl_phase.text = "PHASE 3B: INTERPLANETARY CRUISE (EARLY)"
			lbl_status.text = "DISTANCE: %.0f km • SPEED: %.2f km/s" % [distance_km, velocity_kms]
			lbl_primary.text = "PRIMARY: Track Sunward transfer arc & maintain solar array alignment"
			lbl_action.text = "ACTION: Engage Time Acceleration (10x / 100x) to cruise to MCC waypoint"
			lbl_next.text = "NEXT: Mid-Course Correction (MCC-1) at 300,000 km"
			lbl_controls.text = "CONTROLS: [1-4] Time Warp · [Space] Align Solar · [C] Camera"
			btn_primary_action.text = "⏩ TIME ACCELERATION ACTIVE"
			btn_primary_action.disabled = true
			btn_secondary_action.text = "⚡ ALIGN ARRAYS SUNWARD"
			btn_secondary_action.visible = true
			
		SubPhase.MIDCOURSE_CORRECTION:
			lbl_phase.text = "PHASE 3C: MID-COURSE CORRECTION (MCC-1)"
			lbl_status.text = "TRAJECTORY DRIFT: Trajectory Accuracy %.1f%% (Off-axis 3.8 m/s)" % trajectory_accuracy_pct
			lbl_primary.text = "PRIMARY: Correct trajectory drift to lock Sun-Earth L1 capture corridor"
			lbl_action.text = "ACTION: Press [Space] or click EXECUTE MCC-1 BURN (-16.2 kg propellant)"
			lbl_next.text = "NEXT: Trajectory Lock & Deep Space Cruise"
			lbl_controls.text = "CONTROLS: [Space] Fire RCS Trim · [C] Camera Mode"
			btn_primary_action.text = "🧭 EXECUTE MCC-1 BURN (-16.2 kg)"
			btn_primary_action.visible = true
			btn_primary_action.disabled = false
			btn_secondary_action.visible = false
			
		SubPhase.CRUISE_MID:
			lbl_phase.text = "PHASE 3D: INTERPLANETARY CRUISE (MID)"
			lbl_status.text = "TRAJECTORY LOCKED: Accuracy %.1f%% • DSN Link: %.1f dB" % [trajectory_accuracy_pct, dsn_signal_db]
			lbl_primary.text = "PRIMARY: Navigate probe toward Sun-Earth L1 midpoint"
			lbl_action.text = "ACTION: Use Time Acceleration to advance along Sunward transfer arc"
			lbl_next.text = "NEXT: Precursor Space Weather Anomaly at 750,000 km"
			lbl_controls.text = "CONTROLS: [1-4] Time Warp · [C] Camera"
			btn_primary_action.text = "⏩ TIME ACCELERATION ACTIVE"
			btn_primary_action.disabled = true
			btn_secondary_action.visible = false
			
		SubPhase.SOLAR_CRISIS_ALERT:
			lbl_phase.text = "PHASE 3E: SOLAR PARTICLE EVENT (SEP) ALERT"
			lbl_status.text = "▲ HAZARD ALERT: Proton Flux >1,200 pfu arriving from AR-4890"
			lbl_primary.text = "PRIMARY: Mitigate relativistic solar particle event via tactical response"
			lbl_action.text = "ACTION: Select Safe Mode, Instrument, and Comms options, then click COMMIT"
			lbl_next.text = "NEXT: Particle Storm Peak & Dynamic Survival Simulation"
			lbl_controls.text = "CONTROLS: Click Tactical Choices · Click COMMIT TACTICS"
			btn_primary_action.text = "▲ COMMIT TACTICAL DECISIONS"
			btn_primary_action.visible = true
			btn_primary_action.disabled = false
			btn_secondary_action.visible = false
			
		SubPhase.CRISIS_SIMULATION:
			lbl_phase.text = "PHASE 3E: SOLAR STORM PROPAGATION"
			lbl_status.text = "FLUX: %.0f pfu • ACCUMULATED DOSE: %.1f rad" % [current_proton_flux_pfu, accumulated_radiation_dose_rad]
			lbl_primary.text = "PRIMARY: Survive relativistic proton flux through configured defenses"
			lbl_action.text = "ACTION: Stand by while storm simulation runs its course"
			lbl_next.text = "NEXT: Storm Clearance & Spacecraft Recovery"
			lbl_controls.text = "CONTROLS: [P] Pause · [C] Camera Perspective"
			btn_primary_action.text = "⚡ STORM PROPAGATING..."
			btn_primary_action.disabled = true
			btn_secondary_action.visible = false
			
		SubPhase.SPACECRAFT_RECOVERY:
			lbl_phase.text = "PHASE 3F: SPACECRAFT POST-CRISIS RECOVERY"
			lbl_status.text = "STEP %d/4: RECOVERY PROCEDURE ACTIVE" % (recovery_step + 1)
			lbl_primary.text = "PRIMARY: Re-establish spacecraft health, comms, and science systems"
			var act_txt = "ACTION: Click to restore eligible instruments"
			if recovery_step == 1: act_txt = "ACTION: Click to re-establish Earth DSN carrier lock"
			elif recovery_step == 2: act_txt = "ACTION: Click to fire attitude stabilization RCS pulse"
			lbl_action.text = act_txt
			lbl_next.text = "NEXT: L1 Approach Region Preparation"
			lbl_controls.text = "CONTROLS: Click Next Recovery Step"
			btn_primary_action.text = "🔧 EXECUTE RECOVERY STEP (%d/3)" % (recovery_step + 1)
			btn_primary_action.visible = true
			btn_primary_action.disabled = false
			btn_secondary_action.visible = false
			
		SubPhase.L1_APPROACH_READY:
			lbl_phase.text = "PHASE 3G: L1 APPROACH REGION READY"
			lbl_status.text = "★ L1 PROXIMITY CONFIRMED (1,485,000 km / 1,500,000 km)"
			lbl_primary.text = "PRIMARY: Spacecraft verified for Sun-Earth L1 Halo-Orbit Insertion"
			lbl_action.text = "ACTION: Press [Space] or click PROCEED TO L1 HALO INSERTION (PART 4)"
			lbl_next.text = "NEXT: Phase 5 — L1 Halo Orbit Insertion & Commissioning"
			lbl_controls.text = "CONTROLS: [Space] Advance to Part 4"
			btn_primary_action.text = "★ L1 APPROACH READY — PROCEED TO PART 4 →"
			btn_primary_action.visible = true
			btn_primary_action.disabled = false
			btn_secondary_action.visible = false

func _update_telemetry_ui() -> void:
	if val_met:
		val_met.text = "T+%.0fd %02.0fh" % [mission_elapsed_days, mission_elapsed_hours]
	if val_distance:
		val_distance.text = "%.0f km / 1,500,000 km" % distance_km
	if val_velocity:
		val_velocity.text = "%.2f km/s" % velocity_kms
	if val_battery:
		var batt_pct = (battery_charge_wh / battery_capacity_wh) * 100.0
		val_battery.text = "%.0f%% (%.0f Wh)" % [batt_pct, battery_charge_wh]
	if val_power:
		var progress = clamp(distance_km / TARGET_L1_DISTANCE_KM, 0.0, 1.0)
		var solar_flux = lerp(1361.0, 1388.0, progress)
		var gen_w = solar_array_area_m2 * solar_efficiency * solar_flux * cos(deg_to_rad(solar_alignment_deg))
		val_power.text = "%.0f W" % gen_w
	if val_dsn:
		val_dsn.text = "%.1f dB" % dsn_signal_db
		
	# Progress Bars
	if bar_progress:
		bar_progress.value = clamp((distance_km / TARGET_L1_DISTANCE_KM) * 100.0, 0.0, 100.0)
	if val_fuel:
		val_fuel.text = "%.1f kg" % probe_propellant_kg
	if bar_fuel:
		bar_fuel.value = clamp((probe_propellant_kg / 320.0) * 100.0, 0.0, 100.0)
	if val_delta_v:
		val_delta_v.text = "%.0f m/s" % available_delta_v_ms
	if val_traj_accuracy:
		val_traj_accuracy.text = "%.1f%%" % trajectory_accuracy_pct
	if val_rad_dose:
		val_rad_dose.text = "%.1f rad" % accumulated_radiation_dose_rad
	if val_inst_health:
		val_inst_health.text = "FC: %.0f%% • MAG: %.0f%% • SEP: %.0f%%" % [
			instruments_health["faraday_cup"],
			instruments_health["magnetometer"],
			instruments_health["radiation_monitor"]
		]

func _show_advisory(msg: String) -> void:
	if advisory_banner:
		advisory_banner.text = msg
	print("[DeepSpace] ", msg)

func _log_ui_coordinates() -> void:
	var btns = [
		["BtnPrimaryAction", btn_primary_action],
		["BtnSecondaryAction", btn_secondary_action],
		["BtnCommitCrisis", btn_commit_crisis],
		["BtnSafeOpt1", btn_safe_opt1],
		["BtnSafeOpt2", btn_safe_opt2],
		["BtnSafeOpt3", btn_safe_opt3],
		["BtnInstOpt1", btn_inst_opt1],
		["BtnInstOpt2", btn_inst_opt2],
		["BtnInstOpt3", btn_inst_opt3],
		["BtnCommOpt1", btn_comm_opt1],
		["BtnCommOpt2", btn_comm_opt2],
		["BtnCommOpt3", btn_comm_opt3],
		["BtnWarp1x", btn_warp_1x],
		["BtnWarp10x", btn_warp_10x],
		["BtnWarp100x", btn_warp_100x],
		["BtnWarp1000x", btn_warp_1000x],
		["BtnPauseSim", btn_pause]
	]
	for item in btns:
		var name_str = item[0] as String
		var b = item[1] as Button
		if b and is_instance_valid(b):
			var rect = b.get_global_rect()
			print("[UI Coord Track] DeepSpace.%s -> (%d, %d)" % [name_str, int(rect.get_center().x), int(rect.get_center().y)])
