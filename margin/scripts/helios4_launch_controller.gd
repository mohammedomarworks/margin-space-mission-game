class_name Helios4LaunchController
extends Node3D

# ==============================================================================
# MARGIN — HELIOS-4: PHASE 2 — EARTH LAUNCH AND MAX-Q
# High-Fidelity 3D Rocket Ascent Simulation matching Reference: 02_helios4_launch_maxq.png
#
# Key Features:
# 1. 3D Spaceport Launch Complex:
#    - Concrete launch mount, flame deflector trench, cryogenic LOX/LH2 dewars
#    - Red/white Launch Umbilical Tower (LUT) with service swing arms and safety lights
#    - 4 mechanical hold-down clamp assemblies that release at liftoff
#    - 4 perimeter lightning towers with wire catenaries
#    - Coastal spaceport terrain (tarmac, shoreline, deep Atlantic ocean)
#
# 2. 3D Curved Earth & Realistic Atmospheric Environment:
#    - Giant 3D curved Earth horizon sphere (R = 500m) below the ascent trajectory
#    - Specular blue ocean, continent landmasses, swirling cloud deck, and Rayleigh scattering atmospheric limb glow
#    - Day atmosphere fading into deep space starfield as altitude increases
#
# 3. 7 Cinematic Camera States:
#    - 1. PAD, 2. ENGINE, 3. CHASE, 4. WIDE, 5. MAX-Q (exact matching ref 02), 6. SEPARATION, 7. ORBITAL
#
# 4. Authentic Reference 02 Flight HUD:
#    - Vector NavBall (artificial horizon sphere with sky/ground, pitch ladder, reticle)
#    - Dynamic Max-Q Warning Arc Gauge near rocket nose with warning triangle & Q magnifier
#    - Moving vertical Altitude Tape with kilometer scale & numeric pointer
#    - Vertical Throttle Gauge with striped progress bar & up/down buttons
#    - Staging Column Diagram with 3 stages and active booster highlight
#    - Radar Scope in upper right
#    - 4 Officer pill badges at top center (Wrench, Radar, Planetary, Electrical)
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const Helios4Rocket3D = preload("res://margin/scripts/helios4_rocket_3d.gd")
const Helios4HUDWidgets = preload("res://margin/scripts/helios4_hud_widgets.gd")
const SpacecraftMaterials = preload("res://margin/materials/spacecraft_materials.gd")

enum FlightPhase {
	READINESS_HOLD,
	PRE_LAUNCH_PREPARATION,
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

enum CameraMode {
	PAD,
	ENGINE,
	CHASE,
	WIDE,
	MAX_Q,
	SEPARATION,
	ORBITAL
}

var current_phase: FlightPhase = FlightPhase.PRE_LAUNCH_PREPARATION
var current_cam_mode: CameraMode = CameraMode.PAD

# 3D Node References
@onready var rocket: Node3D = %RocketNode
@onready var rocket_visual: Helios4Rocket3D = %RocketVisual
@onready var vapor_cone_node: Node3D = %VaporConeNode
@onready var main_plumes_node: Node3D = %MainEnginePlumes
@onready var vacuum_plume_node: Node3D = %VacuumPlume
@onready var detached_booster: Node3D = %DetachedBoosterNode
@onready var jettisoned_fairing_l: Node3D = %JettisonedFairingLeft
@onready var jettisoned_fairing_r: Node3D = %JettisonedFairingRight
@onready var launch_cam: Camera3D = %LaunchCamera
@onready var earth_curvature: Node3D = %EarthCurvatureNode
@onready var launch_complex: Node3D = %LaunchComplexNode
@onready var sun_light: DirectionalLight3D = $SunLight

# Mechanical Clamps & Umbilical Arms
var hold_down_clamps: Array[Node3D] = []
var umbilical_arms: Array[Node3D] = []
var pad_steam_emitter: CPUParticles3D = null
var plume_smoke_emitter: CPUParticles3D = null

# Pre-Launch Checklist State & Modals
var prelaunch_checks: Dictionary = {
	"ground_systems": false,
	"propellant": false,
	"avionics": false,
	"comms": false,
	"engines": false,
	"guidance": false
}
var countdown_paused: bool = false
var flight_path_angle_deg: float = 90.0
var max_q_achieved_kpa: float = 0.0
var max_g_load_achieved: float = 1.0
var abort_reason_text: String = ""

# Pre-launch UI references
var prelaunch_panel: PanelContainer = null
var abort_modal_panel: PanelContainer = null
var hold_modal_panel: PanelContainer = null
var flight_legend_lbl: Label = null

# Flight Physics State (Educational Simulation Model)
var altitude_m: float = 0.0
var velocity_ms: float = 0.0
var throttle: float = 1.0 # 0.0 to 1.0
var pitch_deg: float = 90.0 # 90 = vertical, 0 = horizontal
var flight_time_s: float = 0.0
var countdown_s: float = 10.0
var downrange_m: float = 0.0

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
var time_warp: float = 1.0

# Camera Smooth Interpolation
var _cam_target_pos: Vector3 = Vector3(-3.2, 7.5, 16.5)
var _cam_target_rot: Vector3 = Vector3(-12.0, -14.0, 0.0)
var _cam_lerp_speed: float = 3.5

# Custom Procedural HUD Widgets
var navball_widget: Helios4HUDWidgets.NavBall = null
var max_q_arc_widget: Helios4HUDWidgets.MaxQArcWidget = null
var altitude_tape_widget: Helios4HUDWidgets.AltitudeTape = null
var throttle_widget: Helios4HUDWidgets.VerticalThrottleGauge = null
var staging_widget: Helios4HUDWidgets.StagingColumn = null
var radar_widget: Helios4HUDWidgets.RadarScope = null
var attitude_widget: Helios4HUDWidgets.AttitudeScope = null

# Constants
const G0: float = 9.80665
const RHO_0: float = 1.225 # kg/m^3 sea-level air density
const SCALE_HEIGHT_M: float = 7500.0 # Earth atmospheric scale height
const TARGET_ORBIT_ALT_M: float = 185000.0 # 185 km parking orbit
const TARGET_ORBIT_VEL_MS: float = 7780.0

func _ready() -> void:
	_init_flight_parameters()
	_build_launch_environment()
	_setup_procedural_hud_widgets()
	_connect_controls()
	_update_ui()
	_set_camera_mode(CameraMode.PAD, true)

	var max_q_holder = find_child("MaxQArcHolder", true, false) as Control
	if max_q_holder:
		max_q_holder.visible = false

	# Setup interactive prelaunch checklist and flight controls legend
	_build_flight_controls_legend()
	if not Helios4CampaignData.is_spacecraft_ready_for_flight():
		current_phase = FlightPhase.READINESS_HOLD
		_show_readiness_hold_modal()
	else:
		current_phase = FlightPhase.PRE_LAUNCH_PREPARATION
		_build_prelaunch_checklist_ui()

	# Print UI coordinates for automated QA and browser testing
	get_tree().process_frame.connect(func():
		var btns = [
			"ProceedToTransferBtn", "BtnStageSeparation", "BtnSystemsActivate",
			"CamBtn_Pad", "CamBtn_Engine", "CamBtn_Chase", "CamBtn_Wide",
			"CamBtn_MaxQ", "CamBtn_Sep", "CamBtn_Orbit",
			"BtnStartCountdown", "BtnAutoVerifyPreflight", "BtnAbortLaunchPrep"
		]
		for b_name in btns:
			var b = find_child(b_name, true, false)
			if b:
				print("[Launch] %s center: " % b_name, b.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _init_flight_parameters() -> void:
	var v_cfg = Helios4CampaignData.vehicle_config
	if v_cfg.is_empty():
		v_cfg = Helios4CampaignData.get_default_vehicle_config()
		Helios4CampaignData.vehicle_config = v_cfg
	if Helios4CampaignData.probe_config.is_empty():
		Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()

	var tel = Helios4CampaignData.calculate_hangar_telemetry()
	s1_fuel_capacity_kg = tel["stage1_fuel_mass_kg"]
	s1_fuel_kg = s1_fuel_capacity_kg
	s2_fuel_capacity_kg = tel["stage2_fuel_mass_kg"]
	s2_fuel_kg = s2_fuel_capacity_kg
	current_mass_kg = tel["liftoff_wet_mass_kg"]

	altitude_m = 0.0
	velocity_ms = 0.0
	throttle = 1.0
	pitch_deg = 90.0
	flight_path_angle_deg = 90.0
	flight_time_s = 0.0
	countdown_s = 10.0
	downrange_m = 0.0
	dynamic_pressure_kpa = 0.0
	g_load = 1.0
	structural_stress_pct = 0.0
	trajectory_error_pct = 0.0
	fairing_separated = false
	stage1_separated = false
	orbit_achieved = false
	systems_activated = false
	time_warp = 1.0
	countdown_paused = false
	max_q_achieved_kpa = 0.0
	max_g_load_achieved = 1.0
	abort_reason_text = ""

	for k in prelaunch_checks:
		prelaunch_checks[k] = false

	if rocket:
		rocket.position = Vector3(0.0, 4.0, 0.0)
		rocket.rotation_degrees = Vector3.ZERO
		if rocket_visual and rocket_visual.stage1_node:
			rocket_visual.stage1_node.visible = true
		if rocket_visual and rocket_visual.fairing_left:
			rocket_visual.fairing_left.visible = true
		if rocket_visual and rocket_visual.fairing_right:
			rocket_visual.fairing_right.visible = true
	if detached_booster:
		detached_booster.visible = false
	if jettisoned_fairing_l:
		jettisoned_fairing_l.visible = false
	if jettisoned_fairing_r:
		jettisoned_fairing_r.visible = false
	if main_plumes_node:
		main_plumes_node.visible = false
	if vacuum_plume_node:
		vacuum_plume_node.visible = false

# ==============================================================================
# 1. 3D LAUNCH ENVIRONMENT & EARTH CURVATURE CONSTRUCTION
# ==============================================================================

func _build_launch_environment() -> void:
	if launch_complex:
		_build_launch_pad_facility(launch_complex)
	if earth_curvature:
		_build_curved_earth_mesh(earth_curvature)
	if vapor_cone_node:
		_build_transonic_vapor_cone(vapor_cone_node)
	if main_plumes_node:
		_build_engine_exhaust_fx(main_plumes_node)
	if vacuum_plume_node:
		_build_vacuum_exhaust_fx(vacuum_plume_node)
	if detached_booster:
		_build_detached_booster_mesh(detached_booster)
	if jettisoned_fairing_l and jettisoned_fairing_r:
		_build_jettisoned_fairings(jettisoned_fairing_l, jettisoned_fairing_r)

func _build_launch_pad_facility(parent: Node3D) -> void:
	var mat_pad := SpacecraftMaterials.get_mat("launch_pad_concrete")
	var mat_trench := SpacecraftMaterials.get_mat("launch_flame_trench")
	var mat_clamp := SpacecraftMaterials.get_mat("launch_clamp_steel")
	var mat_twr_red := SpacecraftMaterials.get_mat("launch_tower_red")
	var mat_twr_white := SpacecraftMaterials.get_mat("launch_tower_white")
	var mat_steel := SpacecraftMaterials.get_mat("hangar_truss_steel")
	var mat_yellow := SpacecraftMaterials.get_mat("industrial_crane_safety")
	var mat_terrain := SpacecraftMaterials.get_mat("spaceport_terrain")
	var mat_tarmac := SpacecraftMaterials.get_mat("spaceport_tarmac")
	var mat_ocean := SpacecraftMaterials.get_mat("spaceport_ocean")

	# --- A. Spaceport Coastal Terrain (600m x 600m) ---
	var terrain := MeshInstance3D.new()
	var t_box := BoxMesh.new()
	t_box.size = Vector3(600.0, 1.0, 600.0)
	terrain.mesh = t_box
	terrain.position = Vector3(0.0, -0.5, 0.0)
	terrain.material_override = mat_terrain
	parent.add_child(terrain)

	# Spaceport Tarmac Perimeter
	var tarmac := MeshInstance3D.new()
	var tm_box := BoxMesh.new()
	tm_box.size = Vector3(120.0, 0.2, 120.0)
	tarmac.mesh = tm_box
	tarmac.position = Vector3(0.0, 0.1, 0.0)
	tarmac.material_override = mat_tarmac
	parent.add_child(tarmac)

	# Coastal Atlantic Ocean Water (East side)
	var water := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(300.0, 0.8, 600.0)
	water.mesh = w_box
	water.position = Vector3(250.0, -0.3, 0.0)
	water.material_override = mat_ocean
	parent.add_child(water)

	# --- B. Concrete Launch Mount & Flame Trench ---
	var mount := MeshInstance3D.new()
	var m_box := BoxMesh.new()
	m_box.size = Vector3(36.0, 4.0, 36.0)
	mount.mesh = m_box
	mount.position = Vector3(0.0, 2.0, 0.0)
	mount.material_override = mat_pad
	parent.add_child(mount)

	# Flame Deflector Trench through center
	var trench := MeshInstance3D.new()
	var tr_box := BoxMesh.new()
	tr_box.size = Vector3(12.0, 4.2, 38.0)
	trench.mesh = tr_box
	trench.position = Vector3(0.0, 2.0, 0.0)
	trench.material_override = mat_trench
	parent.add_child(trench)

	# --- C. Launch Umbilical Tower (LUT) ---
	# Tall red-and-white lattice umbilical service tower at x = -10m
	var tower_x = -10.5
	var tower_height = 42.0

	for level in range(7):
		var ly = 4.0 + level * 5.5
		var is_red = (level % 2 == 0)
		var lvl_mat = mat_twr_red if is_red else mat_twr_white

		# 4 Main Vertical Posts
		for ox in [-2.0, 2.0]:
			for oz in [-2.0, 2.0]:
				var post := MeshInstance3D.new()
				var p_box := BoxMesh.new()
				p_box.size = Vector3(0.4, 5.5, 0.4)
				post.mesh = p_box
				post.position = Vector3(tower_x + ox, ly + 2.75, oz)
				post.material_override = lvl_mat
				parent.add_child(post)

		# Horizontal Framing Deck
		var deck := MeshInstance3D.new()
		var d_box := BoxMesh.new()
		d_box.size = Vector3(4.4, 0.3, 4.4)
		deck.mesh = d_box
		deck.position = Vector3(tower_x, ly, 0.0)
		deck.material_override = mat_steel
		parent.add_child(deck)

		# Diagonal X-Braces on tower faces
		var x_brace := MeshInstance3D.new()
		var xb_box := BoxMesh.new()
		xb_box.size = Vector3(0.12, 0.12, 5.8)
		x_brace.mesh = xb_box
		x_brace.position = Vector3(tower_x + 2.0, ly + 2.75, 0.0)
		x_brace.rotation_degrees = Vector3(45.0, 0.0, 0.0)
		x_brace.material_override = lvl_mat
		parent.add_child(x_brace)

	# Red FAA Strobe Warning Beacon on Top of Umbilical Tower
	var beacon := MeshInstance3D.new()
	var b_sph := SphereMesh.new()
	b_sph.radius = 0.35
	b_sph.height = 0.7
	beacon.mesh = b_sph
	beacon.position = Vector3(tower_x, tower_height + 4.5, 0.0)
	var mat_beacon := StandardMaterial3D.new()
	mat_beacon.albedo_color = Color(1.0, 0.1, 0.1)
	mat_beacon.emission_enabled = true
	mat_beacon.emission = Color(1.0, 0.1, 0.1)
	mat_beacon.emission_energy_multiplier = 4.0
	beacon.material_override = mat_beacon
	parent.add_child(beacon)

	# 3 Articulated Swing Service Umbilical Arms (Interstage, Fuel, Crew/Payload)
	for ay in [12.0, 18.5, 26.0]:
		var arm := Node3D.new()
		arm.position = Vector3(tower_x + 2.0, ay, 0.0)
		parent.add_child(arm)
		umbilical_arms.append(arm)

		var arm_beam := MeshInstance3D.new()
		var ab_box := BoxMesh.new()
		ab_box.size = Vector3(6.5, 0.45, 0.45)
		arm_beam.mesh = ab_box
		arm_beam.position = Vector3(3.25, 0.0, 0.0)
		arm_beam.material_override = mat_yellow
		arm.add_child(arm_beam)

		# Umbilical Interface Claw
		var claw := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(0.6, 1.2, 0.8)
		claw.mesh = c_box
		claw.position = Vector3(6.5, 0.0, 0.0)
		claw.material_override = mat_steel
		arm.add_child(claw)

	# --- D. 4 Mechanical Hold-Down Clamps at Rocket Base ---
	for angle in [45.0, 135.0, 225.0, 315.0]:
		var rad = deg_to_rad(angle)
		var clamp_root := Node3D.new()
		clamp_root.position = Vector3(cos(rad) * 2.3, 4.0, sin(rad) * 2.3)
		clamp_root.rotation.y = -rad + PI * 0.5
		parent.add_child(clamp_root)
		hold_down_clamps.append(clamp_root)

		# Clamp Base Pedestal
		var base_p := MeshInstance3D.new()
		var bp_box := BoxMesh.new()
		bp_box.size = Vector3(0.9, 1.2, 1.4)
		base_p.mesh = bp_box
		base_p.position = Vector3(0.0, 0.6, 0.0)
		base_p.material_override = mat_clamp
		clamp_root.add_child(base_p)

		# Pivoting Clamp Arm Jaw
		var jaw := MeshInstance3D.new()
		var j_box := BoxMesh.new()
		j_box.size = Vector3(0.4, 0.8, 1.2)
		jaw.mesh = j_box
		jaw.position = Vector3(0.0, 1.4, -0.4)
		jaw.material_override = mat_yellow
		clamp_root.add_child(jaw)

	# --- E. 4 Perimeter Lightning Protection Masts ---
	for corner in [Vector3(-26, 0, -26), Vector3(26, 0, -26), Vector3(-26, 0, 26), Vector3(26, 0, 26)]:
		var mast := MeshInstance3D.new()
		var m_cyl := CylinderMesh.new()
		m_cyl.top_radius = 0.15
		m_cyl.bottom_radius = 0.9
		m_cyl.height = 36.0
		mast.mesh = m_cyl
		mast.position = corner + Vector3(0, 18.0, 0)
		mast.material_override = mat_steel
		parent.add_child(mast)

	# --- F. Cryogenic Storage Tanks & Pipelines ---
	for tx in [18.0, 24.0]:
		var tank := MeshInstance3D.new()
		var t_sph := SphereMesh.new()
		t_sph.radius = 3.6
		t_sph.height = 7.2
		tank.mesh = t_sph
		tank.position = Vector3(tx, 4.2, -14.0)
		tank.material_override = SpacecraftMaterials.get_mat("pipe_cryo_insulation")
		parent.add_child(tank)

	# --- G. Pad Liftoff Steam & Dust Particles ---
	pad_steam_emitter = CPUParticles3D.new()
	pad_steam_emitter.name = "PadLiftoffSteam"
	pad_steam_emitter.position = Vector3(0.0, 3.8, 0.0)
	pad_steam_emitter.emitting = false
	pad_steam_emitter.amount = 80
	pad_steam_emitter.lifetime = 2.4
	pad_steam_emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	pad_steam_emitter.emission_ring_radius = 6.0
	pad_steam_emitter.emission_ring_inner_radius = 2.0
	pad_steam_emitter.direction = Vector3(0.0, 0.3, 0.0)
	pad_steam_emitter.spread = 75.0
	pad_steam_emitter.initial_velocity_min = 8.0
	pad_steam_emitter.initial_velocity_max = 16.0
	pad_steam_emitter.gravity = Vector3(0.0, 1.2, 0.0)
	pad_steam_emitter.scale_amount_min = 1.2
	pad_steam_emitter.scale_amount_max = 4.5
	pad_steam_emitter.color = Color(0.92, 0.94, 0.98, 0.45)

	var mat_steam := StandardMaterial3D.new()
	mat_steam.albedo_color = Color(0.92, 0.95, 0.98, 0.45)
	mat_steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_steam.roughness = 0.85
	pad_steam_emitter.material_override = mat_steam
	parent.add_child(pad_steam_emitter)

func _build_curved_earth_mesh(parent: Node3D) -> void:
	var earth_radius = 160.0

	# 1. Earth Sphere with High-Resolution Procedural Satellite Ocean/Continent/Cloud Texture
	var earth := MeshInstance3D.new()
	var e_sph := SphereMesh.new()
	e_sph.radius = earth_radius
	e_sph.height = earth_radius * 2.0
	e_sph.radial_segments = 96
	e_sph.rings = 48
	earth.mesh = e_sph
	earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	earth.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Orient Earth so lush equatorial/temperate oceans and continents face the ascent camera
	earth.rotation_degrees = Vector3(72.0, 50.0, -15.0)

	var img_w = 1024
	var img_h = 512
	var img := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)

	var noise_land := FastNoiseLite.new()
	noise_land.seed = 1042
	noise_land.frequency = 0.007
	noise_land.fractal_octaves = 4

	var noise_cloud := FastNoiseLite.new()
	noise_cloud.seed = 8821
	noise_cloud.frequency = 0.016
	noise_cloud.fractal_octaves = 4

	for py in range(img_h):
		var v = float(py) / float(img_h)
		var lat = (v - 0.5) * PI
		var abs_lat = abs(lat)
		for px in range(img_w):
			var u = float(px) / float(img_w)
			var lon = u * TAU
			# 3D spherical coordinates for noise sampling
			var nx = cos(lat) * cos(lon) * 90.0
			var ny = sin(lat) * 90.0
			var nz = cos(lat) * sin(lon) * 90.0

			var elev = noise_land.get_noise_3d(nx, ny, nz)
			var col: Color

			# Polar Ice Caps only at extreme poles
			if abs_lat > 1.50:
				col = Color(0.92, 0.95, 1.0)
			elif elev < 0.08:
				# Deep Oceanic Blue (Matching Reference 02 deep blue Earth)
				col = Color(0.04, 0.11, 0.28)
			elif elev < 0.16:
				# Coastal Azure / Turquoise Reefs
				col = Color(0.06, 0.28, 0.45)
			elif elev < 0.30:
				# Continent Green
				col = Color(0.12, 0.26, 0.14)
			elif elev < 0.42:
				# Savannah Tan / Arid Land
				col = Color(0.32, 0.26, 0.16)
			else:
				# Highland Brown
				col = Color(0.42, 0.35, 0.25)

			# Clouds: Swirling wispy cloud bands across oceans & continents
			var c_val = noise_cloud.get_noise_3d(nx * 1.6, ny * 1.6, nz * 1.6)
			if c_val > 0.07:
				var c_alpha = clamp((c_val - 0.07) / 0.26, 0.0, 0.90)
				col = col.lerp(Color(0.97, 0.98, 1.0), c_alpha)

			img.set_pixel(px, py, col)

	var tex := ImageTexture.create_from_image(img)

	var earth_shader := Shader.new()
	earth_shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D earth_texture : filter_linear_mipmap;

void fragment() {
	vec4 tex_col = texture(earth_texture, UV);
	
	// Directional sun illumination across curved Earth surface
	vec3 sun_dir = normalize(vec3(0.55, 0.75, 0.35));
	float NdotL = clamp(dot(NORMAL, sun_dir) * 0.70 + 0.30, 0.20, 1.0);
	
	// Rayleigh atmospheric scattering limb: Only glows along silhouette edge (1.0 - NdotV)^4
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float atmo_fresnel = pow(1.0 - NdotV, 4.0);
	vec3 atmo_cyan = vec3(0.32, 0.76, 1.0);

	vec3 surface = tex_col.rgb * NdotL;
	vec3 final_col = mix(surface, atmo_cyan, atmo_fresnel * 0.70);
	
	// Glowing cyan/azure horizon limb
	final_col += atmo_cyan * pow(1.0 - NdotV, 8.0) * 1.8;

	ALBEDO = final_col;
}
"""
	var earth_mat := ShaderMaterial.new()
	earth_mat.shader = earth_shader
	earth_mat.set_shader_parameter("earth_texture", tex)
	earth.material_override = earth_mat
	parent.add_child(earth)

func _build_transonic_vapor_cone(parent: Node3D) -> void:
	# Transonic Aerodynamic Vapor Condensation (Matching Reference 02)
	# Soft, unshaded, translucent white shockwave collar at fairing shoulder
	var mat_collar := StandardMaterial3D.new()
	mat_collar.albedo_color = Color(0.96, 0.98, 1.0, 0.28)
	mat_collar.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_collar.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_collar.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 1. Aerodynamic Shock Collar wrapping around fairing base
	var collar := MeshInstance3D.new()
	var col_cyl := CylinderMesh.new()
	col_cyl.top_radius = 1.35
	col_cyl.bottom_radius = 2.1
	col_cyl.height = 1.2
	col_cyl.radial_segments = 32
	collar.mesh = col_cyl
	collar.position = Vector3(0.0, -0.4, 0.0)
	collar.material_override = mat_collar
	parent.add_child(collar)

	# 2. Secondary soft vapor expansion skirt
	var mat_fringe := StandardMaterial3D.new()
	mat_fringe.albedo_color = Color(0.96, 0.98, 1.0, 0.14)
	mat_fringe.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_fringe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fringe.cull_mode = BaseMaterial3D.CULL_DISABLED

	var fringe := MeshInstance3D.new()
	var fr_cyl := CylinderMesh.new()
	fr_cyl.top_radius = 2.0
	fr_cyl.bottom_radius = 2.7
	fr_cyl.height = 1.0
	fr_cyl.radial_segments = 32
	fringe.mesh = fr_cyl
	fringe.position = Vector3(0.0, -1.3, 0.0)
	fringe.material_override = mat_fringe
	parent.add_child(fringe)

	# 3. 4 Delicate Vapor Streamers trailing along the 4 strap-on boosters
	var mat_stream := StandardMaterial3D.new()
	mat_stream.albedo_color = Color(0.96, 0.98, 1.0, 0.16)
	mat_stream.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_stream.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_stream.cull_mode = BaseMaterial3D.CULL_DISABLED

	for o in [Vector3(-1.1, -2.5, -1.1), Vector3(1.1, -2.5, -1.1), Vector3(-1.1, -2.5, 1.1), Vector3(1.1, -2.5, 1.1)]:
		var st := MeshInstance3D.new()
		var st_cyl := CylinderMesh.new()
		st_cyl.top_radius = 0.35
		st_cyl.bottom_radius = 0.55
		st_cyl.height = 4.2
		st_cyl.radial_segments = 16
		st.mesh = st_cyl
		st.position = o
		st.material_override = mat_stream
		parent.add_child(st)

func _build_engine_exhaust_fx(parent: Node3D) -> void:
	# 1. 4 White-Hot Core Engine Flames under the 4 nozzles
	var mat_core := StandardMaterial3D.new()
	mat_core.albedo_color = Color(1.0, 1.0, 1.0)
	mat_core.emission_enabled = true
	mat_core.emission = Color(1.0, 1.0, 1.0)
	mat_core.emission_energy_multiplier = 14.0
	mat_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var offsets = [
		Vector3(-0.95, -0.6, -0.95),
		Vector3(0.95, -0.6, -0.95),
		Vector3(-0.95, -0.6, 0.95),
		Vector3(0.95, -0.6, 0.95)
	]

	for o in offsets:
		var flame := MeshInstance3D.new()
		var f_cyl := CylinderMesh.new()
		f_cyl.top_radius = 0.35
		f_cyl.bottom_radius = 0.95
		f_cyl.height = 4.2
		f_cyl.radial_segments = 16
		flame.mesh = f_cyl
		flame.position = o + Vector3(0.0, -2.1, 0.0)
		flame.material_override = mat_core
		parent.add_child(flame)

	# 2. Merged Supersonic Expansion Fire Cone (Dazzling Fire)
	var mat_fire := StandardMaterial3D.new()
	mat_fire.albedo_color = Color(1.0, 0.92, 0.70, 0.90)
	mat_fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_fire.emission_enabled = true
	mat_fire.emission = Color(1.0, 0.85, 0.50)
	mat_fire.emission_energy_multiplier = 8.0
	mat_fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var exp_cone := MeshInstance3D.new()
	var ec_cyl := CylinderMesh.new()
	ec_cyl.top_radius = 1.1
	ec_cyl.bottom_radius = 2.4
	ec_cyl.height = 6.0
	ec_cyl.radial_segments = 20
	exp_cone.mesh = ec_cyl
	exp_cone.position = Vector3(0.0, -4.2, 0.0)
	exp_cone.material_override = mat_fire
	parent.add_child(exp_cone)

	# 3. Cascading Billowing Smoke Contrail Puffs (Matching Reference 02 turbulent contrail)
	var puff_configs = [
		{"pos": Vector3(0.0, -8.0, 0.0), "r_top": 1.8, "r_bot": 3.0, "h": 5.0, "alpha": 0.45},
		{"pos": Vector3(0.0, -13.5, 0.0), "r_top": 2.8, "r_bot": 4.5, "h": 6.5, "alpha": 0.32},
		{"pos": Vector3(0.0, -20.5, 0.0), "r_top": 4.2, "r_bot": 6.5, "h": 8.0, "alpha": 0.20},
		{"pos": Vector3(0.0, -29.0, 0.0), "r_top": 6.0, "r_bot": 9.0, "h": 10.0, "alpha": 0.12}
	]

	for cfg in puff_configs:
		var mat_puff := StandardMaterial3D.new()
		mat_puff.albedo_color = Color(0.96, 0.97, 1.0, cfg["alpha"])
		mat_puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_puff.roughness = 0.85
		mat_puff.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat_puff.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

		var puff := MeshInstance3D.new()
		var p_cyl := CylinderMesh.new()
		p_cyl.top_radius = cfg["r_top"]
		p_cyl.bottom_radius = cfg["r_bot"]
		p_cyl.height = cfg["h"]
		p_cyl.radial_segments = 16
		puff.mesh = p_cyl
		puff.position = cfg["pos"]
		puff.material_override = mat_puff
		parent.add_child(puff)

	# Luminous Exhaust Flame Light
	var flame_light := OmniLight3D.new()
	flame_light.name = "PlumeLight"
	flame_light.light_color = Color(1.0, 0.88, 0.55)
	flame_light.light_energy = 5.0
	flame_light.omni_range = 35.0
	flame_light.position = Vector3(0.0, -4.0, 0.0)
	parent.add_child(flame_light)

	# Dynamic particle emitter
	plume_smoke_emitter = CPUParticles3D.new()
	plume_smoke_emitter.name = "AscentPlumeSmoke"
	plume_smoke_emitter.position = Vector3(0.0, -2.5, 0.0)
	plume_smoke_emitter.emitting = false
	plume_smoke_emitter.amount = 90
	plume_smoke_emitter.lifetime = 1.1
	plume_smoke_emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	plume_smoke_emitter.emission_sphere_radius = 1.2
	plume_smoke_emitter.direction = Vector3(0.0, -1.0, 0.0)
	plume_smoke_emitter.spread = 14.0
	plume_smoke_emitter.initial_velocity_min = 28.0
	plume_smoke_emitter.initial_velocity_max = 42.0
	plume_smoke_emitter.gravity = Vector3(0.0, -4.0, 0.0)
	plume_smoke_emitter.scale_amount_min = 0.8
	plume_smoke_emitter.scale_amount_max = 3.6
	plume_smoke_emitter.color = Color(1.0, 0.95, 0.85, 0.75)
	plume_smoke_emitter.material_override = SpacecraftMaterials.get_mat("engine_plume_smoke")
	parent.add_child(plume_smoke_emitter)

func _build_vacuum_exhaust_fx(parent: Node3D) -> void:
	# Stage 2 Vacuum Expanding Plume (Ethereal Blue/Violet bell)
	var vac_flame := MeshInstance3D.new()
	var vf_cyl := CylinderMesh.new()
	vf_cyl.top_radius = 0.35
	vf_cyl.bottom_radius = 2.4
	vf_cyl.height = 4.5
	vf_cyl.radial_segments = 24
	vac_flame.mesh = vf_cyl
	vac_flame.position = Vector3(0.0, -2.25, 0.0)
	vac_flame.material_override = SpacecraftMaterials.get_mat("vacuum_plume_blue")
	parent.add_child(vac_flame)

func _build_detached_booster_mesh(parent: Node3D) -> void:
	# Clone Stage 1 booster stack for physical tumbling separation
	var mat_steel := SpacecraftMaterials.get_mat("rocket_machined_steel")
	var mat_dark := SpacecraftMaterials.get_mat("rocket_dark_carbon")

	# Core column
	var core := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 1.1
	c_cyl.bottom_radius = 1.1
	c_cyl.height = 5.6
	core.mesh = c_cyl
	core.material_override = mat_dark
	parent.add_child(core)

	# 4 Strap-on booster tanks
	var offsets = [
		Vector3(-0.95, 0.0, -0.95),
		Vector3(0.95, 0.0, -0.95),
		Vector3(-0.95, 0.0, 0.95),
		Vector3(0.95, 0.0, 0.95)
	]
	for o in offsets:
		var tank := MeshInstance3D.new()
		var t_cyl := CylinderMesh.new()
		t_cyl.top_radius = 0.68
		t_cyl.bottom_radius = 0.68
		t_cyl.height = 4.4
		tank.mesh = t_cyl
		tank.position = o
		tank.material_override = mat_steel
		parent.add_child(tank)

	# 4 Grid Fins
	for a in [45.0, 135.0, 225.0, 315.0]:
		var r = deg_to_rad(a)
		var fin := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(0.4, 0.8, 0.08)
		fin.mesh = f_box
		fin.position = Vector3(cos(r) * 2.1, 2.2, sin(r) * 2.1)
		fin.rotation.y = -r
		fin.material_override = SpacecraftMaterials.get_mat("titanium")
		parent.add_child(fin)

func _build_jettisoned_fairings(left_node: Node3D, right_node: Node3D) -> void:
	var mat_fairing := SpacecraftMaterials.get_mat("rocket_machined_steel")
	for node in [left_node, right_node]:
		var shell := MeshInstance3D.new()
		var c_cyl := CylinderMesh.new()
		c_cyl.top_radius = 0.5
		c_cyl.bottom_radius = 1.35
		c_cyl.height = 4.2
		c_cyl.radial_segments = 20
		shell.mesh = c_cyl
		shell.material_override = mat_fairing
		node.add_child(shell)

# ==============================================================================
# 2. PROCEDURAL VECTOR HUD WIDGETS
# ==============================================================================

func _setup_procedural_hud_widgets() -> void:
	# A. NavBall / Attitude Director Sphere (Bottom Center)
	var nav_container = find_child("NavBallContainer", true, false)
	if nav_container:
		navball_widget = Helios4HUDWidgets.NavBall.new()
		navball_widget.custom_minimum_size = Vector2(100, 100)
		navball_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navball_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
		nav_container.add_child(navball_widget)

	# B. Dynamic Max-Q Warning Arc Widget (Above rocket nose)
	var max_q_container = find_child("MaxQArcHolder", true, false)
	if max_q_container:
		max_q_arc_widget = Helios4HUDWidgets.MaxQArcWidget.new()
		max_q_arc_widget.custom_minimum_size = Vector2(140, 110)
		max_q_arc_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		max_q_arc_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
		max_q_container.add_child(max_q_arc_widget)

	# C. Vertical Moving Altitude Tape (Left Telemetry Ribbon)
	var alt_container = find_child("LeftTelemetryTape", true, false)
	if alt_container:
		altitude_tape_widget = Helios4HUDWidgets.AltitudeTape.new()
		altitude_tape_widget.custom_minimum_size = Vector2(56, 260)
		altitude_tape_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		altitude_tape_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
		alt_container.add_child(altitude_tape_widget)

	# D. Vertical Throttle Gauge (Bottom Left)
	var throt_container = find_child("ThrottleHolder", true, false)
	if throt_container:
		throttle_widget = Helios4HUDWidgets.VerticalThrottleGauge.new()
		throttle_widget.custom_minimum_size = Vector2(40, 124)
		throttle_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		throttle_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
		throt_container.add_child(throttle_widget)

	# E. Staging Column Diagram (Bottom Left)
	var staging_container = find_child("StagingHolder", true, false)
	if staging_container:
		staging_widget = Helios4HUDWidgets.StagingColumn.new()
		staging_widget.custom_minimum_size = Vector2(56, 124)
		staging_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		staging_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
		staging_container.add_child(staging_widget)

	# F. Radar Scope (Top Right)
	var radar_container = find_child("TopRightRadarScope", true, false)
	if radar_container:
		radar_widget = Helios4HUDWidgets.RadarScope.new()
		radar_widget.custom_minimum_size = Vector2(80, 80)
		radar_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		radar_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
		radar_container.add_child(radar_widget)

	# G. Attitude Vector Scope (Bottom Right, matching reference 02)
	var att_container = find_child("BottomRightAttitudeScope", true, false)
	if att_container:
		attitude_widget = Helios4HUDWidgets.AttitudeScope.new()
		attitude_widget.custom_minimum_size = Vector2(80, 80)
		attitude_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attitude_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
		att_container.add_child(attitude_widget)

	# H. Top Center 4 Officer Vector Icons
	_setup_top_officer_icons()

func _setup_top_officer_icons() -> void:
	var map = [
		{"holder": "IconHolderProp", "type": "wrench", "col": Color(0.98, 0.65, 0.12)},
		{"holder": "IconHolderStruct", "type": "radar", "col": Color(0.25, 0.88, 0.48)},
		{"holder": "IconHolderAstro", "type": "planetary", "col": Color(0.95, 0.40, 0.50)},
		{"holder": "IconHolderSys", "type": "electrical", "col": Color(0.20, 0.85, 1.00)}
	]
	for item in map:
		var container = find_child(item["holder"], true, false)
		if container:
			var icon = Helios4HUDWidgets.SpecialistIcon.new()
			icon.role_type = item["type"]
			icon.icon_color = item["col"]
			icon.custom_minimum_size = Vector2(28, 26)
			container.add_child(icon)

# ==============================================================================
# 3. MULTI-CAMERA SYSTEM (7 STATES)
# ==============================================================================

func _set_camera_mode(mode: CameraMode, instant: bool = false) -> void:
	current_cam_mode = mode
	_update_camera_buttons_styling()

	match mode:
		CameraMode.PAD:
			# Low-angle ground view establishing launch mount & towering rocket
			_cam_target_pos = Vector3(-14.0, 5.0, 18.0)
			_cam_target_rot = Vector3(-10.0, -32.0, 0.0)
		CameraMode.ENGINE:
			# Close-up of 4 engine bells, flame deflector trench, and hold-down clamps
			_cam_target_pos = Vector3(3.2, 1.8, 6.5)
			_cam_target_rot = Vector3(14.0, 26.0, 0.0)
		CameraMode.CHASE:
			# Behind & slightly below ascending rocket looking along blazing exhaust plume
			_cam_target_pos = Vector3(-3.5, 3.5, 16.5)
			_cam_target_rot = Vector3(-12.0, -12.0, 0.0)
		CameraMode.WIDE:
			# High-altitude wide view showing rocket climbing against curved Earth
			_cam_target_pos = Vector3(-24.0, 8.0, 32.0)
			_cam_target_rot = Vector3(-8.0, -35.0, 0.0)
		CameraMode.MAX_Q:
			# THE SIGNATURE VIEW (Matching Reference 02_helios4_launch_maxq.png exact angle):
			# 3/4 isometric perspective from behind/left framing rocket ascending diagonally across Earth curvature
			_cam_target_pos = Vector3(-4.0, 8.2, 17.5)
			_cam_target_rot = Vector3(-7.0, -18.0, 12.0)
		CameraMode.SEPARATION:
			# Focused on interstage during uncoupling of Stage 1 booster core
			_cam_target_pos = Vector3(-7.5, 4.2, 13.5)
			_cam_target_rot = Vector3(-8.0, -24.0, 4.0)
		CameraMode.ORBITAL:
			# Orbital insertion view above atmosphere rim in space
			_cam_target_pos = Vector3(-14.0, 9.5, 18.5)
			_cam_target_rot = Vector3(-18.0, -32.0, 0.0)

	if instant and launch_cam and rocket:
		launch_cam.position = rocket.position + _cam_target_pos
		launch_cam.rotation_degrees = _cam_target_rot

var _style_cam_act: StyleBoxFlat = null
var _style_cam_norm: StyleBoxFlat = null

func _get_cam_btn_styles() -> Array:
	if not _style_cam_act:
		_style_cam_act = StyleBoxFlat.new()
		_style_cam_act.bg_color = Color(0.18, 0.55, 0.88, 0.95)
		_style_cam_act.border_color = Color(0.4, 0.9, 1.0, 1.0)
		_style_cam_act.set_border_width_all(1)
		_style_cam_act.set_corner_radius_all(4)
		_style_cam_act.content_margin_left = 8.0
		_style_cam_act.content_margin_right = 8.0
		_style_cam_act.content_margin_top = 4.0
		_style_cam_act.content_margin_bottom = 4.0

		_style_cam_norm = StyleBoxFlat.new()
		_style_cam_norm.bg_color = Color(0.08, 0.12, 0.18, 0.85)
		_style_cam_norm.border_color = Color(0.25, 0.35, 0.5, 0.6)
		_style_cam_norm.set_border_width_all(1)
		_style_cam_norm.set_corner_radius_all(4)
		_style_cam_norm.content_margin_left = 8.0
		_style_cam_norm.content_margin_right = 8.0
		_style_cam_norm.content_margin_top = 4.0
		_style_cam_norm.content_margin_bottom = 4.0
	return [_style_cam_act, _style_cam_norm]

func _update_camera_buttons_styling() -> void:
	var styles = _get_cam_btn_styles()
	var style_act: StyleBoxFlat = styles[0]
	var style_norm: StyleBoxFlat = styles[1]

	var btns = [
		{"btn": find_child("CamBtn_Pad", true, false), "active": current_cam_mode == CameraMode.PAD},
		{"btn": find_child("CamBtn_Engine", true, false), "active": current_cam_mode == CameraMode.ENGINE},
		{"btn": find_child("CamBtn_Chase", true, false), "active": current_cam_mode == CameraMode.CHASE},
		{"btn": find_child("CamBtn_Wide", true, false), "active": current_cam_mode == CameraMode.WIDE},
		{"btn": find_child("CamBtn_MaxQ", true, false), "active": current_cam_mode == CameraMode.MAX_Q},
		{"btn": find_child("CamBtn_Sep", true, false), "active": current_cam_mode == CameraMode.SEPARATION},
		{"btn": find_child("CamBtn_Orbit", true, false), "active": current_cam_mode == CameraMode.ORBITAL}
	]
	for b in btns:
		if b["btn"] and b["btn"] is Button:
			b["btn"].add_theme_stylebox_override("normal", style_act if b["active"] else style_norm)

# ==============================================================================
# 4. FLIGHT DYNAMICS & ASCENT SIMULATION
# ==============================================================================

# ==============================================================================
# 4. PRE-LAUNCH CHECKLIST, FLIGHT DYNAMICS & ASCENT SIMULATION
# ==============================================================================

func _build_flight_controls_legend() -> void:
	var root_ui = find_child("RootUI", true, false)
	if not root_ui:
		return
	
	flight_legend_lbl = Label.new()
	flight_legend_lbl.name = "FlightControlsLegend"
	flight_legend_lbl.text = "FLIGHT CONTROLS: [W/S] Throttle • [A/D] Pitch Steering (Gravity Turn) • [SPACE] Staging • [E] Systems • [T] Time Warp • [1-7] Cameras"
	flight_legend_lbl.add_theme_font_size_override("font_size", 10)
	flight_legend_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95, 0.85))
	flight_legend_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flight_legend_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	flight_legend_lbl.offset_top = -42.0
	flight_legend_lbl.offset_bottom = -26.0
	root_ui.add_child(flight_legend_lbl)

func _show_readiness_hold_modal() -> void:
	var root_ui = find_child("RootUI", true, false)
	if not root_ui:
		return

	hold_modal_panel = PanelContainer.new()
	hold_modal_panel.name = "ReadinessHoldModal"
	hold_modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	hold_modal_panel.custom_minimum_size = Vector2(560, 260)
	hold_modal_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hold_modal_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.04, 0.04, 0.96)
	p_style.border_color = Color(0.95, 0.35, 0.35, 1.0)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(8)
	p_style.content_margin_left = 24
	p_style.content_margin_top = 20
	p_style.content_margin_right = 24
	p_style.content_margin_bottom = 20
	hold_modal_panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "▲ FLIGHT AUTHORIZATION REQUIRED: ENGINEERING REVIEW HOLD"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "HELIOS-4 launchpad ignition is locked. The launch vehicle configuration has not passed the mandatory Engineering Readiness Review or is missing 4-officer unanimous authorization.\n\nPlease complete the Flight Readiness Review to verify TWR, multi-stage Delta-V, structural stability, power surplus, and payload envelope constraints."
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_END

	var btn_review := Button.new()
	btn_review.text = "PROCEED TO READINESS REVIEW →"
	btn_review.add_theme_font_size_override("font_size", 11)
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.12, 0.52, 0.82, 0.95)
	r_style.border_color = Color(0.35, 0.9, 1.0)
	r_style.set_border_width_all(1)
	r_style.set_corner_radius_all(4)
	r_style.content_margin_left = 14
	r_style.content_margin_right = 14
	r_style.content_margin_top = 8
	r_style.content_margin_bottom = 8
	btn_review.add_theme_stylebox_override("normal", r_style)
	btn_review.pressed.connect(func():
		Helios4CampaignData.load_stage(Helios4CampaignData.Stage.ENGINEERING_REVIEW, get_tree())
	)
	hbox.add_child(btn_review)

	var btn_hangar := Button.new()
	btn_hangar.text = "RETURN TO ASSEMBLY HANGAR"
	btn_hangar.add_theme_font_size_override("font_size", 11)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color(0.1, 0.14, 0.20, 0.9)
	h_style.border_color = Color(0.3, 0.4, 0.55)
	h_style.set_border_width_all(1)
	h_style.set_corner_radius_all(4)
	h_style.content_margin_left = 12
	h_style.content_margin_right = 12
	h_style.content_margin_top = 8
	h_style.content_margin_bottom = 8
	btn_hangar.add_theme_stylebox_override("normal", h_style)
	btn_hangar.pressed.connect(func():
		Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_1_HANGAR, get_tree())
	)
	hbox.add_child(btn_hangar)

	vbox.add_child(hbox)
	hold_modal_panel.add_child(vbox)
	root_ui.add_child(hold_modal_panel)

func _build_prelaunch_checklist_ui() -> void:
	var root_ui = find_child("RootUI", true, false)
	if not root_ui:
		return

	if prelaunch_panel:
		prelaunch_panel.queue_free()

	prelaunch_panel = PanelContainer.new()
	prelaunch_panel.name = "PrelaunchChecklistPanel"
	prelaunch_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	prelaunch_panel.offset_left = 82.0
	prelaunch_panel.offset_top = 84.0
	prelaunch_panel.custom_minimum_size = Vector2(340, 310)

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.07, 0.12, 0.94)
	p_style.border_color = Color(0.25, 0.65, 0.95, 0.85)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 12
	p_style.content_margin_top = 10
	p_style.content_margin_right = 12
	p_style.content_margin_bottom = 10
	prelaunch_panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.name = "PrelaunchVBox"
	vbox.add_theme_constant_override("separation", 6)

	var title_box := HBoxContainer.new()
	var t_lbl := Label.new()
	t_lbl.text = "PRE-LAUNCH FLIGHT READINESS CONSOLE"
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.add_theme_font_size_override("font_size", 11)
	t_lbl.add_theme_color_override("font_color", Color(0.35, 0.88, 1.0))
	title_box.add_child(t_lbl)
	vbox.add_child(title_box)

	# 6 Interactive Checklist Items
	var check_items = [
		{"key": "ground_systems", "label": "Ground Umbilicals & Clamps", "role": "STRUCT"},
		{"key": "propellant", "label": "Cryogenic Tank Pressurization", "role": "PROP"},
		{"key": "avionics", "label": "Internal Battery Power Transfer", "role": "SYS"},
		{"key": "comms", "label": "DSN 34m RF Telemetry Lock", "role": "SYS"},
		{"key": "engines", "label": "Turbopump Chill & Igniters Armed", "role": "PROP"},
		{"key": "guidance", "label": "Guidance Profile & IMU Alignment", "role": "ASTRO"}
	]

	for item in check_items:
		var k = item["key"]
		var btn := Button.new()
		btn.name = "BtnCheck_" + k
		btn.text = "[%s] %s: PENDING" % [item["role"], item["label"]]
		btn.add_theme_font_size_override("font_size", 10)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var is_checked = prelaunch_checks[k]
		_style_check_btn(btn, is_checked)
		btn.pressed.connect(func():
			prelaunch_checks[k] = not prelaunch_checks[k]
			_refresh_prelaunch_checklist_ui()
		)
		vbox.add_child(btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Action Buttons
	var auto_btn := Button.new()
	auto_btn.name = "BtnAutoVerifyPreflight"
	auto_btn.text = "⚡ AUTO-VERIFY ALL [RAPID PREFLIGHT]"
	auto_btn.add_theme_font_size_override("font_size", 10)
	var auto_style := StyleBoxFlat.new()
	auto_style.bg_color = Color(0.12, 0.22, 0.35, 0.9)
	auto_style.border_color = Color(0.3, 0.65, 0.95)
	auto_style.set_border_width_all(1)
	auto_style.set_corner_radius_all(4)
	auto_btn.add_theme_stylebox_override("normal", auto_style)
	auto_btn.pressed.connect(_on_auto_verify_all_pressed)
	vbox.add_child(auto_btn)

	var countdown_row := HBoxContainer.new()
	countdown_row.add_theme_constant_override("separation", 6)

	var start_cd_btn := Button.new()
	start_cd_btn.name = "BtnStartCountdown"
	start_cd_btn.text = "INITIATE COUNTDOWN (T-10s)"
	start_cd_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_cd_btn.add_theme_font_size_override("font_size", 10)
	var cd_style := StyleBoxFlat.new()
	cd_style.bg_color = Color(0.15, 0.55, 0.35, 0.95)
	cd_style.border_color = Color(0.35, 0.95, 0.55)
	cd_style.set_border_width_all(1)
	cd_style.set_corner_radius_all(4)
	start_cd_btn.add_theme_stylebox_override("normal", cd_style)
	start_cd_btn.pressed.connect(_on_start_countdown_pressed)
	countdown_row.add_child(start_cd_btn)

	var pause_cd_btn := Button.new()
	pause_cd_btn.name = "BtnPauseCountdown"
	pause_cd_btn.text = "HOLD"
	pause_cd_btn.custom_minimum_size = Vector2(48, 0)
	pause_cd_btn.add_theme_font_size_override("font_size", 10)
	pause_cd_btn.pressed.connect(_on_pause_countdown_pressed)
	countdown_row.add_child(pause_cd_btn)

	var abort_cd_btn := Button.new()
	abort_cd_btn.name = "BtnAbortLaunchPrep"
	abort_cd_btn.text = "ABORT"
	abort_cd_btn.custom_minimum_size = Vector2(54, 0)
	abort_cd_btn.add_theme_font_size_override("font_size", 10)
	var ab_style := StyleBoxFlat.new()
	ab_style.bg_color = Color(0.35, 0.1, 0.1, 0.9)
	ab_style.border_color = Color(0.95, 0.35, 0.35)
	ab_style.set_border_width_all(1)
	ab_style.set_corner_radius_all(4)
	abort_cd_btn.add_theme_stylebox_override("normal", ab_style)
	abort_cd_btn.pressed.connect(_on_abort_countdown_pressed)
	countdown_row.add_child(abort_cd_btn)

	vbox.add_child(countdown_row)

	prelaunch_panel.add_child(vbox)
	root_ui.add_child(prelaunch_panel)
	_refresh_prelaunch_checklist_ui()

func _style_check_btn(btn: Button, is_checked: bool) -> void:
	var style := StyleBoxFlat.new()
	if is_checked:
		style.bg_color = Color(0.08, 0.22, 0.12, 0.95)
		style.border_color = Color(0.35, 0.95, 0.55, 0.9)
	else:
		style.bg_color = Color(0.08, 0.11, 0.16, 0.85)
		style.border_color = Color(0.25, 0.35, 0.48, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	var col = Color(0.35, 0.95, 0.55) if is_checked else Color(0.8, 0.85, 0.92)
	btn.add_theme_color_override("font_color", col)

func _refresh_prelaunch_checklist_ui() -> void:
	if not prelaunch_panel:
		return
	var check_items = [
		{"key": "ground_systems", "label": "Ground Umbilicals & Clamps", "role": "STRUCT"},
		{"key": "propellant", "label": "Cryogenic Tank Pressurization", "role": "PROP"},
		{"key": "avionics", "label": "Internal Battery Power Transfer", "role": "SYS"},
		{"key": "comms", "label": "DSN 34m RF Telemetry Lock", "role": "SYS"},
		{"key": "engines", "label": "Turbopump Chill & Igniters Armed", "role": "PROP"},
		{"key": "guidance", "label": "Guidance Profile & IMU Alignment", "role": "ASTRO"}
	]

	var all_verified: bool = true
	for item in check_items:
		var k = item["key"]
		var is_checked = prelaunch_checks[k]
		if not is_checked: all_verified = false
		var btn = prelaunch_panel.find_child("BtnCheck_" + k, true, false) as Button
		if btn:
			btn.text = "[%s] %s: %s" % [item["role"], item["label"], "VERIFIED [OK]" if is_checked else "PENDING"]
			_style_check_btn(btn, is_checked)

	var start_cd_btn = prelaunch_panel.find_child("BtnStartCountdown", true, false) as Button
	if start_cd_btn:
		if all_verified:
			start_cd_btn.text = "INITIATE COUNTDOWN (T-10s) →"
			start_cd_btn.disabled = false
		else:
			start_cd_btn.text = "VERIFY ALL CHECKS BEFORE COUNTDOWN"
			start_cd_btn.disabled = false

func _on_auto_verify_all_pressed() -> void:
	for k in prelaunch_checks:
		prelaunch_checks[k] = true
	_refresh_prelaunch_checklist_ui()
	print("[Launch] All pre-launch flight readiness checks verified.")

func _on_start_countdown_pressed() -> void:
	var all_verified: bool = true
	for k in prelaunch_checks:
		if not prelaunch_checks[k]:
			all_verified = false
			break
	if not all_verified:
		var advisory_lbl = find_child("AdvisoryBanner", true, false) as Label
		if advisory_lbl:
			advisory_lbl.text = "▲ LAUNCH HOLD: Complete all 6 pre-launch checks or press AUTO-VERIFY before countdown."
			advisory_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
		return

	current_phase = FlightPhase.COUNTDOWN
	countdown_s = 10.0
	countdown_paused = false
	print("[Launch] COUNTDOWN INITIATED: T-minus 10 seconds to HELIOS-4 liftoff.")

func _on_pause_countdown_pressed() -> void:
	if current_phase == FlightPhase.COUNTDOWN:
		countdown_paused = not countdown_paused
		var p_btn = prelaunch_panel.find_child("BtnPauseCountdown", true, false) as Button
		if p_btn:
			p_btn.text = "RESUME" if countdown_paused else "HOLD"
		var advisory_lbl = find_child("AdvisoryBanner", true, false) as Label
		if advisory_lbl:
			advisory_lbl.text = ("● COUNTDOWN HOLD: Paused at T-%.1f seconds." % countdown_s) if countdown_paused else ("RESUMING COUNTDOWN: T-%.1f seconds." % countdown_s)
			advisory_lbl.add_theme_color_override("font_color", Color(0.98, 0.65, 0.15) if countdown_paused else Color(0.35, 0.85, 1.0))

func _on_abort_countdown_pressed() -> void:
	current_phase = FlightPhase.PRE_LAUNCH_PREPARATION
	countdown_s = 10.0
	countdown_paused = false
	if pad_steam_emitter: pad_steam_emitter.emitting = false
	var advisory_lbl = find_child("AdvisoryBanner", true, false) as Label
	if advisory_lbl:
		advisory_lbl.text = "● LAUNCH COUNTDOWN ABORTED: Pad safe, reset to pre-flight standby."
		advisory_lbl.add_theme_color_override("font_color", Color(0.98, 0.65, 0.15))
	_refresh_prelaunch_checklist_ui()

func _physics_process(delta: float) -> void:
	delta *= time_warp
	if current_phase == FlightPhase.FLIGHT_COMPLETED or current_phase == FlightPhase.FLIGHT_ABORTED or current_phase == FlightPhase.READINESS_HOLD:
		_update_camera_smooth(delta)
		return

	# Pre-Launch Preparation
	if current_phase == FlightPhase.PRE_LAUNCH_PREPARATION:
		_update_ui()
		_update_camera_smooth(delta)
		return

	# Countdown
	if current_phase == FlightPhase.COUNTDOWN:
		if not countdown_paused:
			countdown_s -= delta
			if countdown_s <= 3.0 and pad_steam_emitter and not pad_steam_emitter.emitting:
				pad_steam_emitter.emitting = true
			if countdown_s <= 0.0:
				countdown_s = 0.0
				_execute_ignition_liftoff()
		_update_ui()
		_update_camera_smooth(delta)
		return

	flight_time_s += delta
	_update_flight_physics(delta)
	_update_3d_visuals(delta)
	_update_ui()
	_check_phase_transitions()
	_update_camera_smooth(delta)

func _execute_ignition_liftoff() -> void:
	var all_checked: bool = true
	for k in prelaunch_checks:
		if not prelaunch_checks[k]:
			all_checked = false
			break
	if not all_checked:
		print("[Launch] LAUNCH INTERLOCK: Attempted ignition without completing pre-launch checklist!")
		_trigger_flight_abort("LAUNCH INTERLOCK ABORT: Ground systems and engine readiness checks incomplete before ignition.")
		return

	var tel = Helios4CampaignData.calculate_hangar_telemetry()
	var twr_liftoff = tel["liftoff_twr"] * throttle

	# Pad FX
	if pad_steam_emitter: pad_steam_emitter.emitting = true
	if plume_smoke_emitter: plume_smoke_emitter.emitting = true
	if main_plumes_node: main_plumes_node.visible = true

	# Physical TWR check: Must be > 1.0 to clear pad!
	if twr_liftoff <= 1.00:
		print("[Launch] LIFTOFF FAILED! TWR is %.2f <= 1.00. Rocket cannot lift off!" % twr_liftoff)
		_trigger_flight_abort("INSUFFICIENT LIFTOFF THRUST (TWR %.2f <= 1.00): Vehicle cannot overcome gravity to clear launch mount. Engines fired but vehicle remained on pad." % twr_liftoff)
		return

	current_phase = FlightPhase.ASCENT_STAGE1
	print("[Launch] LIFTOFF OF HELIOS-4! Clamps released. Tower clearance nominal.")

	# Release mechanical hold-down clamps
	for cl in hold_down_clamps:
		var tween = create_tween()
		tween.tween_property(cl, "rotation_degrees:x", -35.0, 0.4)

	# Swing away umbilical service arms
	for arm in umbilical_arms:
		var tween = create_tween()
		tween.tween_property(arm, "rotation_degrees:y", -75.0, 0.8)

	if prelaunch_panel:
		prelaunch_panel.visible = false

	# Auto-switch to Chase view if on Pad camera
	if current_cam_mode == CameraMode.PAD:
		_set_camera_mode(CameraMode.CHASE)

func _update_flight_physics(delta: float) -> void:
	var v_cfg = Helios4CampaignData.vehicle_config
	var thrust_n: float = 0.0
	var isp_s: float = 320.0

	# Atmospheric Density Model: rho = rho_0 * exp(-h / H)
	var air_density: float = RHO_0 * exp(-altitude_m / SCALE_HEIGHT_M) if altitude_m < 85000.0 else 0.0

	# Dynamic Pressure: q = 0.5 * rho * v^2 / 1000.0 (in kPa)
	dynamic_pressure_kpa = (0.5 * air_density * velocity_ms * velocity_ms) / 1000.0
	if dynamic_pressure_kpa > max_q_achieved_kpa:
		max_q_achieved_kpa = dynamic_pressure_kpa

	# Check Max-Q Corridor (typically 10km to 15km altitude, ~30-36 kPa)
	if dynamic_pressure_kpa > 27.5 and not stage1_separated:
		current_phase = FlightPhase.MAX_Q_CORRIDOR
		if vapor_cone_node:
			vapor_cone_node.visible = true
			var cone_scale = clamp((dynamic_pressure_kpa - 25.0) / 10.0, 0.8, 1.25)
			vapor_cone_node.scale = Vector3(cone_scale, cone_scale, cone_scale)

		# Auto-switch to signature Max-Q camera if on Chase view
		if current_cam_mode == CameraMode.CHASE and dynamic_pressure_kpa > 30.0:
			_set_camera_mode(CameraMode.MAX_Q)

		# Structural Stress accumulation: If throttle > 0.75 during peak dynamic pressure, stress accumulates
		if dynamic_pressure_kpa > 28.0 and throttle > 0.75:
			structural_stress_pct += delta * 14.0 * (throttle - 0.75) * (dynamic_pressure_kpa / 30.0)
			if structural_stress_pct >= 100.0:
				_trigger_flight_abort("MAX-Q STRUCTURAL FAILURE: Dynamic pressure (%.1f kPa) exceeded vehicle design envelope. Throttle was not reduced through Max-Q." % dynamic_pressure_kpa)
				return
	else:
		if vapor_cone_node:
			vapor_cone_node.visible = false

	# Propulsion and Fuel Depletion
	if not stage1_separated:
		var s1_thrust_max = v_cfg.get("stage1_thrust_kn", 480.0) * 1000.0
		thrust_n = s1_thrust_max * throttle
		isp_s = v_cfg.get("stage1_isp_s", 320.0)
		var mdot = thrust_n / (isp_s * G0) if thrust_n > 0.0 else 0.0
		var burn_fuel = mdot * delta
		s1_fuel_kg = max(0.0, s1_fuel_kg - burn_fuel)
		current_mass_kg = max(current_mass_kg - burn_fuel, 8000.0)

		if s1_fuel_kg <= 0.0 and current_phase != FlightPhase.STAGE1_BURNOUT and current_phase != FlightPhase.STAGE_SEPARATION:
			current_phase = FlightPhase.STAGE1_BURNOUT
			throttle = 0.0
			thrust_n = 0.0
			if plume_smoke_emitter: plume_smoke_emitter.emitting = false
			if main_plumes_node: main_plumes_node.visible = false
			_set_camera_mode(CameraMode.SEPARATION)
			print("[Launch] MECO: Main Engine Cut-Off. Stage 1 Burnout confirmed.")
	elif not orbit_achieved:
		# Stage 2 Vacuum Burn
		var s2_thrust_max = v_cfg.get("stage2_thrust_kn", 65.0) * 1000.0
		thrust_n = s2_thrust_max * throttle
		isp_s = v_cfg.get("stage2_isp_s", 450.0)
		var mdot2 = thrust_n / (isp_s * G0) if thrust_n > 0.0 else 0.0
		var burn_fuel2 = mdot2 * delta
		s2_fuel_kg = max(0.0, s2_fuel_kg - burn_fuel2)
		current_mass_kg = max(current_mass_kg - burn_fuel2, 1200.0)

		if s2_fuel_kg <= 0.0 and velocity_ms < 7700.0:
			_trigger_flight_abort("SUBORBITAL TRAJECTORY: Upper stage fuel depleted before reaching orbital velocity (%.0f m/s < 7,700 m/s)." % velocity_ms)
			return

	# G-load: T / (m * g0)
	g_load = (thrust_n / (current_mass_kg * G0)) if current_mass_kg > 0.0 else 1.0
	if g_load > max_g_load_achieved:
		max_g_load_achieved = g_load

	# Aerodynamic Drag: D = 0.5 * rho * v^2 * Cd * A
	var drag_n: float = dynamic_pressure_kpa * 1000.0 * 0.28 * 4.5

	# Angle of attack: difference between vehicle pitch and flight path angle
	var alpha_deg: float = abs(pitch_deg - flight_path_angle_deg)
	if dynamic_pressure_kpa > 5.0 and alpha_deg > 14.0:
		structural_stress_pct += delta * 6.0 * (alpha_deg - 14.0)
		if structural_stress_pct >= 100.0:
			_trigger_flight_abort("AERODYNAMIC SHEAR FAILURE: High angle of attack (%.1f°) at %.1f kPa dynamic pressure tore vehicle apart." % [alpha_deg, dynamic_pressure_kpa])
			return

	# Effective Tangential Acceleration along velocity vector
	var thrust_tangential = thrust_n * cos(deg_to_rad(alpha_deg)) - drag_n
	var gamma_rad = deg_to_rad(flight_path_angle_deg)
	var accel_ms2: float = (thrust_tangential / current_mass_kg) - (G0 * sin(gamma_rad))
	velocity_ms = max(0.0, velocity_ms + accel_ms2 * delta)

	# Gravity turn rate: change of flight path angle
	if velocity_ms > 2.0:
		var normal_thrust = thrust_n * sin(deg_to_rad(pitch_deg - flight_path_angle_deg))
		var centrifugal = (velocity_ms * velocity_ms * cos(gamma_rad)) / (6371000.0 + altitude_m)
		var gamma_dot_rad = (normal_thrust / (current_mass_kg * velocity_ms)) - ((G0 * cos(gamma_rad)) / velocity_ms) + (centrifugal / velocity_ms)
		flight_path_angle_deg = clamp(flight_path_angle_deg + rad_to_deg(gamma_dot_rad) * delta, 0.0, 90.0)
	else:
		flight_path_angle_deg = 90.0

	# Altitude and downrange integration
	var v_vert = velocity_ms * sin(deg_to_rad(flight_path_angle_deg))
	var v_horiz = velocity_ms * cos(deg_to_rad(flight_path_angle_deg))
	altitude_m += v_vert * delta
	downrange_m += v_horiz * delta

	# Check terrain impact
	if altitude_m < 0.0 and flight_time_s > 3.0:
		altitude_m = 0.0
		_trigger_flight_abort("TERRAIN IMPACT: Rocket pitched below horizon and collided with ocean/terrain.")
		return

	# Natural Gravity Turn Guidance: Optimal pitch schedule comparison for scoring
	var target_pitch = 90.0 * (1.0 - sqrt(clamp(altitude_m / 140000.0, 0.0, 1.0)))
	var pitch_deviation = abs(pitch_deg - target_pitch)
	if pitch_deviation > 12.0:
		trajectory_error_pct += delta * 1.5

func _check_phase_transitions() -> void:
	# Fairing Jettison check (Above dense atmosphere: > 68,000m)
	if altitude_m > 68000.0 and not fairing_separated:
		_execute_fairing_jettison()

	# Orbital Injection check (Velocity >= 7,700 m/s, Altitude >= 160,000 m, and flight path angle near horizontal <= 8 deg)
	if velocity_ms >= 7700.0 and altitude_m >= 160000.0 and flight_path_angle_deg <= 8.0 and not orbit_achieved:
		orbit_achieved = true
		current_phase = FlightPhase.ORBITAL_INJECTION
		throttle = 0.0
		if vacuum_plume_node: vacuum_plume_node.visible = false
		_set_camera_mode(CameraMode.ORBITAL)
		print("[Launch] Orbital Insertion Achieved! Orbit: %.0f km circular parking orbit, v = %.0f m/s." % [altitude_m / 1000.0, velocity_ms])

func _execute_stage_separation() -> void:
	if stage1_separated:
		return

	stage1_separated = true
	current_phase = FlightPhase.ASCENT_STAGE2
	throttle = 1.0

	# Drop Stage 1 dry mass + fin mass from vehicle
	var tel = Helios4CampaignData.calculate_hangar_telemetry()
	var v_cfg = Helios4CampaignData.vehicle_config
	var s1_dry = v_cfg.get("stage1_dry_mass_kg", 2800.0) + v_cfg.get("stage1_fin_mass_kg", 220.0)
	current_mass_kg = max(current_mass_kg - s1_dry, 1400.0)

	# Hide Stage 1 on vehicle
	if rocket_visual and rocket_visual.stage1_node:
		rocket_visual.stage1_node.visible = false

	# Activate Detached Booster for tumbling drift
	if detached_booster and rocket:
		detached_booster.visible = true
		detached_booster.global_position = rocket.global_position
		detached_booster.global_rotation = rocket.global_rotation

	# Activate Stage 2 vacuum engine exhaust
	if vacuum_plume_node:
		vacuum_plume_node.visible = true

	print("[Launch] STAGE SEPARATION CONFIRMED! Stage 1 booster discarded. Stage 2 vacuum engine ignition.")

func _execute_fairing_jettison() -> void:
	fairing_separated = true
	var v_cfg = Helios4CampaignData.vehicle_config
	var fairing_m = v_cfg.get("fairing_mass_kg", 420.0)
	current_mass_kg = max(current_mass_kg - fairing_m, 1100.0)

	if rocket_visual:
		rocket_visual.set_fairing_open_instant(true)
		if rocket_visual.fairing_left: rocket_visual.fairing_left.visible = false
		if rocket_visual.fairing_right: rocket_visual.fairing_right.visible = false

	# Show jettisoned halves drifting away
	if jettisoned_fairing_l and jettisoned_fairing_r and rocket:
		jettisoned_fairing_l.visible = true
		jettisoned_fairing_r.visible = true
		jettisoned_fairing_l.global_position = rocket.global_position + Vector3(-1.8, 8.0, 0)
		jettisoned_fairing_r.global_position = rocket.global_position + Vector3(1.8, 8.0, 0)

	print("[Launch] FAIRING JETTISON CONFIRMED! HELIOS-4 solar sentinel probe exposed to vacuum.")

func _execute_systems_activation() -> void:
	if orbit_achieved and not systems_activated:
		systems_activated = true
		current_phase = FlightPhase.SYSTEMS_ACTIVATION
		print("[Launch] Systems Officer activated: Power online, DSN telemetry linked, early solar telemetry streaming.")

func _trigger_flight_abort(reason: String) -> void:
	current_phase = FlightPhase.FLIGHT_ABORTED
	abort_reason_text = reason
	throttle = 0.0
	if pad_steam_emitter: pad_steam_emitter.emitting = false
	if plume_smoke_emitter: plume_smoke_emitter.emitting = false
	if main_plumes_node: main_plumes_node.visible = false
	if vacuum_plume_node: vacuum_plume_node.visible = false
	if vapor_cone_node: vapor_cone_node.visible = false
	print("[Launch] *** MISSION ABORT / LAUNCH FAILURE: %s ***" % reason)
	_show_abort_modal(reason)

func _show_abort_modal(reason: String) -> void:
	var root_ui = find_child("RootUI", true, false)
	if not root_ui:
		return

	if abort_modal_panel:
		abort_modal_panel.queue_free()

	abort_modal_panel = PanelContainer.new()
	abort_modal_panel.name = "FlightAbortModal"
	abort_modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	abort_modal_panel.custom_minimum_size = Vector2(580, 280)
	abort_modal_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	abort_modal_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.12, 0.04, 0.04, 0.96)
	p_style.border_color = Color(0.95, 0.25, 0.25, 1.0)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(8)
	p_style.content_margin_left = 24
	p_style.content_margin_top = 20
	p_style.content_margin_right = 24
	p_style.content_margin_bottom = 20
	abort_modal_panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "▲ MISSION ABORT / LAUNCH FLIGHT FAILURE"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	vbox.add_child(title)

	var reason_lbl := Label.new()
	reason_lbl.text = "ABORT CAUSE:\n%s" % reason
	reason_lbl.add_theme_font_size_override("font_size", 12)
	reason_lbl.add_theme_color_override("font_color", Color(0.98, 0.75, 0.75))
	reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(reason_lbl)

	var tel_lbl := Label.new()
	tel_lbl.text = "TELEMETRY AT ABORT: Alt: %.1f km • Vel: %.0f m/s • Max-Q: %.1f kPa • Stress: %.0f%%" % [
		altitude_m / 1000.0, velocity_ms, max_q_achieved_kpa, structural_stress_pct
	]
	tel_lbl.add_theme_font_size_override("font_size", 11)
	tel_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(tel_lbl)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_END

	var btn_retry := Button.new()
	btn_retry.name = "BtnRetryLaunch"
	btn_retry.text = "↺ RETRY LAUNCH FROM PAD"
	btn_retry.add_theme_font_size_override("font_size", 11)
	var retry_style := StyleBoxFlat.new()
	retry_style.bg_color = Color(0.15, 0.45, 0.75, 0.95)
	retry_style.border_color = Color(0.35, 0.85, 1.0)
	retry_style.set_border_width_all(1)
	retry_style.set_corner_radius_all(4)
	retry_style.content_margin_left = 14
	retry_style.content_margin_right = 14
	retry_style.content_margin_top = 8
	retry_style.content_margin_bottom = 8
	btn_retry.add_theme_stylebox_override("normal", retry_style)
	btn_retry.pressed.connect(_retry_launch_from_pad)
	hbox.add_child(btn_retry)

	var btn_hangar := Button.new()
	btn_hangar.name = "BtnReturnToHangar"
	btn_hangar.text = "← RETURN TO 3D HANGAR (RE-ENGINEER)"
	btn_hangar.add_theme_font_size_override("font_size", 11)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color(0.12, 0.16, 0.22, 0.9)
	h_style.border_color = Color(0.35, 0.45, 0.6)
	h_style.set_border_width_all(1)
	h_style.set_corner_radius_all(4)
	h_style.content_margin_left = 14
	h_style.content_margin_right = 14
	h_style.content_margin_top = 8
	h_style.content_margin_bottom = 8
	btn_hangar.add_theme_stylebox_override("normal", h_style)
	btn_hangar.pressed.connect(_return_to_hangar_from_launch)
	hbox.add_child(btn_hangar)

	vbox.add_child(hbox)
	abort_modal_panel.add_child(vbox)
	root_ui.add_child(abort_modal_panel)

func _retry_launch_from_pad() -> void:
	if abort_modal_panel:
		abort_modal_panel.queue_free()
		abort_modal_panel = null
	_init_flight_parameters()
	current_phase = FlightPhase.PRE_LAUNCH_PREPARATION
	_set_camera_mode(CameraMode.PAD, true)
	if prelaunch_panel:
		prelaunch_panel.visible = true
	_refresh_prelaunch_checklist_ui()
	_update_ui()
	print("[Launch] Flight simulation reset. Standby at pad.")

func _return_to_hangar_from_launch() -> void:
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_1_HANGAR, get_tree())

func _update_3d_visuals(delta: float) -> void:
	if not rocket:
		return

	# Continuous physical motion through 3D world coordinates
	var visual_y: float = 4.0
	if altitude_m <= 1000.0:
		visual_y = 4.0 + altitude_m
	else:
		visual_y = 1004.0 + pow(altitude_m - 1000.0, 0.65) * 4.0
	var visual_x: float = downrange_m * 0.015

	rocket.position = Vector3(visual_x, visual_y, 0.0)
	rocket.rotation_degrees.z = -(90.0 - pitch_deg)

	# Detached booster tumbling physics in world coordinates
	if detached_booster and detached_booster.visible:
		detached_booster.position.y -= delta * 16.0
		detached_booster.position.x -= delta * 4.0
		detached_booster.rotation_degrees.z += delta * 18.0
		detached_booster.rotation_degrees.x += delta * 12.0

	# Jettisoned fairing halves drifting
	if jettisoned_fairing_l and jettisoned_fairing_l.visible:
		jettisoned_fairing_l.position.x -= delta * 10.0
		jettisoned_fairing_l.position.y -= delta * 8.0
		jettisoned_fairing_l.rotation_degrees.z += delta * 35.0
	if jettisoned_fairing_r and jettisoned_fairing_r.visible:
		jettisoned_fairing_r.position.x += delta * 10.0
		jettisoned_fairing_r.position.y -= delta * 8.0
		jettisoned_fairing_r.rotation_degrees.z -= delta * 35.0

	# Dynamic Sky Fade: Day coastal blue at pad -> Deep space navy/black at altitude
	var env_node = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment and env_node.environment.sky:
		var sky_mat = env_node.environment.sky.sky_material as ProceduralSkyMaterial
		if sky_mat:
			var alt_space_ratio = clamp(altitude_m / 28000.0, 0.0, 1.0)
			sky_mat.sky_top_color = lerp(Color(0.04, 0.12, 0.28), Color(0.003, 0.006, 0.015), alt_space_ratio)
			sky_mat.sky_horizon_color = lerp(Color(0.35, 0.65, 0.95), Color(0.012, 0.025, 0.05), alt_space_ratio)
			sky_mat.ground_bottom_color = lerp(Color(0.05, 0.10, 0.18), Color(0.002, 0.004, 0.008), alt_space_ratio)
			sky_mat.ground_horizon_color = lerp(Color(0.25, 0.50, 0.75), Color(0.008, 0.018, 0.035), alt_space_ratio)

	# Smooth Earth relative motion: Earth curvature stays framed under ascending rocket
	if earth_curvature:
		earth_curvature.position = rocket.position + Vector3(18.0, -165.0, -60.0)
		earth_curvature.rotation_degrees.y += delta * 0.08

	# Dynamic 3D-unprojected positioning of MaxQArcHolder right by rocket nose cone
	var max_q_holder = find_child("MaxQArcHolder", true, false) as Control
	if max_q_holder and launch_cam and rocket:
		var is_max_q_active = (current_phase == FlightPhase.MAX_Q_CORRIDOR or current_cam_mode == CameraMode.MAX_Q)
		if is_max_q_active:
			var nose_world = rocket.global_position + rocket.global_transform.basis * Vector3(0.0, 14.6, 0.0)
			if not launch_cam.is_position_behind(nose_world):
				var screen_pt = launch_cam.unproject_position(nose_world)
				var target_pos = screen_pt + Vector2(35.0, -45.0)
				target_pos.x = clamp(target_pos.x, 20.0, 1280.0 - 160.0)
				target_pos.y = clamp(target_pos.y, 65.0, 720.0 - 130.0)
				max_q_holder.global_position = target_pos
				max_q_holder.visible = true
			else:
				max_q_holder.global_position = Vector2(850.0, 135.0)
				max_q_holder.visible = true
		else:
			max_q_holder.visible = false

	var pad_light = get_node_or_null("PadFillLight") as OmniLight3D
	if pad_light:
		pad_light.visible = altitude_m < 50.0

	# Launch pad complex stays on ground at Y=0; hidden when far below in space
	if launch_complex:
		launch_complex.visible = (altitude_m < 35000.0)

	# Camera Shake during Max-Q
	if dynamic_pressure_kpa > 25.0 and launch_cam:
		var shake = (dynamic_pressure_kpa / 35.0) * 0.05
		launch_cam.h_offset = randf_range(-shake, shake)
		launch_cam.v_offset = randf_range(-shake, shake)
	elif launch_cam:
		launch_cam.h_offset = 0.0
		launch_cam.v_offset = 0.0

func _update_camera_smooth(delta: float) -> void:
	if not launch_cam or not rocket:
		return

	if current_cam_mode == CameraMode.PAD:
		# Ground observation post tracking ascending rocket
		var pad_pos = Vector3(-20.0, 6.0, 24.0)
		launch_cam.position = pad_pos
		var look_target = rocket.position + Vector3(0.0, 6.0, 0.0)
		launch_cam.look_at(look_target, Vector3.UP)
	else:
		# Tracking camera relative to vehicle
		var base_cam_pos = rocket.position + _cam_target_pos
		launch_cam.position = launch_cam.position.lerp(base_cam_pos, clamp(delta * _cam_lerp_speed, 0.0, 1.0))
		launch_cam.rotation_degrees = launch_cam.rotation_degrees.lerp(_cam_target_rot, clamp(delta * _cam_lerp_speed, 0.0, 1.0))

# ==============================================================================
# 5. UI CONTROLS & EVENT WIRING
# ==============================================================================

func _connect_controls() -> void:
	# Camera Ribbon Buttons
	_connect_cam_btn("CamBtn_Pad", CameraMode.PAD)
	_connect_cam_btn("CamBtn_Engine", CameraMode.ENGINE)
	_connect_cam_btn("CamBtn_Chase", CameraMode.CHASE)
	_connect_cam_btn("CamBtn_Wide", CameraMode.WIDE)
	_connect_cam_btn("CamBtn_MaxQ", CameraMode.MAX_Q)
	_connect_cam_btn("CamBtn_Sep", CameraMode.SEPARATION)
	_connect_cam_btn("CamBtn_Orbit", CameraMode.ORBITAL)

	# Throttle Step Buttons
	var btn_throt_up = find_child("BtnThrotUp", true, false) as Button
	if btn_throt_up: btn_throt_up.pressed.connect(func(): throttle = clamp(throttle + 0.1, 0.0, 1.0))

	var btn_throt_down = find_child("BtnThrotDown", true, false) as Button
	if btn_throt_down: btn_throt_down.pressed.connect(func(): throttle = clamp(throttle - 0.1, 0.0, 1.0))

	# Pitch Buttons (Gravity Turn steering)
	var btn_pitch_left = find_child("BtnPitchLeft", true, false) as Button
	if btn_pitch_left: btn_pitch_left.pressed.connect(func(): pitch_deg = clamp(pitch_deg - 3.0, 0.0, 90.0))

	var btn_pitch_right = find_child("BtnPitchRight", true, false) as Button
	if btn_pitch_right: btn_pitch_right.pressed.connect(func(): pitch_deg = clamp(pitch_deg + 3.0, 0.0, 90.0))

	# Stage Separation Button (SPACE)
	var btn_stage = find_child("BtnStageSeparation", true, false) as Button
	if btn_stage: btn_stage.pressed.connect(_execute_stage_separation)

	# Systems Activation Button (E)
	var btn_systems = find_child("BtnSystemsActivate", true, false) as Button
	if btn_systems: btn_systems.pressed.connect(_execute_systems_activation)

	# Proceed to Deep Space Transfer Button
	var btn_proceed_trans = find_child("ProceedToTransferBtn", true, false) as Button
	if btn_proceed_trans: btn_proceed_trans.pressed.connect(_on_proceed_to_transfer_pressed)

func _connect_cam_btn(btn_name: String, mode: CameraMode) -> void:
	var btn = find_child(btn_name, true, false) as Button
	if btn:
		btn.pressed.connect(func():
			if mode == CameraMode.MAX_Q and altitude_m < 2000.0:
				set_test_state_max_q()
			elif mode == CameraMode.SEPARATION and not stage1_separated:
				set_test_state_separation()
			elif mode == CameraMode.ORBITAL and not orbit_achieved:
				set_test_state_orbit()
			else:
				_set_camera_mode(mode)
		)

func set_test_state_max_q() -> void:
	current_phase = FlightPhase.MAX_Q_CORRIDOR
	altitude_m = 34200.0
	velocity_ms = 1480.0
	pitch_deg = 48.0
	flight_path_angle_deg = 48.0
	throttle = 0.95
	dynamic_pressure_kpa = 34.2
	flight_time_s = 68.0
	stage1_separated = false
	if prelaunch_panel: prelaunch_panel.visible = false
	if vapor_cone_node:
		vapor_cone_node.visible = true
		vapor_cone_node.scale = Vector3(1.15, 1.15, 1.15)
	if main_plumes_node: main_plumes_node.visible = true
	if vacuum_plume_node: vacuum_plume_node.visible = false
	if detached_booster: detached_booster.visible = false
	_set_camera_mode(CameraMode.MAX_Q, true)
	_update_3d_visuals(0.016)
	_update_ui()
	print("[Launch] Advanced to signature MAX-Q corridor: 34.2 km, 1480 m/s, q = 34.2 kPa")

func set_test_state_separation() -> void:
	current_phase = FlightPhase.STAGE_SEPARATION
	altitude_m = 72000.0
	velocity_ms = 3200.0
	pitch_deg = 24.0
	flight_path_angle_deg = 24.0
	throttle = 1.0
	dynamic_pressure_kpa = 0.8
	flight_time_s = 145.0
	if prelaunch_panel: prelaunch_panel.visible = false
	if vapor_cone_node: vapor_cone_node.visible = false
	if main_plumes_node: main_plumes_node.visible = false
	_execute_stage_separation()
	_set_camera_mode(CameraMode.SEPARATION, true)
	_update_3d_visuals(0.016)
	_update_ui()
	print("[Launch] Advanced to Stage 1 Separation.")

func set_test_state_orbit() -> void:
	_execute_fast_forward_orbit()
	_update_3d_visuals(0.016)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.keycode == KEY_W and event.pressed):
		throttle = clamp(throttle + 0.1, 0.0, 1.0)
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.keycode == KEY_S and event.pressed):
		throttle = clamp(throttle - 0.1, 0.0, 1.0)
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.keycode == KEY_A and event.pressed):
		pitch_deg = clamp(pitch_deg - 2.5, 0.0, 90.0)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.keycode == KEY_D and event.pressed):
		pitch_deg = clamp(pitch_deg + 2.5, 0.0, 90.0)
	elif event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		_execute_stage_separation()
	elif event is InputEventKey and event.keycode == KEY_E and event.pressed:
		_execute_systems_activation()
	elif event is InputEventKey and event.keycode == KEY_T and event.pressed:
		time_warp = 4.0 if time_warp == 1.0 else 1.0
		print("[Launch] Time warp toggled to: ", time_warp, "x")
	elif event is InputEventKey and event.keycode == KEY_P and event.pressed:
		_on_pause_countdown_pressed()
	elif event is InputEventKey and event.keycode == KEY_C and event.pressed:
		_on_start_countdown_pressed()
	elif event is InputEventKey and event.keycode == KEY_O and event.pressed:
		_execute_fast_forward_orbit()
	elif event is InputEventKey and event.pressed:
		# Number keys 1-7 for Camera selection
		match event.keycode:
			KEY_1: _set_camera_mode(CameraMode.PAD)
			KEY_2: _set_camera_mode(CameraMode.ENGINE)
			KEY_3: _set_camera_mode(CameraMode.CHASE)
			KEY_4: _set_camera_mode(CameraMode.WIDE)
			KEY_5: _set_camera_mode(CameraMode.MAX_Q)
			KEY_6: _set_camera_mode(CameraMode.SEPARATION)
			KEY_7: _set_camera_mode(CameraMode.ORBITAL)

func _execute_fast_forward_orbit() -> void:
	altitude_m = TARGET_ORBIT_ALT_M
	velocity_ms = TARGET_ORBIT_VEL_MS
	pitch_deg = 0.0
	flight_path_angle_deg = 0.0
	stage1_separated = true
	fairing_separated = true
	orbit_achieved = true
	current_phase = FlightPhase.ORBITAL_INJECTION
	if prelaunch_panel: prelaunch_panel.visible = false
	if rocket_visual:
		if rocket_visual.stage1_node: rocket_visual.stage1_node.visible = false
		rocket_visual.set_fairing_open_instant(true)
		if rocket_visual.fairing_left: rocket_visual.fairing_left.visible = false
		if rocket_visual.fairing_right: rocket_visual.fairing_right.visible = false
	if main_plumes_node: main_plumes_node.visible = false
	if vacuum_plume_node: vacuum_plume_node.visible = false
	_set_camera_mode(CameraMode.ORBITAL)
	_update_ui()
	print("[Launch] Fast-forward to Parking Orbit Injection.")

func _update_ui() -> void:
	# Update Procedural Widgets
	if navball_widget:
		navball_widget.pitch_deg = pitch_deg
	if max_q_arc_widget:
		max_q_arc_widget.dynamic_pressure_kpa = dynamic_pressure_kpa
	if altitude_tape_widget:
		altitude_tape_widget.altitude_km = altitude_m / 1000.0
	if throttle_widget:
		throttle_widget.throttle = throttle
	if staging_widget:
		staging_widget.active_stage = 2 if stage1_separated else 1
	if attitude_widget:
		attitude_widget.pitch_deg = pitch_deg
		attitude_widget.flight_path_angle = flight_path_angle_deg

	# Text labels
	_update_label("ValVelocity", "%.0f m/s" % velocity_ms)
	var mach = velocity_ms / 340.0
	_update_label("ValMach", "Mach %.2f" % mach)
	_update_label("ValGLoad", "%.2f G" % g_load)
	_update_label("ValDynamicPressure", "%.1f kPa" % dynamic_pressure_kpa)

	# Aero structural load
	var stress_lbl = find_child("ValStress", true, false) as Label
	if stress_lbl:
		if structural_stress_pct > 50.0:
			stress_lbl.text = "CRITICAL (%.0f%%)" % structural_stress_pct
			stress_lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.2))
		elif dynamic_pressure_kpa > 28.0:
			stress_lbl.text = "MAX-Q (%.0f%%)" % structural_stress_pct
			stress_lbl.add_theme_color_override("font_color", Color(0.98, 0.65, 0.15))
		else:
			stress_lbl.text = "NOMINAL (%.0f%%)" % structural_stress_pct
			stress_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55))

	# Fuel Bars
	var bar_s1 = find_child("BarFuelS1", true, false) as ProgressBar
	if bar_s1: bar_s1.value = (s1_fuel_kg / s1_fuel_capacity_kg) * 100.0

	var bar_s2 = find_child("BarFuelS2", true, false) as ProgressBar
	if bar_s2: bar_s2.value = (s2_fuel_kg / s2_fuel_capacity_kg) * 100.0

	# Timer
	var timer_lbl = find_child("ValFlightTime", true, false) as Label
	if timer_lbl:
		if current_phase == FlightPhase.READINESS_HOLD:
			timer_lbl.text = "HOLD"
		elif current_phase == FlightPhase.PRE_LAUNCH_PREPARATION:
			timer_lbl.text = "STANDBY"
		elif current_phase == FlightPhase.COUNTDOWN:
			timer_lbl.text = "T- %02d" % int(ceil(countdown_s))
		else:
			var mins = int(flight_time_s) / 60
			var secs = int(flight_time_s) % 60
			timer_lbl.text = "T+ %02d:%02d" % [mins, secs]

	# Flight Event Advisory Banner & Buttons
	var advisory_lbl = find_child("AdvisoryBanner", true, false) as Label
	var btn_stage = find_child("BtnStageSeparation", true, false) as Button
	var btn_systems = find_child("BtnSystemsActivate", true, false) as Button
	var btn_proceed = find_child("ProceedToTransferBtn", true, false) as Button

	match current_phase:
		FlightPhase.READINESS_HOLD:
			if advisory_lbl:
				advisory_lbl.text = "▲ FLIGHT CLEARANCE HOLD: Complete Engineering Readiness Review before launch."
				advisory_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
		FlightPhase.PRE_LAUNCH_PREPARATION:
			if advisory_lbl:
				advisory_lbl.text = "STANDBY: Complete pre-flight operational verifications on console to unlock countdown."
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
		FlightPhase.COUNTDOWN:
			if advisory_lbl:
				if countdown_paused:
					advisory_lbl.text = "● COUNTDOWN HOLD: Paused at T-%.1f seconds. Press RESUME to continue." % countdown_s
					advisory_lbl.add_theme_color_override("font_color", Color(0.98, 0.65, 0.15))
				else:
					advisory_lbl.text = "T-MINUS %.1f SECONDS — PAD CLEARED • STANDBY FOR BOOSTER IGNITION" % countdown_s
					advisory_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.5))
		FlightPhase.ASCENT_STAGE1:
			if advisory_lbl:
				advisory_lbl.text = "BOOSTER CLIMB: STEER GRAVITY TURN TOWARD HORIZON [A/D KEYS]"
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
		FlightPhase.MAX_Q_CORRIDOR:
			if advisory_lbl:
				advisory_lbl.text = "▲ MAX-Q TRANSONIC PRESSURE PEAK (%.1f kPa) — REDUCE THROTTLE TO 70%% TO PREVENT BREAKUP!" % dynamic_pressure_kpa
				advisory_lbl.add_theme_color_override("font_color", Color(0.98, 0.65, 0.15))
		FlightPhase.STAGE1_BURNOUT:
			if advisory_lbl:
				advisory_lbl.text = "STAGE 1 DEPLETED (MECO) — AUTHORIZE STAGE SEPARATION [SPACE / BUTTON]"
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
			if btn_stage: btn_stage.disabled = false
		FlightPhase.ASCENT_STAGE2:
			if advisory_lbl:
				var fairing_msg = " • FAIRING JETTISONED" if fairing_separated else ""
				advisory_lbl.text = "STAGE 2 VACUUM BURN: ACCELERATING TO ORBITAL VELOCITY (7,780 m/s)%s" % fairing_msg
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
			if btn_stage: btn_stage.disabled = true
		FlightPhase.ORBITAL_INJECTION:
			if advisory_lbl:
				advisory_lbl.text = "PARKING ORBIT INJECTION SUCCESSFUL! SYSTEMS OFFICER: ACTIVATE BUS TELEMETRY [E]"
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
			if btn_systems: btn_systems.disabled = false
		FlightPhase.SYSTEMS_ACTIVATION:
			if advisory_lbl:
				advisory_lbl.text = "★ ALL SYSTEMS NOMINAL: HELIOS-4 INJECTED TOWARD SUN-EARTH L1!"
				advisory_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
			if btn_proceed:
				btn_proceed.visible = true
				print("[Launch] ProceedToTransferBtn global_rect: ", btn_proceed.get_global_rect(), " center: ", btn_proceed.get_global_rect().get_center())
		FlightPhase.FLIGHT_ABORTED:
			if advisory_lbl:
				advisory_lbl.text = "▲ MISSION ABORT: %s" % abort_reason_text
				advisory_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))

func _update_label(node_name: String, text_val: String) -> void:
	var lbl = find_child(node_name, true, false) as Label
	if lbl:
		lbl.text = text_val

func _on_proceed_to_transfer_pressed() -> void:
	# Save launch telemetry
	Helios4CampaignData.launch_telemetry = {
		"flight_time_s": flight_time_s,
		"max_q_kpa": max_q_achieved_kpa,
		"max_g_load": max_g_load_achieved,
		"structural_stress_pct": structural_stress_pct,
		"trajectory_error_pct": trajectory_error_pct,
		"orbit_altitude_km": altitude_m / 1000.0,
		"orbit_velocity_ms": velocity_ms,
		"s2_fuel_remaining_kg": s2_fuel_kg,
		"is_orbital_insertion_success": true
	}
	print("[Launch] Flight successful! Advancing to Stage 3: Deep Space Transfer")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_3_TRANSFER, get_tree())
