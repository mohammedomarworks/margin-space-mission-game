class_name Helios4L1ArrivalController
extends Node3D

# ==============================================================================
# MARGIN — HELIOS-4: PHASE 5 & 6 — L1 HALO-ORBIT INSERTION & COMMISSIONING
# Location: Sun-Earth L1 region (~1.5 million km sunward from Earth)
# Halo Orbit: Periodic 3D orbit around L1 libration point
# Commissioning: Boom deployment, Faraday cup activation, live solar wind stream,
# and transmission of early-warning packet with advance lead time (~42 min).
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const SpacecraftMaterials = preload("res://margin/materials/spacecraft_materials.gd")

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

var current_step: StageStep = StageStep.APPROACH

# 3D Node References
@onready var probe_node: Node3D = %ProbeNode
@onready var halo_ring: MeshInstance3D = %HaloOrbitRing
@onready var sun_mesh: MeshInstance3D = %SunMesh
@onready var earth_mesh: MeshInstance3D = %EarthMesh

# UI References
@onready var action_btn: Button = %CommissionActionBtn
@onready var status_banner: Label = %CommissionStatusBanner
@onready var step_desc: Label = %StepDescription
@onready var telemetry_data_lbl: Label = %TelemetryDataLabel
@onready var fuel_reserve_lbl: Label = %FuelReserveLabel
@onready var warning_time_lbl: Label = %WarningTimeLabel
@onready var proceed_debrief_btn: Button = %ProceedToDebriefBtn

# Physical State
var propellant_kg: float = 240.0
var halo_stability_pct: float = 0.0
var mag_boom_deployed: bool = false
var faraday_cup_active: bool = false
var earth_comm_linked: bool = false
var warning_packet_sent: bool = false

# Physical & Trajectory Constants
const L1_DISTANCE_KM: float = 1500000.0
var shock_velocity_km_s: float = 2420.0
var lead_time_minutes: float = 0.0

# Trajectory parameters for educational 3D parametric halo orbit model
# Spatial displacement in all three axes: X (Sun-Earth axis), Y (in-plane), Z (out-of-plane)
# Note: This is an educational parametric visualization, not a numerically integrated CR3BP orbit.
const HALO_AX: float = 0.85
const HALO_AY: float = 2.4
const HALO_AZ: float = 3.4

# Halo Orbit Animation
var _halo_angle: float = 0.0

func _ready() -> void:
	lead_time_minutes = Helios4CampaignData.calculate_warning_lead_time_minutes(shock_velocity_km_s, L1_DISTANCE_KM)
	var crisis_lost = Helios4CampaignData.crisis_results.get("propellant_lost_kg", 20.0)
	var transfer_rem = Helios4CampaignData.transfer_telemetry.get("propellant_remaining_kg", 300.0)
	propellant_kg = max(20.0, transfer_rem - crisis_lost)
	
	_build_probe_visual()
	_update_halo_orbit_visual()
	
	action_btn.pressed.connect(_on_action_pressed)
	proceed_debrief_btn.pressed.connect(_on_proceed_to_debrief_pressed)
	
	_load_step(current_step)
	
	get_tree().process_frame.connect(func():
		if action_btn: print("[L1Arrival] CommissionActionBtn center: ", action_btn.get_global_rect().get_center())
		if proceed_debrief_btn: print("[L1Arrival] ProceedToDebriefBtn center: ", proceed_debrief_btn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	# Animate probe along educational 3D parametric halo orbit
	_halo_angle += delta * 0.4
	if probe_node and current_step >= StageStep.HOI_BURN:
		# Parametric 3D halo model with non-zero spatial variation across X, Y, and Z
		var pos = Vector3(
			-HALO_AX * cos(2.0 * _halo_angle),
			HALO_AY * sin(_halo_angle),
			HALO_AZ * cos(_halo_angle)
		)
		probe_node.position = pos
		
		# Align attitude along velocity tangent
		var tan_vel = Vector3(
			2.0 * HALO_AX * sin(2.0 * _halo_angle),
			HALO_AY * cos(_halo_angle),
			-HALO_AZ * sin(_halo_angle)
		)
		if tan_vel.length_squared() > 0.001:
			probe_node.look_at(probe_node.position + tan_vel.normalized(), Vector3.UP)

func _build_probe_visual() -> void:
	if not probe_node:
		return
	for c in probe_node.get_children():
		c.queue_free()
		
	# Bus
	var bus := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(1.2, 1.2, 1.2)
	bus.mesh = b_box
	bus.material_override = SpacecraftMaterials.get_mat("gold_mli")
	probe_node.add_child(bus)
	
	# Solar wings
	for dir in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(2.0, 0.85, 0.04)
		panel.mesh = p_box
		panel.position = Vector3(0.0, 0.0, dir * 1.8)
		panel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		panel.material_override = SpacecraftMaterials.get_mat("solar_cells")
		probe_node.add_child(panel)
		
	# High gain dish pointing toward Earth (+X direction)
	var dish := MeshInstance3D.new()
	var d_sph := SphereMesh.new()
	d_sph.radius = 0.6
	d_sph.height = 0.3
	dish.mesh = d_sph
	dish.position = Vector3(0.65, 0.6, 0.0)
	dish.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	dish.material_override = SpacecraftMaterials.get_mat("dish_reflector")
	probe_node.add_child(dish)

func _update_halo_orbit_visual() -> void:
	if not halo_ring:
		return
	halo_ring.mesh = _generate_halo_tube_mesh(HALO_AX, HALO_AY, HALO_AZ, 0.06, 64, 8)
	halo_ring.position = Vector3.ZERO
	halo_ring.rotation_degrees = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.74, 0.96, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.58, 0.92)
	mat.emission_energy_multiplier = 1.5
	halo_ring.material_override = mat

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

func _load_step(step: StageStep) -> void:
	match step:
		StageStep.APPROACH:
			status_banner.text = "APPROACHING SUN-EARTH L1 REGION (1.5M km Sunward)"
			step_desc.text = "The spacecraft has arrived near the Sun-Earth L1 region (1,500,000 km sunward). Astrogator must command the Halo-Orbit Insertion (HOI) burn to capture the probe into a closed 3D halo orbit path (educational parametric model; not full CR3BP propagation)."
			action_btn.text = "EXECUTE HALO-ORBIT INSERTION BURN (-35 kg) →"
			fuel_reserve_lbl.text = "Propellant: %.1f kg" % propellant_kg
			warning_time_lbl.text = "Early Warning: %.2f min (d: 1.5M km | v: %.0f km/s)" % [lead_time_minutes, shock_velocity_km_s]
			
		StageStep.HOI_BURN:
			status_banner.text = "HALO-ORBIT INSERTION BURN SUCCESSFUL"
			step_desc.text = "Insertion burn complete (Δv = 280 m/s applied). Spacecraft captured into educational 3D parametric halo orbit (non-zero spatial motion across X, Y, and Z axes). Verifying stationkeeping propellant margins."
			action_btn.text = "VERIFY STATIONKEEPING RESERVES (EDUCATIONAL THRESHOLD) →"
			
		StageStep.STATIONKEEPING_VERIFY:
			var sk_ok = (propellant_kg >= 35.0)
			status_banner.text = "● STATIONKEEPING RESERVE THRESHOLD VERIFIED (%.1f kg REMAINING)" % propellant_kg if sk_ok else "▲ BELOW ILLUSTRATIVE STATIONKEEPING THRESHOLD"
			step_desc.text = "Collinear Lagrange points are dynamically unstable saddle equilibria requiring active stationkeeping maneuvers (~15–30 m/s/yr). Remaining propellant satisfies the > 35 kg illustrative reserve threshold (educational game model; actual operational lifetimes depend on tracking uncertainty and navigation dispersion rather than a guaranteed duration)."
			action_btn.text = "DEPLOY 4m MAGNETOMETER BOOM SUNWARD →"
			
		StageStep.BOOM_DEPLOY:
			status_banner.text = "MAGNETOMETER BOOM EXTENDED (ISOLATED FROM BUS DIPOLE)"
			step_desc.text = "Triaxial fluxgate magnetometer boom deployed 4 meters away from spacecraft electronics to measure pristine interplanetary magnetic field (IMF) vectors."
			action_btn.text = "ACTIVATE FARADAY CUP PLASMA ANALYZER →"
			
		StageStep.FARADAY_ACTIVATE:
			status_banner.text = "FARADAY CUP ACTIVE: SOLAR WIND PLASMA MEASUREMENTS ONLINE"
			step_desc.text = "Faraday Cup is capturing solar wind proton fluxes. Streaming bulk velocity (v_sw), proton density (n_p), and thermal temperature."
			action_btn.text = "LOCK HIGH-GAIN DISH ON EARTH DSN →"
			
		StageStep.EARTH_LINK:
			status_banner.text = "★ DEEP SPACE NETWORK CARRIER LOCKED (GOLDSTONE & MADRID)"
			step_desc.text = "High-gain X/Ka-band dish gimbaled directly toward Earth. RF Link margin +4.2 dB. Ready to transmit early-warning telemetry packet (Calculated lead time: %.2f min at %.0f km/s across 1,500,000 km distance)." % [lead_time_minutes, shock_velocity_km_s]
			action_btn.text = "TRANSMIT EARLY-WARNING TELEMETRY PACKET →"
			
		StageStep.TRANSMIT_WARNING:
			status_banner.text = "★ EARLY-WARNING DATA PACKET DELIVERED TO EARTH"
			step_desc.text = "Following successful commissioning, the anticipated coronal mass ejection from Active Region AR-4890 has erupted from the Sun and its interplanetary shock front has reached Sun-Earth L1:\n• CME Shock Velocity: %.0f km/s (Severe shock)\n• L1-to-Earth Distance: %.1f Million km (1,500,000 km)\n• Authoritative Early-Warning Lead Time: %.2f Minutes (t = d / v / 60)\n• Interplanetary Magnetic Field Bz: -31.5 nT (Extreme southward reconnection)\n• Proton Density: 46.2 p/cm³\n\nEARTH ADVANCE WARNING DELIVERED: %.2f MINUTES\nEarth grid operators, satellite flight controllers, and aviation networks alerted." % [
				shock_velocity_km_s,
				L1_DISTANCE_KM / 1000000.0,
				lead_time_minutes,
				lead_time_minutes
			]
			warning_time_lbl.text = "Advance Lead Time Delivered: %.2f min (d: 1.5M km | v: %.0f km/s)" % [lead_time_minutes, shock_velocity_km_s]
			action_btn.visible = false
			proceed_debrief_btn.visible = true
			get_tree().process_frame.connect(func():
				print("[L1Arrival] ProceedToDebriefBtn center: ", proceed_debrief_btn.get_global_rect().get_center())
			, CONNECT_ONE_SHOT)

func _on_action_pressed() -> void:
	match current_step:
		StageStep.APPROACH:
			propellant_kg = max(5.0, propellant_kg - 35.0)
			halo_stability_pct = 99.4
			fuel_reserve_lbl.text = "Propellant: %.1f kg" % propellant_kg
			current_step = StageStep.HOI_BURN
			_load_step(current_step)
			
		StageStep.HOI_BURN:
			current_step = StageStep.STATIONKEEPING_VERIFY
			_load_step(current_step)
			
		StageStep.STATIONKEEPING_VERIFY:
			mag_boom_deployed = true
			current_step = StageStep.BOOM_DEPLOY
			_load_step(current_step)
			
		StageStep.BOOM_DEPLOY:
			faraday_cup_active = true
			current_step = StageStep.FARADAY_ACTIVATE
			_load_step(current_step)
			
		StageStep.FARADAY_ACTIVATE:
			earth_comm_linked = true
			current_step = StageStep.EARTH_LINK
			_load_step(current_step)
			
		StageStep.EARTH_LINK:
			warning_packet_sent = true
			warning_time_lbl.text = "Advance Warning Lead Time: %.2f Minutes" % lead_time_minutes
			current_step = StageStep.TRANSMIT_WARNING
			_load_step(current_step)

func _on_proceed_to_debrief_pressed() -> void:
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
		"imf_bz_nt": -31.5
	}
	print("[L1Arrival] Commissioning successful! Advancing to Stage 6: Mission Debrief")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.MISSION_DEBRIEF, get_tree())
