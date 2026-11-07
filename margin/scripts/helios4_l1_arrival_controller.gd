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
var lead_time_minutes: float = 42.5

# Halo Orbit Animation
var _halo_angle: float = 0.0

func _ready() -> void:
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
	# Animate probe orbiting in a 3D halo ellipse around L1
	_halo_angle += delta * 0.4
	if probe_node and current_step >= StageStep.HOI_BURN:
		# Halo orbit is elliptical in the Y-Z plane perpendicular to Sun-Earth X-axis
		var halo_radius_y = 2.2
		var halo_radius_z = 3.6
		probe_node.position.y = sin(_halo_angle) * halo_radius_y
		probe_node.position.z = cos(_halo_angle) * halo_radius_z
		probe_node.rotation.y = -_halo_angle + deg_to_rad(90)

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
	var torus := TorusMesh.new()
	torus.inner_radius = 2.8
	torus.outer_radius = 3.2
	halo_ring.mesh = torus
	halo_ring.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.74, 0.96, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.5, 0.8)
	halo_ring.material_override = mat

func _load_step(step: StageStep) -> void:
	match step:
		StageStep.APPROACH:
			status_banner.text = "APPROACHING SUN-EARTH L1 LIBRATION POINT (1.5M km Sunward)"
			step_desc.text = "The spacecraft has arrived at the Sun-Earth L1 saddle point. Astrogator must command the Halo-Orbit Insertion (HOI) burn to capture the probe into a periodic 3D halo orbit."
			action_btn.text = "EXECUTE HALO-ORBIT INSERTION BURN (-35 kg) →"
			fuel_reserve_lbl.text = "Propellant: %.1f kg" % propellant_kg
			warning_time_lbl.text = "Advance Lead Time: Calculating..."
			
		StageStep.HOI_BURN:
			status_banner.text = "HALO-ORBIT INSERTION BURN SUCCESSFUL"
			step_desc.text = "Insertion burn complete (Δv = 280 m/s applied). Spacecraft captured into a stable 3D periodic halo orbit. Verifying stationkeeping propellant margins."
			action_btn.text = "VERIFY 3-YEAR STATIONKEEPING RESERVES →"
			
		StageStep.STATIONKEEPING_VERIFY:
			var sk_ok = (propellant_kg >= 35.0)
			status_banner.text = "● STATIONKEEPING RESERVES VALIDATED (%.1f kg REMAINING)" % propellant_kg if sk_ok else "▲ LOW STATIONKEEPING MARGIN"
			step_desc.text = "L1 halo orbits are dynamically unstable and require regular stationkeeping burns every 90 days. Reserves confirm mission duration > 3 years."
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
			step_desc.text = "High-gain X/Ka-band dish gimbaled directly toward Earth. RF Link margin +4.2 dB. Ready to package early-warning telemetry data packet."
			action_btn.text = "TRANSMIT EARLY-WARNING TELEMETRY PACKET →"
			
		StageStep.TRANSMIT_WARNING:
			status_banner.text = "★ EARLY-WARNING DATA PACKET DELIVERED TO EARTH"
			step_desc.text = "CRITICAL CME SHOCKWAVE DETECTED AT L1:\n• Solar Wind Velocity: 2,420 km/s (Severe shock)\n• Interplanetary Magnetic Field Bz: -31.5 nT (Extreme southward reconnection)\n• Proton Density: 46.2 p/cm³\n\nEARTH ADVANCE WARNING LEAD TIME: %.1f MINUTES\nEarth grid operators, satellite flight controllers, and aviation networks alerted." % lead_time_minutes
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
			warning_time_lbl.text = "Advance Warning Lead Time: %.1f Minutes" % lead_time_minutes
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
		"lead_time_minutes": lead_time_minutes,
		"solar_wind_speed_kms": 2420.0,
		"imf_bz_nt": -31.5
	}
	print("[L1Arrival] Commissioning successful! Advancing to Stage 6: Mission Debrief")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.MISSION_DEBRIEF, get_tree())
