class_name Helios4DeepSpaceController
extends Node3D

# ==============================================================================
# MARGIN — HELIOS-4: PHASE 3 — DEEP SPACE TRANSFER
# 1.5 Million Kilometers Sunward to Sun-Earth L1
# - Sun and Earth 3D positioning (~1.5M km sunward, NOT midpoint)
# - Transfer trajectory arc & Mid-Course Correction (MCC) burn
# - Solar array sun-tracking orientation and DSN link budget
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const SpacecraftMaterials = preload("res://margin/materials/spacecraft_materials.gd")

@onready var probe_node: Node3D = %ProbeNode
@onready var sun_mesh: MeshInstance3D = %SunMesh
@onready var earth_mesh: MeshInstance3D = %EarthMesh
@onready var mcc_btn: Button = %ExecuteMCCBtn
@onready var sun_align_btn: Button = %AlignSolarBtn
@onready var crisis_btn: Button = %EnterCrisisBtn

# Cruise Simulation State
var distance_traveled_km: float = 120000.0 # 0 to 1,500,000 km
const TARGET_L1_DISTANCE_KM: float = 1500000.0
var cruise_velocity_kms: float = 3.8 # km/s
var cruise_day: float = 12.0

var solar_alignment_deg: float = 14.0 # Angle off normal
var dsn_signal_db: float = 28.5
var mcc_completed: bool = false
var trajectory_margin_pct: float = 98.2

var probe_propellant_kg: float = 320.0

func _ready() -> void:
	var p_cfg = Helios4CampaignData.probe_config
	if not p_cfg.is_empty():
		probe_propellant_kg = p_cfg.get("propellant_mass_kg", 320.0)
		
	_build_probe_visual()
	_connect_signals()
	_update_ui()
	
	if crisis_btn:
		crisis_btn.visible = true
	get_tree().process_frame.connect(func():
		if crisis_btn: print("[DeepSpace] EnterCrisisBtn global_rect: ", crisis_btn.get_global_rect(), " center: ", crisis_btn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	if distance_traveled_km < 820000.0:
		distance_traveled_km += cruise_velocity_kms * delta * 4500.0
		cruise_day += delta * 1.5
		_update_probe_and_planets()
		_update_ui()
	else:
		# Cruise reaches crisis zone (solar storm alert approaching L1 transfer midpoint)
		if crisis_btn:
			crisis_btn.visible = true

func _update_probe_and_planets() -> void:
	var progress = clamp(distance_traveled_km / TARGET_L1_DISTANCE_KM, 0.0, 1.0)
	
	# Earth recedes in the background (pointing away from Sun)
	if earth_mesh:
		earth_mesh.position.z = -15.0 - progress * 35.0
		earth_mesh.position.x = 10.0 + progress * 8.0
		var earth_scale = max(0.2, 1.0 - progress * 0.7)
		earth_mesh.scale = Vector3.ONE * earth_scale
		
	# Probe gentle slow rotation
	if probe_node:
		probe_node.rotation.y += 0.05 * get_process_delta_time()

func _build_probe_visual() -> void:
	if not probe_node:
		return
	for c in probe_node.get_children():
		c.queue_free()
		
	# Spacecraft gold MLI bus
	var bus := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(1.2, 1.2, 1.2)
	bus.mesh = b_box
	bus.material_override = SpacecraftMaterials.get_mat("gold_mli")
	probe_node.add_child(bus)
	
	# Solar wings left and right
	for dir in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(1.8, 0.8, 0.04)
		panel.mesh = p_box
		panel.position = Vector3(dir * 1.6, 0.0, 0.0)
		panel.material_override = SpacecraftMaterials.get_mat("solar_cells")
		probe_node.add_child(panel)
		
	# High gain dish pointing back at Earth
	var dish := MeshInstance3D.new()
	var d_sph := SphereMesh.new()
	d_sph.radius = 0.55
	d_sph.height = 0.28
	dish.mesh = d_sph
	dish.position = Vector3(0.0, 0.8, 0.4)
	dish.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	dish.material_override = SpacecraftMaterials.get_mat("dish_reflector")
	probe_node.add_child(dish)
	
	# Long Magnetometer Boom pointing Sunward
	var boom := MeshInstance3D.new()
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 0.025
	b_cyl.bottom_radius = 0.03
	b_cyl.height = 2.4
	boom.mesh = b_cyl
	boom.position = Vector3(0.0, 0.6, -1.2)
	boom.rotation_degrees = Vector3(65.0, 0.0, 0.0)
	boom.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
	probe_node.add_child(boom)
	
	# Faraday Cup Sensor
	var cup := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 0.1
	c_cyl.bottom_radius = 0.06
	c_cyl.height = 0.2
	cup.mesh = c_cyl
	cup.position = Vector3(0.35, 0.7, -0.6)
	cup.rotation_degrees = Vector3(45.0, 0.0, 0.0)
	cup.material_override = SpacecraftMaterials.get_mat("sensor_lens")
	probe_node.add_child(cup)

func _connect_signals() -> void:
	if mcc_btn:
		mcc_btn.pressed.connect(_on_execute_mcc_pressed)
	if sun_align_btn:
		sun_align_btn.pressed.connect(_on_align_solar_pressed)
	if crisis_btn:
		crisis_btn.pressed.connect(_on_enter_crisis_pressed)

func _on_align_solar_pressed() -> void:
	solar_alignment_deg = 0.5 # Perfect normal to Sun
	_update_ui()
	print("[DeepSpace] Systems Officer aligned solar arrays sunward: 100% illumination efficiency.")

func _on_execute_mcc_pressed() -> void:
	if not mcc_completed and probe_propellant_kg >= 18.0:
		mcc_completed = true
		probe_propellant_kg -= 18.0 # MCC-1 burn: ~25 m/s delta-V
		trajectory_margin_pct = 99.8
		mcc_btn.disabled = true
		mcc_btn.text = "MCC-1 BURN EXECUTED (-18 kg)"
		_update_ui()
		print("[DeepSpace] Astrogator executed MCC-1 mid-course correction burn. Trajectory locked to L1 Halo injection corridor.")

func _on_enter_crisis_pressed() -> void:
	Helios4CampaignData.transfer_telemetry = {
		"distance_km": distance_traveled_km,
		"cruise_days": cruise_day,
		"mcc_completed": mcc_completed,
		"solar_alignment_deg": solar_alignment_deg,
		"propellant_remaining_kg": probe_propellant_kg
	}
	print("[DeepSpace] Approaching deep space weather anomaly. Transitioning to Phase 4: Crisis")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_4_CRISIS, get_tree())

func _update_ui() -> void:
	_update_label("ValDistance", "%.0f km / 1,500,000 km" % distance_traveled_km)
	_update_label("ValCruiseDay", "Day %.1f" % cruise_day)
	_update_label("ValPropRemaining", "%.1f kg" % probe_propellant_kg)
	_update_label("ValTrajAccuracy", "%.1f%%" % trajectory_margin_pct)
	
	var solar_eff = cos(deg_to_rad(solar_alignment_deg)) * 100.0
	_update_label("ValSolarEff", "%.0f%% (Angle: %.1f°)" % [solar_eff, solar_alignment_deg])
	
	var dist_pct = clamp((distance_traveled_km / TARGET_L1_DISTANCE_KM) * 100.0, 0.0, 100.0)
	var bar_dist = find_child("BarProgress", true, false) as ProgressBar
	if bar_dist:
		bar_dist.value = dist_pct

func _update_label(node_name: String, text_val: String) -> void:
	var lbl = find_child(node_name, true, false) as Label
	if lbl:
		lbl.text = text_val
