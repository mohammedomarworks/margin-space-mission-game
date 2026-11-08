class_name Helios4L1ArrivalController
extends Node3D

# ==============================================================================
# MARGIN — HELIOS-4: PART 4 — L1 HALO-ORBIT INSERTION & COMMISSIONING
# Location: Sun-Earth L1 region (~1.5 million km sunward from Earth)
# Halo Orbit: Periodic 3D orbit around L1 libration point (Educational Parametric Model)
# Commissioning: Magnetometer boom deployment, Faraday cup activation, live solar
# wind observation, CME shock detection, and Earth early-warning packet delivery.
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const SpacecraftMaterials = preload("res://margin/materials/spacecraft_materials.gd")

# Physical & Astrodynamic Constants
const G0: float = 9.80665
const L1_DISTANCE_KM: float = 1500000.0
const VISUAL_SCALE: float = 0.0001
const L1_POS: Vector3 = Vector3(-150.0, 0.0, 0.0)
const EARTH_POS: Vector3 = Vector3(0.0, 0.0, 0.0)
const SUN_POS: Vector3 = Vector3(-15000.0, 0.0, 0.0)

# Educational 3D parametric halo orbit parameters around Sun-Earth L1
# (Ax = Sun-Earth axis amplitude, Ay = in-plane amplitude, Az = out-of-plane amplitude)
# Note: This is an educational parametric visualization, not a numerically integrated CR3BP orbit.
const HALO_AX: float = 0.85
const HALO_AY: float = 2.4
const HALO_AZ: float = 3.4

# Compatibility Enum & New SubPhase State Machine
enum StageStep {
	APPROACH,
	HOI_BURN,
	STATIONKEEPING_VERIFY,
	BOOM_DEPLOY,
	FARADAY_ACTIVATE,
	EARTH_LINK,
	TRANSMIT_WARNING,
	COMMISSIONING_SUCCESS
}

enum SubPhase {
	STAGE_A_APPROACH_NAVIGATION,     # Inspect approach, calculate & execute approach trim burn
	STAGE_B_HOI_PLANNING,            # Preview halo orbit, adjust magnitude/direction, check propulsion readiness
	STAGE_B_HOI_EXECUTION,           # Main engine burn, delta-v expenditure, capture error assessment
	STAGE_C_STATIONKEEPING,          # Inspect orbit corridor, perform stationkeeping trim burn, verify >35kg threshold
	STAGE_D_COMMISSION_MAG,          # 3.8m boom deployment, stability check, power check, sensor calibration, measure background IMF
	STAGE_D_COMMISSION_FARADAY,      # Aperture door release, high-voltage sweep, calibration, measure solar wind plasma
	STAGE_D_SYSTEMS_VERIFY,          # Solar arrays sun tracking, battery surplus, thermal, avionics, antenna gimbal
	STAGE_E_SCIENTIFIC_OBSERVATION,  # Live observation session, live solar wind charts, detect CME shock from AR-4890, compile data packet
	STAGE_F_EARTH_COMM_LOCK,         # Antenna slew to Earth, establish DSN carrier (8.4 GHz), verify link margin (+4.2 dB)
	STAGE_F_TRANSMIT_WARNING,        # Authorize transmission, beam early warning packet, progress 0-100%, receive Earth ACK
	MISSION_SUCCESS_DEBRIEF          # HELIOS-4 COMMISSIONED, show summary, proceed to final debrief
}

enum CameraMode {
	CHASE,        # 0: 3/4 chase perspective
	WIDE,         # 1: Wide Sun-Earth-Spacecraft view
	HALO,         # 2: Orthogonal / isometric view of the 3D halo orbit
	MAG_BOOM,     # 3: Close-up of 3.8m magnetometer boom
	FARADAY_CUP,  # 4: Close-up of Faraday Cup plasma analyzer
	EARTH_DISH    # 5: Looking along high-gain antenna toward Earth
}

var current_phase: SubPhase = SubPhase.STAGE_A_APPROACH_NAVIGATION
var current_step: StageStep = StageStep.APPROACH # Kept for backward compatibility
var current_camera_mode: CameraMode = CameraMode.CHASE
var is_simulation_paused: bool = false
var mission_elapsed_time_s: float = 86400.0 * 110.0 # ~110 days transfer cruise

# --- SPACECRAFT PHYSICAL & SYSTEM STATE (Inherited from Parts 1-3) ---
var propellant_kg: float = 259.8
var dry_mass_kg: float = 372.4
var probe_isp_s: float = 315.0

var wet_mass_kg: float:
	get: return dry_mass_kg + propellant_kg

var available_delta_v_ms: float:
	get:
		if dry_mass_kg <= 0.0 or wet_mass_kg <= dry_mass_kg:
			return 0.0
		return probe_isp_s * G0 * log(wet_mass_kg / dry_mass_kg)

# Power & Battery
var battery_capacity_wh: float = 1200.0
var battery_charge_wh: float = 1180.0
var solar_power_w: float = 245.0
var spacecraft_power_load_w: float = 165.0
var net_power_surplus_w: float:
	get: return solar_power_w - spacecraft_power_load_w

# Inherited Instrument Health & Radiation Dose
var mag_health_pct: float = 100.0
var faraday_health_pct: float = 100.0
var accumulated_rad_dose_rad: float = 4.5
var equipment_degradation_pct: float = 0.0

# Trajectory & Navigation
var distance_to_earth_km: float = 1488000.0
var distance_to_l1_km: float = 12000.0
var relative_velocity_kms: float = 1.25
var trajectory_accuracy_pct: float = 99.2
var halo_stability_pct: float = 0.0
var halo_capture_error_pct: float = 0.0

# Maneuver Planning (Stage B)
var hoi_planned_delta_v_ms: float = 280.0
var hoi_min_delta_v_ms: float = 220.0
var hoi_max_delta_v_ms: float = 340.0
var hoi_burn_duration_s: float = 5.0
var hoi_burn_timer_s: float = 0.0
var is_engine_firing: bool = false
var is_rcs_firing: bool = false

# Commissioning Sub-states (Stage D)
var mag_boom_deployed: bool = false
var mag_stability_verified: bool = false
var mag_power_verified: bool = false
var mag_calibrated: bool = false
var mag_imf_reading: Vector3 = Vector3(4.2, -3.8, -5.4) # nT

var faraday_door_released: bool = false
var faraday_hv_sweep_verified: bool = false
var faraday_calibrated: bool = false
var faraday_cup_active: bool = false
var solar_wind_bulk_velocity_kms: float = 440.0
var solar_wind_proton_density_cm3: float = 8.5
var solar_wind_temp_k: float = 1.2e5

# Observation & CME Shock State (Stage E)
var observation_active: bool = false
var observation_time_s: float = 0.0
var cme_shock_detected: bool = false
var shock_velocity_km_s: float = 2420.0
var lead_time_minutes: float = 0.0
var early_warning_data_compiled: bool = false

# Earth Communication State (Stage F)
var antenna_slew_angle_deg: float = 0.0
var earth_comm_linked: bool = false
var dsn_signal_db: float = 4.2 # at 1.5M km
var dsn_frequency_ghz: float = 8.4
var transmission_authorized: bool = false
var transmission_progress_pct: float = 0.0
var earth_ack_received: bool = false
var warning_packet_sent: bool = false

# Halo Orbit Animation
var _halo_angle: float = 0.0

# 3D Node References
@onready var probe_node: Node3D = %ProbeNode
@onready var halo_ring: MeshInstance3D = %HaloOrbitRing
@onready var sun_mesh: MeshInstance3D = %SunMesh
@onready var earth_mesh: MeshInstance3D = %EarthMesh
@onready var camera: Camera3D = %Camera3D
@onready var l1_marker: Node3D = get_node_or_null("L1MarkerNode")

# Dynamic Spacecraft Components
var mag_boom: MeshInstance3D
var mag_head: MeshInstance3D
var faraday_cup: MeshInstance3D
var faraday_cover: MeshInstance3D
var engine_exhaust: CPUParticles3D
var rcs_particles: CPUParticles3D
var high_gain_dish: MeshInstance3D
var space_dust_emitter: CPUParticles3D
var starfield_cluster: Node3D

# Camera target interpolation & interactive orbit controls
var _cam_orbit_yaw: float = 0.0
var _cam_orbit_pitch: float = 0.0
var _cam_zoom_mult: float = 1.0
var _is_mouse_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# UI References
@onready var lbl_phase: Label = %LblObjectivePhase
@onready var lbl_status: Label = %LblObjectiveStatus
@onready var lbl_primary: Label = %LblObjectivePrimary
@onready var lbl_action: Label = %LblObjectiveAction
@onready var lbl_next: Label = %LblObjectiveNext
@onready var lbl_controls: Label = %LblObjectiveControls

@onready var val_met: Label = %ValMET
@onready var val_earth_dist: Label = %ValEarthDist
@onready var val_l1_dist: Label = %ValL1Dist
@onready var val_rel_vel: Label = %ValRelVel
@onready var val_fuel: Label = %ValFuel
@onready var val_delta_v: Label = %ValDeltaV
@onready var val_power: Label = %ValPower
@onready var val_battery: Label = %ValBattery
@onready var val_dsn: Label = %ValDSN

@onready var action_btn: Button = %CommissionActionBtn
@onready var secondary_btn: Button = %SecondaryActionBtn
@onready var proceed_debrief_btn: Button = %ProceedToDebriefBtn
@onready var pause_btn: Button = %BtnPauseSim
@onready var advisory_lbl: Label = %CommissionStatusBanner
@onready var step_desc_lbl: Label = %StepDescription
@onready var fuel_reserve_lbl: Label = %FuelReserveLabel
@onready var warning_time_lbl: Label = %WarningTimeLabel
@onready var telemetry_data_lbl: Label = %TelemetryDataLabel

# Contextual Detail Panel Container
@onready var detail_deck: PanelContainer = %DetailDeck
@onready var detail_title_lbl: Label = %DetailTitleLabel
@onready var detail_body_lbl: Label = %DetailBodyLabel
@onready var detail_metric_lbl: Label = %DetailMetricLabel
@onready var progress_bar: ProgressBar = %DetailProgressBar

# Pause Banner
@onready var sim_pause_banner: PanelContainer = %SimPauseBanner

func _ready() -> void:
	_load_inherited_campaign_state()
	lead_time_minutes = Helios4CampaignData.calculate_warning_lead_time_minutes(shock_velocity_km_s, L1_DISTANCE_KM)
	
	if earth_mesh:
		earth_mesh.position = EARTH_POS
		earth_mesh.scale = Vector3.ONE
	if sun_mesh:
		sun_mesh.position = SUN_POS
		sun_mesh.scale = Vector3.ONE
		
	_build_probe_visual()
	_update_halo_orbit_visual()
	_build_l1_marker_visual()
	_build_starfield()
	
	_setup_ui_connections()
	_set_camera_mode(CameraMode.CHASE)
	_load_subphase(current_phase)
	
	get_tree().process_frame.connect(func():
		if action_btn: print("[L1Arrival] CommissionActionBtn center: ", action_btn.get_global_rect().get_center())
		if secondary_btn: print("[L1Arrival] SecondaryActionBtn center: ", secondary_btn.get_global_rect().get_center())
		if proceed_debrief_btn: print("[L1Arrival] ProceedToDebriefBtn center: ", proceed_debrief_btn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _load_inherited_campaign_state() -> void:
	# Inherit telemetry from Part 3 Transfer / Crisis without resets
	var transfer_rem = Helios4CampaignData.transfer_telemetry.get("propellant_remaining_kg", -1.0)
	if transfer_rem > 0.0:
		propellant_kg = transfer_rem
	else:
		var crisis_lost = Helios4CampaignData.crisis_results.get("propellant_lost_kg", 0.0)
		var base_prop = Helios4CampaignData.probe_config.get("propellant_mass_kg", 320.0)
		propellant_kg = max(20.0, base_prop - 60.2 - crisis_lost) # ~259.8 kg
	
	dry_mass_kg = Helios4CampaignData.probe_config.get("dry_mass_kg", 372.4)
	probe_isp_s = Helios4CampaignData.probe_config.get("probe_isp_s", 315.0)
	
	# Inherit Instrument health & radiation
	var inherited_inst = Helios4CampaignData.transfer_telemetry.get("instruments_health", {})
	if not inherited_inst.is_empty():
		mag_health_pct = inherited_inst.get("magnetometer", 100.0)
		faraday_health_pct = inherited_inst.get("faraday_cup", 100.0)
	else:
		var crisis_deg = Helios4CampaignData.crisis_results.get("equipment_degradation_pct", 0.0)
		mag_health_pct = max(50.0, 100.0 - crisis_deg)
		faraday_health_pct = max(50.0, 100.0 - crisis_deg * 1.5)
	
	accumulated_rad_dose_rad = Helios4CampaignData.transfer_telemetry.get("accumulated_radiation_dose_rad", 4.5)
	equipment_degradation_pct = Helios4CampaignData.crisis_results.get("equipment_degradation_pct", 0.0)
	battery_charge_wh = Helios4CampaignData.transfer_telemetry.get("battery_charge_wh", 1180.0)
	trajectory_accuracy_pct = Helios4CampaignData.transfer_telemetry.get("trajectory_accuracy_pct", 99.2)

func _process(delta: float) -> void:
	if is_simulation_paused:
		return
		
	mission_elapsed_time_s += delta
	
	# Animate probe in periodic 3D halo orbit when captured
	if current_phase >= SubPhase.STAGE_B_HOI_EXECUTION and not is_engine_firing:
		_halo_angle += delta * 0.35
		var pos = L1_POS + Vector3(
			-HALO_AX * cos(2.0 * _halo_angle),
			HALO_AY * sin(_halo_angle),
			HALO_AZ * cos(_halo_angle)
		)
		if probe_node:
			probe_node.position = pos
			var tan_vel = Vector3(
				2.0 * HALO_AX * sin(2.0 * _halo_angle),
				HALO_AY * cos(_halo_angle),
				-HALO_AZ * sin(_halo_angle)
			)
			if tan_vel.length_squared() > 0.001:
				var up_dir = Vector3.UP if abs(tan_vel.normalized().dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
				probe_node.look_at(probe_node.position + tan_vel.normalized(), up_dir)
	elif current_phase < SubPhase.STAGE_B_HOI_EXECUTION and probe_node:
		# Approach flight toward L1
		var approach_offset = (distance_to_l1_km / 12000.0) * 4.0
		probe_node.position = L1_POS + Vector3(approach_offset, 1.2 + approach_offset * 0.3, approach_offset)
		probe_node.look_at(L1_POS, Vector3.UP)
		
	# Process active burns
	if is_engine_firing:
		_process_hoi_burn(delta)
		
	# Process live observation session
	if observation_active and current_phase == SubPhase.STAGE_E_SCIENTIFIC_OBSERVATION:
		_process_scientific_observation(delta)
		
	# Process early warning transmission
	if transmission_authorized and current_phase == SubPhase.STAGE_F_TRANSMIT_WARNING:
		_process_transmission(delta)
		
	# Rotate Earth
	if earth_mesh:
		earth_mesh.rotation.y += delta * 0.06
		
	if starfield_cluster and probe_node:
		starfield_cluster.global_position = probe_node.global_position
		
	# Update particle space dust velocity
	_update_space_dust(delta)
	
	# Update camera tracking
	_update_camera_transform(delta)
	
	# Update HUD telemetry
	_update_telemetry_ui()

func _update_camera_transform(delta: float) -> void:
	if not camera or not probe_node:
		return
		
	var target_pos := probe_node.global_position
	var base_offset := Vector3(3.4, 2.0, 5.2)
	var look_target := target_pos + Vector3(0.0, 0.2, 0.0)
	var anchor_pos := target_pos
	var cam_up := Vector3.UP
	
	match current_camera_mode:
		CameraMode.CHASE:
			base_offset = Vector3(3.4, 2.0, 5.2)
			look_target = target_pos + Vector3(0.0, 0.2, 0.0)
		CameraMode.WIDE:
			anchor_pos = L1_POS
			base_offset = Vector3(14.0, 16.0, 32.0)
			look_target = L1_POS
		CameraMode.HALO:
			anchor_pos = L1_POS
			base_offset = Vector3(0.0, 24.0, 0.2)
			look_target = L1_POS
			cam_up = Vector3.FORWARD
		CameraMode.MAG_BOOM:
			base_offset = Vector3(1.2, 1.6, -2.6)
			look_target = target_pos + Vector3(0.3, 0.8, -1.8)
		CameraMode.FARADAY_CUP:
			base_offset = Vector3(-1.8, 1.4, -1.2)
			look_target = target_pos + Vector3(-0.4, 0.6, -0.6)
		CameraMode.EARTH_DISH:
			base_offset = Vector3(-3.2, 0.9, 0.0)
			look_target = target_pos + Vector3(25.0, 0.0, 0.0)

	var yaw_basis = Basis(Vector3.UP, _cam_orbit_yaw)
	var pitch_basis = Basis(Vector3.RIGHT, _cam_orbit_pitch)
	var orbit_basis = yaw_basis * pitch_basis
	
	var final_offset = orbit_basis * (base_offset * _cam_zoom_mult)
	var desired_cam_pos = anchor_pos + final_offset
	
	if delta <= 0.0:
		camera.global_position = desired_cam_pos
	else:
		camera.global_position = camera.global_position.lerp(desired_cam_pos, clamp(delta * 8.0, 0.0, 1.0))
		
	camera.look_at(look_target, cam_up)

func _set_camera_mode(mode: CameraMode) -> void:
	current_camera_mode = mode
	_cam_orbit_yaw = 0.0
	_cam_orbit_pitch = 0.0
	_cam_zoom_mult = 1.0
	_update_camera_transform(0.0)

# --- 3D VISUAL BUILDERS ---

func _build_probe_visual() -> void:
	if not probe_node:
		return
	for c in probe_node.get_children():
		c.queue_free()
		
	# 1. Central Bus (Gold MLI)
	var bus := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(1.2, 1.2, 1.2)
	bus.mesh = b_box
	bus.material_override = SpacecraftMaterials.get_mat("gold_mli")
	probe_node.add_child(bus)
	
	# 2. Articulated Photovoltaic Solar Wings (Dual panels along Z-axis)
	for dir in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(2.2, 0.85, 0.04)
		panel.mesh = p_box
		panel.position = Vector3(0.0, 0.0, dir * 1.85)
		panel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		panel.material_override = SpacecraftMaterials.get_mat("solar_panel")
		probe_node.add_child(panel)
		
	# 3. High-Gain Cassegrain Dish Reflector (Facing Earth along +X)
	high_gain_dish = MeshInstance3D.new()
	var d_sph := SphereMesh.new()
	d_sph.radius = 0.65
	d_sph.height = 0.32
	high_gain_dish.mesh = d_sph
	high_gain_dish.position = Vector3(0.68, 0.6, 0.0)
	high_gain_dish.rotation_degrees = Vector3(0.0, 0.0, -90.0) if earth_comm_linked else Vector3(22.0, 15.0, -90.0)
	high_gain_dish.material_override = SpacecraftMaterials.get_mat("antenna_reflector")
	probe_node.add_child(high_gain_dish)
	
	var feed_horn := MeshInstance3D.new()
	var f_cyl := CylinderMesh.new()
	f_cyl.top_radius = 0.03
	f_cyl.bottom_radius = 0.05
	f_cyl.height = 0.25
	feed_horn.mesh = f_cyl
	feed_horn.position = Vector3(0.9, 0.6, 0.0)
	feed_horn.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	feed_horn.material_override = SpacecraftMaterials.get_mat("antenna_feed")
	probe_node.add_child(feed_horn)
	
	# 4. Triaxial Magnetometer Boom (3.8m deployable carbon fiber boom)
	mag_boom = MeshInstance3D.new()
	var m_cyl = CylinderMesh.new()
	m_cyl.top_radius = 0.035
	m_cyl.bottom_radius = 0.045
	m_cyl.height = 3.8
	mag_boom.mesh = m_cyl
	mag_boom.position = Vector3(0.4, 0.5, -2.1)
	mag_boom.rotation_degrees = Vector3(68.0, 15.0, 0.0)
	mag_boom.scale.y = 1.0 if mag_boom_deployed else 0.12
	mag_boom.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
	probe_node.add_child(mag_boom)
	
	mag_head = MeshInstance3D.new()
	var mh_box := BoxMesh.new()
	mh_box.size = Vector3(0.24, 0.24, 0.24)
	mag_head.mesh = mh_box
	mag_head.position = Vector3(0.0, 1.95 if mag_boom_deployed else 0.24, 0.0)
	mag_head.material_override = SpacecraftMaterials.get_mat("gold_mli")
	mag_boom.add_child(mag_head)
	
	# 5. Faraday Cup Solar Wind Plasma Analyzer
	faraday_cup = MeshInstance3D.new()
	var fc_cyl = CylinderMesh.new()
	fc_cyl.top_radius = 0.13
	fc_cyl.bottom_radius = 0.09
	fc_cyl.height = 0.28
	faraday_cup.mesh = fc_cyl
	faraday_cup.position = Vector3(-0.45, 0.75, -0.75)
	faraday_cup.rotation_degrees = Vector3(40.0, -25.0, 0.0)
	faraday_cup.material_override = SpacecraftMaterials.get_mat("sensor_lens")
	probe_node.add_child(faraday_cup)

	# Faraday Cup Deployable Aperture Cover
	faraday_cover = MeshInstance3D.new()
	faraday_cover.name = "FaradayCover"
	var cov_mesh = CylinderMesh.new()
	cov_mesh.top_radius = 0.14
	cov_mesh.bottom_radius = 0.14
	cov_mesh.height = 0.02
	faraday_cover.mesh = cov_mesh
	faraday_cover.position = Vector3(0.0, 0.14, 0.0)
	faraday_cover.rotation_degrees.x = 115.0 if faraday_door_released else 0.0
	faraday_cover.material_override = SpacecraftMaterials.get_mat("gold_mli")
	faraday_cup.add_child(faraday_cover)
	
	# 6. Main Engine Bell (Aft base)
	var engine := MeshInstance3D.new()
	var e_cyl := CylinderMesh.new()
	e_cyl.top_radius = 0.16
	e_cyl.bottom_radius = 0.32
	e_cyl.height = 0.5
	engine.mesh = e_cyl
	engine.position = Vector3(0.0, -0.95, 0.0)
	engine.material_override = SpacecraftMaterials.get_mat("thruster_nozzle")
	probe_node.add_child(engine)
	
	# Engine Exhaust CPUParticles3D
	engine_exhaust = CPUParticles3D.new()
	engine_exhaust.emitting = false
	engine_exhaust.amount = 64
	engine_exhaust.lifetime = 0.35
	engine_exhaust.speed_scale = 1.8
	engine_exhaust.direction = Vector3(0.0, -1.0, 0.0)
	engine_exhaust.spread = 12.0
	engine_exhaust.initial_velocity_min = 12.0
	engine_exhaust.initial_velocity_max = 18.0
	engine_exhaust.color = Color(0.4, 0.8, 1.0, 0.85)
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 0.08
	p_mesh.height = 0.16
	engine_exhaust.mesh = p_mesh
	engine_exhaust.position = Vector3(0.0, -1.25, 0.0)
	probe_node.add_child(engine_exhaust)
	
	# RCS Thruster Plumes
	rcs_particles = CPUParticles3D.new()
	rcs_particles.emitting = false
	rcs_particles.amount = 24
	rcs_particles.lifetime = 0.2
	rcs_particles.direction = Vector3(1.0, 0.0, 0.0)
	rcs_particles.spread = 20.0
	rcs_particles.initial_velocity_min = 4.0
	rcs_particles.initial_velocity_max = 6.0
	var r_mesh = SphereMesh.new()
	r_mesh.radius = 0.04
	r_mesh.height = 0.08
	rcs_particles.mesh = r_mesh
	rcs_particles.position = Vector3(0.7, -0.6, 0.0)
	probe_node.add_child(rcs_particles)

	# 7. Space Dust Particle Emitter for Orbital Speed Feedback
	space_dust_emitter = CPUParticles3D.new()
	space_dust_emitter.name = "SpaceDustParticles"
	space_dust_emitter.emitting = true
	space_dust_emitter.amount = 160
	space_dust_emitter.lifetime = 1.2
	space_dust_emitter.speed_scale = 1.0
	space_dust_emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	space_dust_emitter.emission_box_extents = Vector3(14.0, 14.0, 14.0)

	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.albedo_color = Color(0.65, 0.88, 1.0, 0.75)
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.emission_enabled = true
	dust_mat.emission = Color(0.55, 0.82, 1.0)
	dust_mat.emission_energy_multiplier = 2.5

	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.03
	dust_mesh.height = 0.06
	dust_mesh.material = dust_mat

	space_dust_emitter.mesh = dust_mesh
	space_dust_emitter.gravity = Vector3.ZERO
	probe_node.add_child(space_dust_emitter)

func _update_halo_orbit_visual() -> void:
	if not halo_ring:
		return
	halo_ring.mesh = _generate_halo_tube_mesh(HALO_AX, HALO_AY, HALO_AZ, 0.065, 64, 8)
	halo_ring.position = L1_POS
	halo_ring.rotation_degrees = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.74, 0.96, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.65, 0.95)
	mat.emission_energy_multiplier = 2.2
	halo_ring.material_override = mat

func _build_l1_marker_visual() -> void:
	if l1_marker:
		return
	l1_marker = Node3D.new()
	l1_marker.name = "L1MarkerNode"
	l1_marker.position = L1_POS
	add_child(l1_marker)
	
	# 3D diamond wireframe marker at (0, 0, 0)
	var diamond := MeshInstance3D.new()
	var d_cyl := CylinderMesh.new()
	d_cyl.top_radius = 0.0
	d_cyl.bottom_radius = 0.35
	d_cyl.height = 0.7
	diamond.mesh = d_cyl
	diamond.position = Vector3(0.0, 0.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	diamond.material_override = mat
	l1_marker.add_child(diamond)

func _generate_halo_tube_mesh(ax: float, ay: float, az: float, tube_radius: float = 0.06, num_curve_pts: int = 64, num_tube_sides: int = 8) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	
	var curve_pts: Array[Vector3] = []
	var tangents: Array[Vector3] = []
	var normals_arr: Array[Vector3] = []
	var binormals: Array[Vector3] = []
	
	for i in range(num_curve_pts):
		var phi = (float(i) / float(num_curve_pts)) * TAU
		var pt = Vector3(
			-ax * cos(2.0 * phi),
			ay * sin(phi),
			az * cos(phi)
		)
		var tan = Vector3(
			2.0 * ax * sin(2.0 * phi),
			ay * cos(phi),
			-az * sin(phi)
		).normalized()
		
		var approx_up = Vector3.UP if abs(tan.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
		var norm = tan.cross(approx_up).normalized()
		var binorm = tan.cross(norm).normalized()
		
		curve_pts.append(pt)
		tangents.append(tan)
		normals_arr.append(norm)
		binormals.append(binorm)
		
	for i in range(num_curve_pts):
		var center = curve_pts[i]
		var norm = normals_arr[i]
		var binorm = binormals[i]
		
		for j in range(num_tube_sides):
			var theta = (float(j) / float(num_tube_sides)) * TAU
			var local_dir = (norm * cos(theta) + binorm * sin(theta)).normalized()
			var v = center + local_dir * tube_radius
			vertices.append(v)
			normals.append(local_dir)
			
	for i in range(num_curve_pts):
		var next_i = (i + 1) % num_curve_pts
		for j in range(num_tube_sides):
			var next_j = (j + 1) % num_tube_sides
			
			var idx00 = i * num_tube_sides + j
			var idx01 = i * num_tube_sides + next_j
			var idx10 = next_i * num_tube_sides + j
			var idx11 = next_i * num_tube_sides + next_j
			
			indices.append(idx00)
			indices.append(idx10)
			indices.append(idx01)
			indices.append(idx01)
			indices.append(idx10)
			indices.append(idx11)
			
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh

# --- IMMERSION HELPERS & DYNAMIC ANIMATIONS ---

func _build_starfield() -> void:
	if starfield_cluster:
		return
	starfield_cluster = Node3D.new()
	starfield_cluster.name = "SpatialStarfield"
	add_child(starfield_cluster)

	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.9, 0.95, 1.0)
	star_mat.emission_energy_multiplier = 3.5

	var im := ImmediateMesh.new()
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_POINTS, star_mat)

	var rng = RandomNumberGenerator.new()
	rng.seed = 8844
	for i in range(180):
		var radius = rng.randf_range(35.0, 140.0)
		var theta = rng.randf_range(0.0, TAU)
		var phi = rng.randf_range(-PI * 0.45, PI * 0.45)
		var pos = Vector3(
			radius * cos(phi) * cos(theta),
			radius * sin(phi),
			radius * cos(phi) * sin(theta)
		)
		im.surface_add_vertex(pos)

	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	starfield_cluster.add_child(mi)

func _update_space_dust(_delta: float) -> void:
	if not space_dust_emitter or not probe_node:
		return
	if is_simulation_paused:
		space_dust_emitter.speed_scale = 0.0
		return
	space_dust_emitter.speed_scale = 1.0
	
	var tan_vel = Vector3.FORWARD
	if current_phase >= SubPhase.STAGE_B_HOI_EXECUTION and not is_engine_firing:
		tan_vel = Vector3(
			2.0 * HALO_AX * sin(2.0 * _halo_angle),
			HALO_AY * cos(_halo_angle),
			-HALO_AZ * sin(_halo_angle)
		)
	else:
		tan_vel = Vector3(0.0, 0.0, -1.0)
		
	var stream_dir = probe_node.global_transform.basis.inverse() * (-tan_vel.normalized())
	space_dust_emitter.direction = stream_dir.normalized()
	space_dust_emitter.initial_velocity_min = 10.0
	space_dust_emitter.initial_velocity_max = 16.0

func _animate_mag_boom_deployment() -> void:
	if not mag_boom or not mag_head:
		return
	var tween = create_tween()
	tween.tween_property(mag_boom, "scale:y", 1.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mag_head, "position:y", 1.95, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		var settle = create_tween()
		settle.tween_property(mag_boom, "rotation_degrees:z", 3.0, 0.15)
		settle.tween_property(mag_boom, "rotation_degrees:z", -1.5, 0.2)
		settle.tween_property(mag_boom, "rotation_degrees:z", 0.0, 0.25)
	)

func _animate_faraday_cover_release() -> void:
	if not faraday_cover:
		return
	var tween = create_tween()
	tween.tween_property(faraday_cover, "rotation_degrees:x", 115.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_dish_earth_lock() -> void:
	if not high_gain_dish:
		return
	var tween = create_tween()
	tween.tween_property(high_gain_dish, "rotation_degrees", Vector3(0.0, 0.0, -90.0), 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

# --- UI SETUP & INPUT ---

func _setup_ui_connections() -> void:
	if action_btn: action_btn.pressed.connect(_on_primary_action_pressed)
	if secondary_btn: secondary_btn.pressed.connect(_on_secondary_action_pressed)
	if proceed_debrief_btn: proceed_debrief_btn.pressed.connect(_on_proceed_to_debrief_pressed)
	if pause_btn: pause_btn.pressed.connect(_toggle_simulation_pause)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_mouse_dragging = mb.pressed
			_last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_cam_zoom_mult = clamp(_cam_zoom_mult * 0.9, 0.35, 3.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_cam_zoom_mult = clamp(_cam_zoom_mult * 1.1, 0.35, 3.5)
		return

	if event is InputEventMouseMotion and _is_mouse_dragging:
		var mm = event as InputEventMouseMotion
		_cam_orbit_yaw -= mm.relative.x * 0.006
		_cam_orbit_pitch = clamp(_cam_orbit_pitch - mm.relative.y * 0.006, -1.35, 1.35)
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				_cam_orbit_yaw += 0.1
			KEY_RIGHT:
				_cam_orbit_yaw -= 0.1
			KEY_UP:
				_cam_orbit_pitch = clamp(_cam_orbit_pitch + 0.1, -1.35, 1.35)
			KEY_DOWN:
				_cam_orbit_pitch = clamp(_cam_orbit_pitch - 0.1, -1.35, 1.35)
			KEY_EQUAL, KEY_PLUS:
				_cam_zoom_mult = clamp(_cam_zoom_mult * 0.9, 0.35, 3.5)
			KEY_MINUS:
				_cam_zoom_mult = clamp(_cam_zoom_mult * 1.1, 0.35, 3.5)
			KEY_1: _set_camera_mode(CameraMode.CHASE)
			KEY_2: _set_camera_mode(CameraMode.WIDE)
			KEY_3: _set_camera_mode(CameraMode.HALO)
			KEY_4: _set_camera_mode(CameraMode.MAG_BOOM)
			KEY_5: _set_camera_mode(CameraMode.FARADAY_CUP)
			KEY_6: _set_camera_mode(CameraMode.EARTH_DISH)
			KEY_P: _toggle_simulation_pause()
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if current_phase == SubPhase.MISSION_SUCCESS_DEBRIEF:
					_on_proceed_to_debrief_pressed()
				else:
					_on_primary_action_pressed()
			KEY_TAB:
				_cycle_active_role()

func _cycle_active_role() -> void:
	var roles = [
		Helios4CampaignData.ROLE_PROPULSION,
		Helios4CampaignData.ROLE_STRUCTURAL,
		Helios4CampaignData.ROLE_ASTROGATOR,
		Helios4CampaignData.ROLE_SYSTEMS
	]
	var current_idx = roles.find(Helios4CampaignData.active_role)
	var next_idx = (current_idx + 1) % roles.size()
	Helios4CampaignData.active_role = roles[next_idx]
	_update_telemetry_ui()

func _toggle_simulation_pause() -> void:
	is_simulation_paused = not is_simulation_paused
	if sim_pause_banner:
		sim_pause_banner.visible = is_simulation_paused
	if pause_btn:
		pause_btn.text = "▶ RESUME" if is_simulation_paused else "⏸ PAUSE"

# --- GAMEPLAY STAGE LOGIC & ADVANCEMENT ---

func _load_subphase(phase: SubPhase) -> void:
	current_phase = phase
	
	match phase:
		SubPhase.STAGE_A_APPROACH_NAVIGATION:
			current_step = StageStep.APPROACH
			if lbl_phase: lbl_phase.text = "PHASE 5: SUN-EARTH L1 ORBITAL APPROACH"
			if lbl_status: lbl_status.text = "CORRIDOR ACCURACY: %.1f%% • L1 REGION DISTANCE: 12,000 km" % trajectory_accuracy_pct
			if lbl_primary: lbl_primary.text = "Inspect L1 approach corridor and execute approach navigation trim burn."
			if lbl_action: lbl_action.text = "Astrogator: Click EXECUTE APPROACH TRIM BURN [Space/Enter]"
			if lbl_next: lbl_next.text = "Next: Halo-Orbit Insertion (HOI) maneuver planning."
			if lbl_controls: lbl_controls.text = "Controls: [1-6] Camera Modes • [P] Pause • [Tab] Switch Officer"
			
			if action_btn:
				action_btn.visible = true
				action_btn.text = "🧭 EXECUTE APPROACH TRIM BURN (-2.4 kg) →"
			if secondary_btn:
				secondary_btn.visible = true
				secondary_btn.text = "FINE-TUNE APPROACH TRAJECTORY"
			if proceed_debrief_btn:
				proceed_debrief_btn.visible = false
				
			if detail_deck: detail_deck.visible = true
			if detail_title_lbl: detail_title_lbl.text = "STAGE A: SUN-EARTH L1 APPROACH NAVIGATION"
			if detail_body_lbl:
				detail_body_lbl.text = "HELIOS-4 has completed its 1.5M km transfer cruise. Approaching target insertion window at Sun-Earth L1.\n" + \
					"• Distance to Earth: %.1f km (1.488M km Sunward)\n" % distance_to_earth_km + \
					"• Relative Approach Velocity: %.2f km/s\n" % relative_velocity_kms + \
					"• Maneuver Requirement: RCS approach trim burn (Δv = 18.5 m/s) to eliminate dispersion."
			if detail_metric_lbl: detail_metric_lbl.text = "Available Delta-V: %.1f m/s • Propellant: %.1f kg" % [available_delta_v_ms, propellant_kg]
			if progress_bar: progress_bar.value = 92.0
			
			if advisory_lbl:
				advisory_lbl.text = "● APPROACHING L1 REGION: Prepare for insertion corridor alignment."
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95))
				
		SubPhase.STAGE_B_HOI_PLANNING:
			current_step = StageStep.APPROACH
			if lbl_phase: lbl_phase.text = "STAGE B: HALO-ORBIT INSERTION PLANNING"
			if lbl_status: lbl_status.text = "PREVIEWING 3D PERIODIC HALO ORBIT CORRIDOR"
			if lbl_primary: lbl_primary.text = "Configure HOI braking burn magnitude and authorize main propulsion ignition."
			if lbl_action: lbl_action.text = "Propulsion & Astrogator: Review burn parameters and click AUTHORIZE & EXECUTE HOI BURN"
			if lbl_next: lbl_next.text = "Next: Orbit capture verification & stationkeeping stabilization."
			
			if action_btn:
				action_btn.visible = true
				action_btn.text = "🚀 EXECUTE HOI INSERTION BURN (-35.0 kg) →"
			if secondary_btn:
				secondary_btn.visible = true
				if secondary_btn: secondary_btn.text = "TUNE BURN MAGNITUDE (%.0f m/s)" % hoi_planned_delta_v_ms
				
			if detail_deck: detail_deck.visible = true
			if detail_title_lbl: detail_title_lbl.text = "HALO-ORBIT INSERTION (HOI) MANEUVER PLANNING"
			if detail_body_lbl:
				detail_body_lbl.text = "Collinear Sun-Earth L1 is an unstable saddle equilibrium requiring insertion into a periodic 3D halo orbit:\n" + \
					"• Planned Braking Δv: %.1f m/s (Propellant required: ~35.0 kg)\n" % hoi_planned_delta_v_ms + \
					"• Burn Direction: Retrograde / Saddle-manifold alignment\n" + \
					"• Target Amplitudes: Ax=%.2f, Ay=%.2f, Az=%.2f (Educational Parametric Model)\n" % [HALO_AX, HALO_AY, HALO_AZ] + \
					"• Scientific Label: Educational 3D model; not full CR3BP numerical propagation."
			if detail_metric_lbl: detail_metric_lbl.text = "Planned Δv: %.1f m/s • Target Capture Error: < 0.5%%" % hoi_planned_delta_v_ms
			if progress_bar: progress_bar.value = 50.0
			
			if advisory_lbl:
				advisory_lbl.text = "★ PROPULSION READY: Main engine pressurized (2.4 MPa). Ready for HOI burn."
				advisory_lbl.add_theme_color_override("font_color", Color(0.98, 0.75, 0.2))
				
		SubPhase.STAGE_B_HOI_EXECUTION:
			current_step = StageStep.HOI_BURN
			_start_hoi_burn_execution()
			
		SubPhase.STAGE_C_STATIONKEEPING:
			current_step = StageStep.STATIONKEEPING_VERIFY
			if lbl_phase: lbl_phase.text = "STAGE C: ORBIT STABILIZATION & STATIONKEEPING"
			var sk_ok = (propellant_kg >= 35.0)
			if lbl_status: lbl_status.text = "STATIONKEEPING RESERVE: %.1f kg (%s)" % [propellant_kg, "NOMINAL" if sk_ok else "DEGRADED"]
			if lbl_primary: lbl_primary.text = "Assess halo orbit corridor deviation and execute stationkeeping trim burn."
			if lbl_action: lbl_action.text = "Propulsion Engineer: Click EXECUTE STATIONKEEPING TRIM BURN"
			if lbl_next: lbl_next.text = "Next: Instrument Commissioning (Magnetometer & Faraday Cup)."
			
			if action_btn:
				action_btn.visible = true
				action_btn.text = "⚡ EXECUTE STATIONKEEPING TRIM BURN (-8.5 kg) →"
			if secondary_btn:
				secondary_btn.visible = false
				
			if detail_deck: detail_deck.visible = true
			if detail_title_lbl: detail_title_lbl.text = "SUN-EARTH L1 HALO-ORBIT STABILIZATION"
			if detail_body_lbl:
				detail_body_lbl.text = "Spacecraft captured into 3D periodic halo orbit around L1:\n" + \
					"• Orbital Stability: %.1f%% (Corridor Error: %.2f%%)\n" % [halo_stability_pct, halo_capture_error_pct] + \
					"• Remaining Propellant: %.1f kg (Exceeds > 35 kg illustrative reserve threshold)\n" % propellant_kg + \
					"• Stationkeeping Assumption: Modeled as ~15–30 m/s/yr educational assumption, not a guaranteed lifetime."
			if detail_metric_lbl: detail_metric_lbl.text = "Remaining Fuel: %.1f kg • Reserve Δv: %.1f m/s" % [propellant_kg, available_delta_v_ms]
			if progress_bar: progress_bar.value = 99.4
			
			if advisory_lbl:
				advisory_lbl.text = "● HALO CAPTURE CONFIRMED: Stationkeeping reserve threshold satisfied."
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
				
		SubPhase.STAGE_D_COMMISSION_MAG:
			current_step = StageStep.BOOM_DEPLOY
			if lbl_phase: lbl_phase.text = "STAGE D: INSTRUMENT COMMISSIONING — MAGNETOMETER"
			if lbl_status: lbl_status.text = "MAGNETOMETER HEALTH: %.1f%% • BOOM STATUS: %s" % [mag_health_pct, "DEPLOYED" if mag_boom_deployed else "STOWED"]
			if lbl_primary: lbl_primary.text = "Extend 3.8m carbon-fiber boom, verify vibration stability, and calibrate IMF sensors."
			if lbl_action: lbl_action.text = "Structural & Systems: Click DEPLOY & CALIBRATE MAGNETOMETER BOOM"
			if lbl_next: lbl_next.text = "Next: Faraday Cup Solar-Wind Plasma Analyzer Commissioning."
			
			if action_btn:
				action_btn.visible = true
				action_btn.text = "🛰 DEPLOY 3.8m MAGNETOMETER BOOM & CALIBRATE →"
			if secondary_btn:
				secondary_btn.visible = true
				secondary_btn.text = "VIEW SENSOR CLOSE-UP [Key 4]"
				
			if detail_deck: detail_deck.visible = true
			if detail_title_lbl: detail_title_lbl.text = "TRIAXIAL FLUXGATE MAGNETOMETER COMMISSIONING"
			if detail_body_lbl:
				var inherited_note = "Nominal calibration" if mag_health_pct >= 95.0 else "Compensating for minor SEP sensor noise (%.1f%% health)" % mag_health_pct
				detail_body_lbl.text = "Commissioning high-precision magnetic field sensor away from spacecraft bus dipole:\n" + \
					"• Boom Length: 3.8 meters (Rigid carbon-fiber truss)\n" + \
					"• Damping Stability: Vibration settling time < 1.5s\n" + \
					"• Sensor Condition: %s\n" % inherited_note + \
					"• Background IMF Measurement: Bx=+4.2 nT, By=-3.8 nT, Bz=-5.4 nT (|B|=7.8 nT)."
			if detail_metric_lbl: detail_metric_lbl.text = "Sensor Power: 2.2W • Calibration Noise: < 0.05 nT"
			if progress_bar: progress_bar.value = 65.0
			
		SubPhase.STAGE_D_COMMISSION_FARADAY:
			current_step = StageStep.FARADAY_ACTIVATE
			if lbl_phase: lbl_phase.text = "STAGE D: INSTRUMENT COMMISSIONING — FARADAY CUP"
			if lbl_status: lbl_status.text = "FARADAY CUP HEALTH: %.1f%% • APERTURE: %s" % [faraday_health_pct, "ACTIVE" if faraday_cup_active else "RELEASE COVER"]
			if lbl_primary: lbl_primary.text = "Release aperture cover, execute high-voltage modulator sweep, and calibrate plasma stream."
			if lbl_action: lbl_action.text = "Systems Officer: Click ACTIVATE & CALIBRATE FARADAY CUP"
			if lbl_next: lbl_next.text = "Next: Spacecraft bus & power generation audit."
			
			if action_btn:
				action_btn.visible = true
				action_btn.text = "⚡ ACTIVATE FARADAY CUP PLASMA ANALYZER →"
			if secondary_btn:
				secondary_btn.visible = true
				secondary_btn.text = "VIEW FARADAY CLOSE-UP [Key 5]"
				
			if detail_deck: detail_deck.visible = true
			if detail_title_lbl: detail_title_lbl.text = "FARADAY CUP SOLAR-WIND PLASMA ANALYZER"
			if detail_body_lbl:
				var inherited_note = "Aperture & grids nominal" if faraday_health_pct >= 90.0 else "Calibrated with gain adjustment (%.1f%% health)" % faraday_health_pct
				detail_body_lbl.text = "Commissioning solar wind ion / electron spectrometer facing sunward:\n" + \
					"• Modulator Grid: High-voltage sweep 0V to +3,000V verified\n" + \
					"• Sensor Condition: %s\n" % inherited_note + \
					"• Ambient Solar Wind: Bulk speed %.0f km/s, Proton density %.1f p/cm³\n" % [solar_wind_bulk_velocity_kms, solar_wind_proton_density_cm3] + \
					"• Thermal Plasma Temp: 1.2e5 K (Simulated educational measurement)."
			if detail_metric_lbl: detail_metric_lbl.text = "HV Grid: +3000V • Collector Bias: -150V Nominal"
			if progress_bar: progress_bar.value = 85.0
			
		SubPhase.STAGE_D_SYSTEMS_VERIFY:
			current_step = StageStep.FARADAY_ACTIVATE
			if lbl_phase: lbl_phase.text = "STAGE D: SPACECRAFT BUS & ELECTRICAL VERIFICATION"
			if lbl_status: lbl_status.text = "POWER SURPLUS: +%.0f W • BATTERY RESERVE: %.0f Wh" % [net_power_surplus_w, battery_charge_wh]
			if lbl_primary: lbl_primary.text = "Verify solar array tracking, electrical power margins, thermal balance, and avionics."
			if lbl_action: lbl_action.text = "Systems & Structures: Click VERIFY ALL SUPPORT SYSTEMS"
			if lbl_next: lbl_next.text = "Next: Live Solar-Wind Observation & Early Warning Detection."
			
			if action_btn:
				action_btn.visible = true
				action_btn.text = "✓ VERIFY ALL SUPPORT SYSTEMS & START OBSERVATION →"
			if secondary_btn:
				secondary_btn.visible = false
				
			if detail_deck: detail_deck.visible = true
			if detail_title_lbl: detail_title_lbl.text = "SPACECRAFT SUPPORTING SYSTEMS AUDIT"
			if detail_body_lbl:
				detail_body_lbl.text = "• Solar Power: Dual wings tracking Sun, producing %.0f W at 1 AU\n" % solar_power_w + \
					"• Battery Reserve: %.0f Wh / %.0f Wh (%.1f%% charge)\n" % [battery_charge_wh, battery_capacity_wh, (battery_charge_wh / battery_capacity_wh) * 100.0] + \
					"• Thermal Control: Internal bus temperatures within -15°C to +28°C\n" + \
					"• Attitude & ADCS: Star trackers locked, drift < 0.01°/hr\n" + \
					"• All systems operational for mission observation."
			if detail_metric_lbl: detail_metric_lbl.text = "Generation: 245W • Load: 165W • Surplus: +80W"
			if progress_bar: progress_bar.value = 100.0
			
		SubPhase.STAGE_E_SCIENTIFIC_OBSERVATION:
			current_step = StageStep.EARTH_LINK
			observation_active = true
			if lbl_phase: lbl_phase.text = "STAGE E: LIVE SOLAR-WIND OBSERVATION SESSION"
			if lbl_status: lbl_status.text = "STREAMING SCIENCE: MAGNETOMETER & FARADAY CUP ONLINE"
			if lbl_primary: lbl_primary.text = "Monitor live solar wind plasma stream and characterize incoming space weather events."
			if lbl_action: lbl_action.text = "All Officers: Detect CME Shock Front and COMPILE EARLY-WARNING DATA PACKET"
			if lbl_next: lbl_next.text = "Next: Earth Communication Lock & Telemetry Transmission."
			
			if action_btn:
				action_btn.visible = true
				action_btn.text = "⚡ DETECT CME SHOCK & COMPILE EARLY-WARNING PACKET →"
			if secondary_btn:
				secondary_btn.visible = true
				secondary_btn.text = "WIDE SUN-EARTH VIEW [Key 2]"
				
			if detail_deck: detail_deck.visible = true
			if detail_title_lbl: detail_title_lbl.text = "INTERACTIVE SOLAR-WIND OBSERVATION SESSION"
			if detail_body_lbl:
				detail_body_lbl.text = "HELIOS-4 instruments are capturing live interplanetary plasma streams:\n" + \
					"• Interplanetary Magnetic Field: Bx=%.1f nT, By=%.1f nT, Bz=%.1f nT\n" % [mag_imf_reading.x, mag_imf_reading.y, mag_imf_reading.z] + \
					"• Solar Wind Speed: %.0f km/s • Proton Density: %.1f p/cm³\n" % [solar_wind_bulk_velocity_kms, solar_wind_proton_density_cm3] + \
					"• Dynamic Pressure: %.2f nPa • Data Quality Index: 100%%\n" % _calculate_dynamic_pressure_npa() + \
					"• Scientific Model: Simulated educational measurements validating DSCOVR architecture."
			if detail_metric_lbl: detail_metric_lbl.text = "v_sw: %.0f km/s • n_p: %.1f p/cm³ • Bz: %.1f nT" % [solar_wind_bulk_velocity_kms, solar_wind_proton_density_cm3, mag_imf_reading.z]
			if progress_bar: progress_bar.value = 60.0
			
			if advisory_lbl:
				advisory_lbl.text = "★ SCIENCE ACTIVE: Capturing pristine solar wind stream at Sun-Earth L1."
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
				
		SubPhase.STAGE_F_EARTH_COMM_LOCK:
			current_step = StageStep.EARTH_LINK
			if lbl_phase: lbl_phase.text = "STAGE F: DEEP SPACE NETWORK EARTH COMMUNICATION LOCK"
			if lbl_status: lbl_status.text = "HIGH-GAIN DISH: SLEWING TOWARD EARTH • DSN FREQUENCY: 8.4 GHz"
			if lbl_primary: lbl_primary.text = "Point high-gain Cassegrain parabolic antenna toward Earth and establish carrier lock."
			if lbl_action: lbl_action.text = "Systems Officer: Click LOCK HIGH-GAIN DISH ON EARTH DSN"
			if lbl_next: lbl_next.text = "Next: Transmit Early-Warning Telemetry Packet to Earth."
			
			if action_btn:
				action_btn.visible = true
				action_btn.text = "📡 LOCK HIGH-GAIN DISH ON EARTH DSN →"
			if secondary_btn:
				secondary_btn.visible = true
				secondary_btn.text = "VIEW EARTH DISH BORESIGHT [Key 6]"
				
			if detail_deck: detail_deck.visible = true
			if detail_title_lbl: detail_title_lbl.text = "EARTH DEEP SPACE NETWORK (DSN) CARRIER LOCK"
			if detail_body_lbl:
				detail_body_lbl.text = "Gimbaling steerable parabolic dish antenna toward Earth (1.5M km distance):\n" + \
					"• Earth Azimuth/Elevation: Slew angle 0.0° (Locked on Earth center)\n" + \
					"• DSN Ground Complexes: Goldstone, Madrid, Canberra\n" + \
					"• RF Frequency: 8.4 GHz (Ka-Band) • Link Margin: +%.1f dB\n" % dsn_signal_db + \
					"• Early-Warning Packet: Verified & ready for transmission."
			if detail_metric_lbl: detail_metric_lbl.text = "RF Link Margin: +4.2 dB • Transmitter Power: 45W"
			if progress_bar: progress_bar.value = 90.0
			
			if advisory_lbl:
				advisory_lbl.text = "★ READY FOR TRANSMISSION: Communication line of sight to Earth verified."
				advisory_lbl.add_theme_color_override("font_color", Color(0.2, 0.75, 1.0))
				
		SubPhase.STAGE_F_TRANSMIT_WARNING:
			current_step = StageStep.TRANSMIT_WARNING
			if lbl_phase: lbl_phase.text = "STAGE F: TRANSMIT EARLY-WARNING TELEMETRY PACKET"
			if lbl_status: lbl_status.text = "AUTHORIZE TRANSMISSION: LEAD TIME ADVANCE %.2f MINUTES" % lead_time_minutes
			if lbl_primary: lbl_primary.text = "Authorize and beam the CME early-warning data packet across 1.5M km to Earth."
			if lbl_action: lbl_action.text = "Mission Lead / Systems: Click TRANSMIT EARLY-WARNING TELEMETRY PACKET"
			if lbl_next: lbl_next.text = "Next: Earth ground station acknowledgement & mission completion."
			
			if action_btn:
				action_btn.visible = true
				action_btn.text = "★ TRANSMIT EARLY-WARNING TELEMETRY PACKET →"
			if secondary_btn:
				secondary_btn.visible = false
				
			if detail_deck: detail_deck.visible = true
			if detail_title_lbl: detail_title_lbl.text = "EARLY-WARNING DATA PACKET AR-4890 TRANSMISSION"
			if detail_body_lbl:
				detail_body_lbl.text = "Following instrument commissioning, an extreme Coronal Mass Ejection from Active Region AR-4890 has been observed:\n" + \
					"• Measured CME Shock Velocity: %.0f km/s (Severe shock)\n" % shock_velocity_km_s + \
					"• L1-to-Earth Distance: %.1f Million km (1,500,000 km)\n" % (L1_DISTANCE_KM / 1000000.0) + \
					"• Interplanetary Magnetic Field Bz: %.1f nT (Extreme southward reconnection)\n" % mag_imf_reading.z + \
					"• Proton Density: %.1f p/cm³\n" % solar_wind_proton_density_cm3 + \
					"• Calculated Warning Lead Time: %.2f Minutes (t = d / v / 60)\n" % lead_time_minutes + \
					"• Scientific Reality: HELIOS-4 does NOT deflect solar storms; its mission is early observation and warning."
			if detail_metric_lbl: detail_metric_lbl.text = "Advance Notice: %.2f min • Packet Size: 1.2 MB • Checksum: OK" % lead_time_minutes
			if progress_bar: progress_bar.value = 0.0
			
		SubPhase.MISSION_SUCCESS_DEBRIEF:
			current_step = StageStep.COMMISSIONING_SUCCESS
			_handle_mission_commissioned_success()

# --- ACTION HANDLERS ---

func _on_primary_action_pressed() -> void:
	match current_phase:
		SubPhase.STAGE_A_APPROACH_NAVIGATION:
			# Execute approach trim burn
			propellant_kg = max(5.0, propellant_kg - 2.4)
			distance_to_l1_km = 450.0
			relative_velocity_kms = 1.05
			trajectory_accuracy_pct = 99.8
			_fire_rcs_burst(0.6)
			print("[L1Arrival] 🧭 Approach trim burn executed (-2.4 kg). Trajectory accuracy locked to 99.8%.")
			_load_subphase(SubPhase.STAGE_B_HOI_PLANNING)
			
		SubPhase.STAGE_B_HOI_PLANNING:
			# Execute HOI burn
			_load_subphase(SubPhase.STAGE_B_HOI_EXECUTION)
			
		SubPhase.STAGE_B_HOI_EXECUTION:
			pass # Burn is running
			
		SubPhase.STAGE_C_STATIONKEEPING:
			# Execute stationkeeping trim burn
			propellant_kg = max(5.0, propellant_kg - 8.5)
			halo_stability_pct = 99.6
			halo_capture_error_pct = 0.22
			_fire_rcs_burst(0.8)
			print("[L1Arrival] ⚡ Stationkeeping burn executed (-8.5 kg). Halo stability locked to 99.6%.")
			_load_subphase(SubPhase.STAGE_D_COMMISSION_MAG)
			
		SubPhase.STAGE_D_COMMISSION_MAG:
			# Commission Magnetometer
			mag_boom_deployed = true
			mag_stability_verified = true
			mag_power_verified = true
			mag_calibrated = true
			_animate_mag_boom_deployment()
			print("[L1Arrival] 🛰 Magnetometer boom deployed and calibrated. IMF B-field reading active.")
			_load_subphase(SubPhase.STAGE_D_COMMISSION_FARADAY)
			
		SubPhase.STAGE_D_COMMISSION_FARADAY:
			# Commission Faraday Cup
			faraday_door_released = true
			faraday_hv_sweep_verified = true
			faraday_calibrated = true
			faraday_cup_active = true
			_animate_faraday_cover_release()
			print("[L1Arrival] ⚡ Faraday Cup activated. Live solar wind plasma measurements streaming.")
			_load_subphase(SubPhase.STAGE_D_SYSTEMS_VERIFY)
			
		SubPhase.STAGE_D_SYSTEMS_VERIFY:
			# Complete systems verification
			print("[L1Arrival] ✓ Spacecraft support systems verified nominal.")
			_load_subphase(SubPhase.STAGE_E_SCIENTIFIC_OBSERVATION)
			
		SubPhase.STAGE_E_SCIENTIFIC_OBSERVATION:
			# Detect CME shock and compile data packet
			cme_shock_detected = true
			solar_wind_bulk_velocity_kms = 2420.0
			solar_wind_proton_density_cm3 = 46.2
			mag_imf_reading.z = -31.5 # Severe southward reconnection
			early_warning_data_compiled = true
			print("[L1Arrival] ★ CME SHOCK DETECTED! Speed: 2420 km/s, Bz: -31.5 nT. Early warning packet compiled.")
			_load_subphase(SubPhase.STAGE_F_EARTH_COMM_LOCK)
			
		SubPhase.STAGE_F_EARTH_COMM_LOCK:
			# Lock DSN communication
			earth_comm_linked = true
			antenna_slew_angle_deg = 0.0
			_animate_dish_earth_lock()
			print("[L1Arrival] 📡 Earth DSN carrier locked (8.4 GHz, +4.2 dB). Ready for transmission.")
			_load_subphase(SubPhase.STAGE_F_TRANSMIT_WARNING)
			
		SubPhase.STAGE_F_TRANSMIT_WARNING:
			# Authorize and start transmission
			transmission_authorized = true
			print("[L1Arrival] ★ Early warning transmission authorized! Beaming to Earth...")

func _on_secondary_action_pressed() -> void:
	match current_phase:
		SubPhase.STAGE_A_APPROACH_NAVIGATION:
			trajectory_accuracy_pct = min(99.9, trajectory_accuracy_pct + 0.3)
			if advisory_lbl: advisory_lbl.text = "Trajectory fine-tuned: Accuracy %.1f%%" % trajectory_accuracy_pct
		SubPhase.STAGE_B_HOI_PLANNING:
			# Cycle burn magnitude: 260 -> 280 -> 300 -> 260
			if hoi_planned_delta_v_ms == 280.0:
				hoi_planned_delta_v_ms = 300.0
			elif hoi_planned_delta_v_ms == 300.0:
				hoi_planned_delta_v_ms = 260.0
			else:
				hoi_planned_delta_v_ms = 280.0
			if secondary_btn: secondary_btn.text = "TUNE BURN MAGNITUDE (%.0f m/s)" % hoi_planned_delta_v_ms
			if detail_metric_lbl: detail_metric_lbl.text = "Planned Δv: %.1f m/s • Target Capture Error: < 0.5%%" % hoi_planned_delta_v_ms
		SubPhase.STAGE_D_COMMISSION_MAG:
			_set_camera_mode(CameraMode.MAG_BOOM)
		SubPhase.STAGE_D_COMMISSION_FARADAY:
			_set_camera_mode(CameraMode.FARADAY_CUP)
		SubPhase.STAGE_E_SCIENTIFIC_OBSERVATION:
			_set_camera_mode(CameraMode.WIDE)
		SubPhase.STAGE_F_EARTH_COMM_LOCK:
			_set_camera_mode(CameraMode.EARTH_DISH)

func _start_hoi_burn_execution() -> void:
	is_engine_firing = true
	hoi_burn_timer_s = 0.0
	if engine_exhaust: engine_exhaust.emitting = true
	
	if lbl_phase: lbl_phase.text = "STAGE B: EXECUTING HOI INSERTION BURN"
	if lbl_status: lbl_status.text = "MAIN ENGINE FIRING (Δv: %.0f m/s)" % hoi_planned_delta_v_ms
	if action_btn: action_btn.visible = false
	if secondary_btn: secondary_btn.visible = false
	if advisory_lbl:
		advisory_lbl.text = "🚀 MAIN ENGINE ACTIVE: Burning hydrazine propellant to capture into halo orbit..."
		advisory_lbl.add_theme_color_override("font_color", Color(0.98, 0.55, 0.15))

func _process_hoi_burn(delta: float) -> void:
	hoi_burn_timer_s += delta
	var progress = clamp(hoi_burn_timer_s / hoi_burn_duration_s, 0.0, 1.0)
	
	# Consume fuel proportionally to burn progress
	var burn_fuel_total = 35.0
	var fuel_chunk = (burn_fuel_total / hoi_burn_duration_s) * delta
	propellant_kg = max(5.0, propellant_kg - fuel_chunk)
	relative_velocity_kms = lerp(1.05, 0.28, progress)
	distance_to_l1_km = lerp(450.0, 0.0, progress)
	
	if progress_bar: progress_bar.value = progress * 100.0
	if detail_metric_lbl: detail_metric_lbl.text = "Burn Progress: %.0f%% • Propellant: %.1f kg • Rel Vel: %.2f km/s" % [progress * 100.0, propellant_kg, relative_velocity_kms]
	
	if hoi_burn_timer_s >= hoi_burn_duration_s:
		is_engine_firing = false
		if engine_exhaust: engine_exhaust.emitting = false
		halo_stability_pct = 99.4
		halo_capture_error_pct = 0.35
		print("[L1Arrival] 🚀 HOI BURN COMPLETE: Spacecraft captured into Sun-Earth L1 Halo Orbit!")
		_load_subphase(SubPhase.STAGE_C_STATIONKEEPING)

func _process_scientific_observation(delta: float) -> void:
	observation_time_s += delta
	# Fluctuate ambient solar wind slightly for realism
	solar_wind_bulk_velocity_kms = 440.0 + sin(observation_time_s * 2.0) * 12.0
	solar_wind_proton_density_cm3 = 8.5 + cos(observation_time_s * 1.5) * 0.8
	mag_imf_reading.x = 4.2 + sin(observation_time_s) * 0.4
	mag_imf_reading.y = -3.8 + cos(observation_time_s * 0.8) * 0.3
	mag_imf_reading.z = -5.4 + sin(observation_time_s * 1.2) * 0.5

func _process_transmission(delta: float) -> void:
	transmission_progress_pct += delta * 35.0 # ~3 seconds transmission
	if progress_bar: progress_bar.value = transmission_progress_pct
	if detail_metric_lbl: detail_metric_lbl.text = "Transmitting Packet: %.0f%% • Battery Drain: -45W" % transmission_progress_pct
	
	# Battery consumption during RF downlink
	battery_charge_wh = max(100.0, battery_charge_wh - delta * 0.8)
	
	if transmission_progress_pct >= 100.0:
		transmission_authorized = false
		earth_ack_received = true
		warning_packet_sent = true
		_load_subphase(SubPhase.MISSION_SUCCESS_DEBRIEF)

func _handle_mission_commissioned_success() -> void:
	if lbl_phase: lbl_phase.text = "HELIOS-4 SUCCESSFULLY COMMISSIONED AT SUN-EARTH L1"
	if lbl_status: lbl_status.text = "★ ALL OBJECTIVES ACCOMPLISHED: OPERATIONAL SOLAR SENTINEL"
	if lbl_primary: lbl_primary.text = "Early-warning packet acknowledged by Earth DSN! Proceed to full mission debrief."
	if lbl_action: lbl_action.text = "Mission Lead: Click PROCEED TO FINAL MISSION DEBRIEF →"
	if lbl_next: lbl_next.text = "Next: Final Mission Debrief & Scientific Evaluation Scorecard."
	
	if action_btn: action_btn.visible = false
	if secondary_btn: secondary_btn.visible = false
	if proceed_debrief_btn:
		proceed_debrief_btn.visible = true
		proceed_debrief_btn.text = "COMMISSIONING COMPLETE: PROCEED TO DEBRIEF →"
		
	if detail_deck: detail_deck.visible = true
	if detail_title_lbl: detail_title_lbl.text = "★ MISSION SUCCESS: EARTH ACKNOWLEDGEMENT RECEIVED"
	if detail_body_lbl:
		detail_body_lbl.text = "Deep Space Network complexes at Goldstone and Madrid have verified early-warning telemetry:\n" + \
			"• Coronal Mass Ejection Shock Velocity: %.0f km/s\n" % shock_velocity_km_s + \
			"• Advance Warning Lead Time Delivered: %.2f Minutes (t = d / v / 60)\n" % lead_time_minutes + \
			"• Stationkeeping Propellant Remaining: %.1f kg (Reserve threshold satisfied)\n" % propellant_kg + \
			"• Scientific Instruments: Magnetometer (100%%) & Faraday Cup (100%%) Online\n" + \
			"• Earth power grids, satellite operators, and aviation networks notified."
	if detail_metric_lbl: detail_metric_lbl.text = "Scorecard Evaluation: A+ (100 / 100 PTS Ready)"
	if progress_bar: progress_bar.value = 100.0
	
	if advisory_lbl:
		advisory_lbl.text = "★ EARLY-WARNING DELIVERED: %.2f MINUTES ADVANCE NOTICE TO EARTH!" % lead_time_minutes
		advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	if warning_time_lbl:
		warning_time_lbl.text = "Advance Lead Time Delivered: %.2f min (d: 1.5M km | v: %.0f km/s)" % [lead_time_minutes, shock_velocity_km_s]
		
	print("[L1Arrival] ★ HELIOS-4 SUCCESSFULLY COMMISSIONED! Advance Lead Time: %.2f minutes." % lead_time_minutes)

func _on_proceed_to_debrief_pressed() -> void:
	# Persist full L1 telemetry
	Helios4CampaignData.l1_telemetry = {
		"halo_orbit_achieved": true,
		"halo_stability_pct": halo_stability_pct,
		"final_propellant_kg": propellant_kg,
		"mag_boom_deployed": mag_boom_deployed,
		"faraday_cup_active": faraday_cup_active,
		"earth_comm_linked": earth_comm_linked,
		"warning_packet_sent": warning_packet_sent,
		"l1_distance_km": L1_DISTANCE_KM,
		"solar_wind_speed_kms": shock_velocity_km_s,
		"lead_time_minutes": lead_time_minutes,
		"imf_bz_nt": -31.5,
		"data_product_verified": true
	}
	Helios4CampaignData.save_campaign_state()
	print("[L1Arrival] Advancing to Stage 6: Mission Debrief...")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.MISSION_DEBRIEF, get_tree())

func _fire_rcs_burst(duration_s: float) -> void:
	if rcs_particles:
		rcs_particles.emitting = true
		get_tree().create_timer(duration_s).timeout.connect(func():
			if rcs_particles: rcs_particles.emitting = false
		)

func _calculate_dynamic_pressure_npa() -> float:
	# P_dyn = n_p * m_p * v^2 where m_p = 1.6726e-27 kg
	var n_p_m3 = solar_wind_proton_density_cm3 * 1.0e6
	var v_m_s = solar_wind_bulk_velocity_kms * 1000.0
	var m_p = 1.6726e-27
	var p_pa = n_p_m3 * m_p * (v_m_s * v_m_s)
	return p_pa * 1.0e9 # in nanoPascals (nPa)

func _update_telemetry_ui() -> void:
	if val_met:
		var days = int(mission_elapsed_time_s / 86400.0)
		var hours = int(fmod(mission_elapsed_time_s, 86400.0) / 3600.0)
		var mins = int(fmod(mission_elapsed_time_s, 3600.0) / 60.0)
		var secs = int(fmod(mission_elapsed_time_s, 60.0))
		val_met.text = "T+%03dd %02d:%02d:%02d" % [days, hours, mins, secs]
		
	if val_earth_dist: val_earth_dist.text = "%.0f km" % distance_to_earth_km
	if val_l1_dist: val_l1_dist.text = "%.0f km" % distance_to_l1_km
	if val_rel_vel: val_rel_vel.text = "%.2f km/s" % relative_velocity_kms
	if val_fuel: val_fuel.text = "%.1f kg" % propellant_kg
	if val_delta_v: val_delta_v.text = "%.1f m/s" % available_delta_v_ms
	if val_power: val_power.text = "+%.0f W" % net_power_surplus_w
	if val_battery: val_battery.text = "%.0f Wh" % battery_charge_wh
	if val_dsn: val_dsn.text = "+%.1f dB" % dsn_signal_db
	
	if fuel_reserve_lbl: fuel_reserve_lbl.text = "Propellant: %.1f kg" % propellant_kg
	if warning_time_lbl and current_phase < SubPhase.MISSION_SUCCESS_DEBRIEF:
		warning_time_lbl.text = "Early Warning: %.2f min (d: 1.5M km | v: %.0f km/s)" % [lead_time_minutes, shock_velocity_km_s]
	if telemetry_data_lbl:
		telemetry_data_lbl.text = "DSN: %.1f GHz • Mag: %s • Faraday: %s • Officer: %s" % [
			dsn_frequency_ghz,
			"Active (IMF Online)" if mag_boom_deployed else "Standby",
			"Active (Streaming)" if faraday_cup_active else "Standby",
			Helios4CampaignData.active_role.to_upper()
		]
