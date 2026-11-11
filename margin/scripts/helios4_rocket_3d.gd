class_name Helios4Rocket3D
extends Node3D

# ==============================================================================
# MARGIN: HELIOS-4 HIGH-FIDELITY 3D LAUNCH VEHICLE, PROBE & ASSEMBLY HANGAR
# Faithfully crafted to reproduce the visual reference: 01_helios4_hangar.png
#
# Key Architectural Features:
# 1. Industrial Spacecraft Assembly Hangar:
#    - Concrete floor with octagonal yellow/black hazard warning perimeter.
#    - Central circular steel blast turntable deck with hold-down clamps & vapor vents.
#    - Towering corrugated steel walls with structural I-beam columns & cross-bracing.
#    - Dual vertical service gantry towers (industrial yellow lattice, 4 platform levels,
#      safety railings, catwalks, ladders, amber work floodlights).
#    - Overhead crane girder spanning across ceiling trusses with trolley.
#    - 3 articulated robotic maintenance arms with active welding sparks & flickering torches:
#      * Arm 1: Overhead crane arm welding upper fairing/interstage from above.
#      * Arm 2: Mid-left gantry platform arm welding booster core tank.
#      * Arm 3: Mid-right gantry platform arm inspecting booster flank.
#    - Subtle atmospheric vapor / steam rising from launch deck vents.
#
# 2. Detailed HELIOS-4 Launch Vehicle:
#    - Stage 1: Central structural core flanked by 4 massive quad strap-on booster tanks
#      in brushed machined steel with circumferential weld ribs and vertical conduits;
#      4-bell massive rocket engine cluster with copper throats and inconel bells;
#      4x deployable titanium aerodynamic grid fins.
#    - Stage 2: Heavy open-lattice tubular interstage truss with X cross-bracing,
#      revealing the vacuum engine nozzle inside; upper propellant tank with 4 helium COPVs.
#    - Stage 3 / Probe: Bifold aerodynamic split fairings hinged open to sides,
#      revealing the HELIOS-4 solar sentinel probe clad in brilliant gold MLI foil,
#      parabolic high-gain dish on 2-axis gimbal, deployable GaAs solar array wings,
#      triaxial magnetometer boom, and Faraday cup plasma analyzer.
#
# 3. Reference-matching 3D Holographic Callouts:
#    - Floating cyan wireframe corner-bracket boxes with mini 3D preview models:
#      * Left: Mini 3D Quad Engine Cluster preview + cyan leader lines to rocket base.
#      * Right: Mini 3D Solar Array preview + cyan leader lines to probe solar wings.
#    - Subsystem interactive highlight switching (cyan -> amber) when selected.
# ==============================================================================

const SpacecraftMaterials = preload("res://margin/materials/spacecraft_materials.gd")

# State
@export var include_hangar: bool = true
@export var include_callouts: bool = true
@export var initial_fairing_open: bool = true
var fairing_open: bool = true
var active_highlight: String = ""

# Node References
var hangar_facility_node: Node3D = null
var stage1_node: Node3D = null
var stage2_node: Node3D = null
var probe_node: Node3D = null
var fairing_left: Node3D = null
var fairing_right: Node3D = null
var solar_wing_left: Node3D = null
var solar_wing_right: Node3D = null
var mag_boom: Node3D = null
var engine_cluster_node: Node3D = null
var grid_fins_node: Node3D = null

# Dynamic FX References
var weld_light_1: OmniLight3D = null
var weld_light_2: OmniLight3D = null
var weld_light_3: OmniLight3D = null
var spark_emitter_1: CPUParticles3D = null
var spark_emitter_2: CPUParticles3D = null
var spark_emitter_3: CPUParticles3D = null

# Hologram Callout Brackets & Mini Preview Models
var callouts: Dictionary = {}
var mini_engine_preview: Node3D = null
var mini_solar_preview: Node3D = null

func _ready() -> void:
	rebuild_vehicle()

func _process(delta: float) -> void:
	# Realistic welding arc flicker
	if weld_light_1:
		var flicker = randf_range(0.4, 2.0)
		weld_light_1.light_energy = flicker if randf() > 0.08 else 0.0
	if weld_light_2:
		var flicker2 = randf_range(0.3, 1.8)
		weld_light_2.light_energy = flicker2 if randf() > 0.10 else 0.0
	if weld_light_3:
		var flicker3 = randf_range(0.2, 1.5)
		weld_light_3.light_energy = flicker3 if randf() > 0.12 else 0.0

	# Slowly rotate floating 3D holographic previews
	if mini_engine_preview:
		mini_engine_preview.rotate_y(delta * 0.45)
	if mini_solar_preview:
		mini_solar_preview.rotate_y(delta * 0.40)

func rebuild_vehicle() -> void:
	for child in get_children():
		child.queue_free()
	callouts.clear()

	# --- 1. INDUSTRIAL ASSEMBLY HANGAR & GANTRIES ---
	if include_hangar:
		hangar_facility_node = Node3D.new()
		hangar_facility_node.name = "HangarFacility"
		add_child(hangar_facility_node)
		_build_hangar_facility(hangar_facility_node)

	# --- 2. STAGE 1: HEAVY QUAD-BOOSTER CORE ---
	stage1_node = Node3D.new()
	stage1_node.name = "Stage1_Booster"
	add_child(stage1_node)
	_build_stage1(stage1_node)

	# --- 3. STAGE 2: VACUUM UPPER STAGE & INTERSTAGE TRUSS ---
	stage2_node = Node3D.new()
	stage2_node.name = "Stage2_Upper"
	stage2_node.position = Vector3(0.0, 6.4, 0.0)
	add_child(stage2_node)
	_build_stage2(stage2_node)

	# --- 4. STAGE 3: HELIOS-4 SOLAR PROBE ---
	probe_node = Node3D.new()
	probe_node.name = "Stage3_Probe"
	probe_node.position = Vector3(0.0, 10.6, 0.0)
	add_child(probe_node)
	_build_probe(probe_node)

	# --- 5. BIFOLD SPLIT FAIRINGS ---
	_build_fairings()
	set_fairing_open_instant(initial_fairing_open)

	# --- 6. FLOATING 3D HOLOGRAPHIC CALLOUTS ---
	if include_callouts:
		_build_holographic_callouts()

# ==============================================================================
# HANGAR FACILITY, GANTRIES & ROBOTIC ARMS (Matching Reference 01)
# ==============================================================================

func _build_hangar_facility(parent: Node3D) -> void:
	# --- 1. FLOOR & BLAST TURNTABLE DECK ---
	_build_floor_and_turntable(parent)

	# --- 2. MASSIVE REAR ARCHITECTURE (WALL, BLAST DOORS, CONTROL ROOM, CATWALKS) ---
	_build_rear_hangar_architecture(parent)

	# --- 3. SIDE RUNWAYS, WALLS & EQUIPMENT ALCOVES ---
	_build_side_and_front_architecture(parent)

	# --- 4. CEILING SPACE-FRAME TRUSSES & OVERHEAD BRIDGE CRANE ---
	_build_ceiling_trusses_and_crane(parent)

	# --- 5. DUAL VERTICAL SERVICE GANTRIES (FLANKING VEHICLE) ---
	_build_gantry_tower(parent, -5.0, "LeftGantry")
	_build_gantry_tower(parent, 5.0, "RightGantry")

	# --- 6. ARTICULATED ROBOTIC WELDING ARMS WITH SPARKS ---
	_build_robotic_welding_arms(parent)

	# --- 7. ATMOSPHERIC BASE STEAM / VENTS ---
	_build_base_steam(parent)

# ==============================================================================
# 1. FLOOR & LAUNCH TURNTABLE DECK
# ==============================================================================

func _build_floor_and_turntable(parent: Node3D) -> void:
	var mat_floor := SpacecraftMaterials.get_mat("hangar_floor_concrete")
	var mat_deck := SpacecraftMaterials.get_mat("hangar_blast_deck")
	var mat_steel := SpacecraftMaterials.get_mat("gantry_dark_steel")
	var mat_gantry := SpacecraftMaterials.get_mat("gantry_yellow")
	var mat_hz_y := SpacecraftMaterials.get_mat("hazard_stripe_yellow")
	var mat_hz_b := SpacecraftMaterials.get_mat("hazard_stripe_black")
	var mat_white := SpacecraftMaterials.get_mat("hazard_line_white")
	var mat_grate := SpacecraftMaterials.get_mat("drain_grate")

	# Main Concrete Floor Slab (Enormous 80m x 80m hall)
	var floor_mesh := MeshInstance3D.new()
	var f_box := BoxMesh.new()
	f_box.size = Vector3(80.0, 0.6, 80.0)
	floor_mesh.mesh = f_box
	floor_mesh.position = Vector3(0.0, -0.3, 0.0)
	floor_mesh.material_override = mat_floor
	parent.add_child(floor_mesh)

	# Modular Concrete Expansion Joint Lines (Grid seams every 10m)
	for x_seam in [-30.0, -20.0, -10.0, 10.0, 20.0, 30.0]:
		var seam := MeshInstance3D.new()
		var s_box := BoxMesh.new()
		s_box.size = Vector3(0.06, 0.02, 70.0)
		seam.mesh = s_box
		seam.position = Vector3(x_seam, 0.01, 0.0)
		seam.material_override = mat_steel
		parent.add_child(seam)

	for z_seam in [-20.0, -10.0, 10.0, 20.0]:
		var seam_z := MeshInstance3D.new()
		var sz_box := BoxMesh.new()
		sz_box.size = Vector3(70.0, 0.02, 0.06)
		seam_z.mesh = sz_box
		seam_z.position = Vector3(0.0, 0.01, z_seam)
		seam_z.material_override = mat_steel
		parent.add_child(seam_z)

	# Painted Yellow Central Taxi / Alignment Lines (Leading from rear blast door to turntable)
	var taxi_line := MeshInstance3D.new()
	var tl_box := BoxMesh.new()
	tl_box.size = Vector3(0.35, 0.02, 24.0)
	taxi_line.mesh = tl_box
	taxi_line.position = Vector3(0.0, 0.02, -14.0)
	taxi_line.material_override = mat_gantry
	parent.add_child(taxi_line)

	# Flanking White Equipment Clearance Lines
	for side in [-7.5, 7.5]:
		var guide := MeshInstance3D.new()
		var g_box := BoxMesh.new()
		g_box.size = Vector3(0.18, 0.02, 32.0)
		guide.mesh = g_box
		guide.position = Vector3(side, 0.02, -10.0)
		guide.material_override = mat_white
		parent.add_child(guide)

	# Longitudinal Recessed Cable & Drainage Trenches with Grates
	for side_x in [-10.5, 10.5]:
		var trench := MeshInstance3D.new()
		var tr_box := BoxMesh.new()
		tr_box.size = Vector3(0.9, 0.03, 50.0)
		trench.mesh = tr_box
		trench.position = Vector3(side_x, 0.015, -2.0)
		trench.material_override = mat_grate
		parent.add_child(trench)

		# Yellow border curb along trench
		for curb_x in [side_x - 0.55, side_x + 0.55]:
			var curb := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(0.12, 0.025, 50.0)
			curb.mesh = c_box
			curb.position = Vector3(curb_x, 0.02, -2.0)
			curb.material_override = mat_gantry
			parent.add_child(curb)

	# --- B. Circular Blast Turntable Deck (Multi-Tiered Aerospace Platform) ---
	var base_ring := MeshInstance3D.new()
	var br_cyl := CylinderMesh.new()
	br_cyl.top_radius = 4.4
	br_cyl.bottom_radius = 4.9
	br_cyl.height = 0.3
	br_cyl.radial_segments = 36
	base_ring.mesh = br_cyl
	base_ring.position = Vector3(0.0, 0.15, 0.0)
	base_ring.material_override = mat_steel
	parent.add_child(base_ring)

	var turntable := MeshInstance3D.new()
	var t_cyl := CylinderMesh.new()
	t_cyl.top_radius = 3.9
	t_cyl.bottom_radius = 4.3
	t_cyl.height = 0.35
	t_cyl.radial_segments = 36
	turntable.mesh = t_cyl
	turntable.position = Vector3(0.0, 0.35, 0.0)
	turntable.material_override = mat_deck
	parent.add_child(turntable)

	# Inner Blast Deflector Vent Pit
	var vent_ring := MeshInstance3D.new()
	var vr_cyl := CylinderMesh.new()
	vr_cyl.top_radius = 2.4
	vr_cyl.bottom_radius = 2.65
	vr_cyl.height = 0.55
	vent_ring.mesh = vr_cyl
	vent_ring.position = Vector3(0.0, 0.38, 0.0)
	vent_ring.material_override = mat_steel
	parent.add_child(vent_ring)

	# 4x Heavy Mechanical Hold-Down Clamps on Launch Table
	for angle in [45.0, 135.0, 225.0, 315.0]:
		var rad = deg_to_rad(angle)
		var clamp_root := Node3D.new()
		clamp_root.position = Vector3(cos(rad) * 2.35, 0.55, sin(rad) * 2.35)
		clamp_root.rotation.y = -rad
		parent.add_child(clamp_root)

		# Clamp base block
		var cb := MeshInstance3D.new()
		var cb_box := BoxMesh.new()
		cb_box.size = Vector3(0.55, 0.85, 0.65)
		cb.mesh = cb_box
		cb.material_override = mat_gantry
		clamp_root.add_child(cb)

		# Articulated hold-down jaw arm
		var jaw := MeshInstance3D.new()
		var j_box := BoxMesh.new()
		j_box.size = Vector3(0.35, 0.35, 0.45)
		jaw.mesh = j_box
		jaw.position = Vector3(0.0, 0.45, 0.2)
		jaw.material_override = mat_steel
		clamp_root.add_child(jaw)

	# Hazard stripe ring segments
	for i in range(16):
		var a = i * (360.0 / 16.0)
		var rad = deg_to_rad(a)
		var stripe := MeshInstance3D.new()
		var s_box := BoxMesh.new()
		s_box.size = Vector3(1.3, 0.02, 0.38)
		stripe.mesh = s_box
		stripe.position = Vector3(cos(rad) * 4.6, 0.02, sin(rad) * 4.6)
		stripe.rotation.y = -rad
		stripe.material_override = mat_hz_y if (i % 2 == 0) else mat_hz_b
		parent.add_child(stripe)

# ==============================================================================
# 2. MASSIVE REAR ARCHITECTURE (Wall, Blast Doors, Control Room, Catwalks)
# ==============================================================================

func _build_rear_hangar_architecture(parent: Node3D) -> void:
	var mat_wall := SpacecraftMaterials.get_mat("hangar_wall_dark")
	var mat_doors := SpacecraftMaterials.get_mat("hangar_door_steel")
	var mat_steel := SpacecraftMaterials.get_mat("hangar_truss_steel")
	var mat_gantry := SpacecraftMaterials.get_mat("gantry_yellow")
	var mat_glass := SpacecraftMaterials.get_mat("hangar_control_room_glass")
	var mat_duct := SpacecraftMaterials.get_mat("vent_duct_galvanized")
	var mat_cryo := SpacecraftMaterials.get_mat("pipe_cryo_insulation")
	var mat_grate := SpacecraftMaterials.get_mat("hangar_catwalk_grate")
	var mat_lamp := SpacecraftMaterials.get_mat("worklight_fixture")

	var z_rear = -28.0

	# --- A. Enormous Structural Rear Wall (72m wide x 36m high) ---
	var wall := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(72.0, 36.0, 1.2)
	wall.mesh = w_box
	wall.position = Vector3(0.0, 18.0, z_rear)
	wall.material_override = mat_wall
	parent.add_child(wall)

	# Heavy Steel I-Beam Structural Columns (Every 8m along rear wall)
	for x_col in [-28.0, -20.0, -12.0, -4.0, 4.0, 12.0, 20.0, 28.0]:
		var col := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(0.85, 36.0, 1.1)
		col.mesh = c_box
		col.position = Vector3(x_col, 18.0, z_rear + 0.6)
		col.material_override = mat_steel
		parent.add_child(col)

		# Horizontal cross-tie girders
		for y_tie in [8.0, 16.0, 24.0, 32.0]:
			var tie := MeshInstance3D.new()
			var t_box := BoxMesh.new()
			t_box.size = Vector3(8.0, 0.4, 0.6)
			tie.mesh = t_box
			tie.position = Vector3(x_col, y_tie, z_rear + 0.6)
			tie.material_override = mat_steel
			parent.add_child(tie)

	# --- B. Segmented Giant Hangar Blast Doors (22m wide x 16m high) ---
	var z_door = z_rear + 0.75
	# 4 Vertical sliding blast door slabs
	for i in range(4):
		var dx = (i - 1.5) * 5.2
		var door_slab := MeshInstance3D.new()
		var ds_box := BoxMesh.new()
		ds_box.size = Vector3(5.1, 16.0, 0.4)
		door_slab.mesh = ds_box
		door_slab.position = Vector3(dx, 8.0, z_door)
		door_slab.material_override = mat_doors
		parent.add_child(door_slab)

		# Vertical reinforcing structural stiffener ribs on each door
		for rib_off in [-1.6, 0.0, 1.6]:
			var rib := MeshInstance3D.new()
			var r_box := BoxMesh.new()
			r_box.size = Vector3(0.2, 16.0, 0.25)
			rib.mesh = r_box
			rib.position = Vector3(dx + rib_off, 8.0, z_door + 0.22)
			rib.material_override = mat_steel
			parent.add_child(rib)

	# Top Overhead Door Header Track Beam with Hazard Stripes
	var header := MeshInstance3D.new()
	var h_box := BoxMesh.new()
	h_box.size = Vector3(23.0, 1.2, 0.8)
	header.mesh = h_box
	header.position = Vector3(0.0, 16.6, z_door + 0.3)
	header.material_override = mat_gantry
	parent.add_child(header)

	# Flashing Amber/Red Door Frame Warning Beacons
	for bx in [-11.2, 11.2]:
		var beacon := MeshInstance3D.new()
		var b_cyl := CylinderMesh.new()
		b_cyl.top_radius = 0.18
		b_cyl.bottom_radius = 0.18
		b_cyl.height = 0.45
		beacon.mesh = b_cyl
		beacon.position = Vector3(bx, 16.8, z_door + 0.7)
		beacon.material_override = mat_lamp
		parent.add_child(beacon)

	# --- C. Elevated Control Room & Observation Gallery (Above Blast Doors) ---
	var z_gallery = z_rear + 1.8
	var gallery_body := MeshInstance3D.new()
	var gb_box := BoxMesh.new()
	gb_box.size = Vector3(24.0, 4.8, 2.6)
	gallery_body.mesh = gb_box
	gallery_body.position = Vector3(0.0, 20.0, z_gallery)
	gallery_body.material_override = mat_wall
	parent.add_child(gallery_body)

	# Cantilevered angled observation windows (8 panes of glowing glass)
	for i in range(8):
		var wx = (i - 3.5) * 2.8
		var win := MeshInstance3D.new()
		var w_box_pane := BoxMesh.new()
		w_box_pane.size = Vector3(2.5, 2.8, 0.15)
		win.mesh = w_box_pane
		win.position = Vector3(wx, 20.2, z_gallery + 1.35)
		win.rotation_degrees = Vector3(12.0, 0.0, 0.0) # Angled down toward pad
		win.material_override = mat_glass
		parent.add_child(win)

	# Observation Gallery Under-Corbels (Structural support brackets)
	for cx in [-11.0, -5.5, 0.0, 5.5, 11.0]:
		var corbel := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(0.45, 1.8, 2.2)
		corbel.mesh = c_box
		corbel.position = Vector3(cx, 17.2, z_gallery - 0.2)
		corbel.material_override = mat_steel
		parent.add_child(corbel)

	# --- D. Rear Maintenance Catwalks with Railings ---
	for py in [10.5, 24.5]:
		var catwalk := MeshInstance3D.new()
		var cw_box := BoxMesh.new()
		cw_box.size = Vector3(64.0, 0.2, 1.6)
		catwalk.mesh = cw_box
		catwalk.position = Vector3(0.0, py, z_rear + 1.2)
		catwalk.material_override = mat_grate
		parent.add_child(catwalk)

		# Yellow Safety Railing along Catwalk
		var rail := MeshInstance3D.new()
		var r_box := BoxMesh.new()
		r_box.size = Vector3(64.0, 1.0, 0.06)
		rail.mesh = r_box
		rail.position = Vector3(0.0, py + 0.6, z_rear + 1.95)
		rail.material_override = mat_gantry
		parent.add_child(rail)

	# Vertical Access Ladder Shafts with Safety Cages
	for lx in [-18.0, 18.0]:
		var ladder := MeshInstance3D.new()
		var l_box := BoxMesh.new()
		l_box.size = Vector3(0.7, 24.5, 0.15)
		ladder.mesh = l_box
		ladder.position = Vector3(lx, 12.25, z_rear + 1.0)
		ladder.material_override = mat_gantry
		parent.add_child(ladder)

		# Safety hoop cage
		for hy in range(3, 24, 2):
			var hoop := MeshInstance3D.new()
			var h_cyl := CylinderMesh.new()
			h_cyl.top_radius = 0.55
			h_cyl.bottom_radius = 0.55
			h_cyl.height = 0.06
			hoop.mesh = h_cyl
			hoop.position = Vector3(lx, hy, z_rear + 1.35)
			hoop.material_override = mat_gantry
			parent.add_child(hoop)

	# --- E. Industrial HVAC Ventilation Ducts & Cryogenic Transfer Lines ---
	# Massive Round Ventilation Duct running horizontally across rear wall
	var duct := MeshInstance3D.new()
	var d_cyl := CylinderMesh.new()
	d_cyl.top_radius = 0.65
	d_cyl.bottom_radius = 0.65
	d_cyl.height = 68.0
	duct.mesh = d_cyl
	duct.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	duct.position = Vector3(0.0, 26.5, z_rear + 1.4)
	duct.material_override = mat_duct
	parent.add_child(duct)

	# Cryogenic Propellant Transfer Lines (Insulated white piping)
	for dy in [6.5, 7.2]:
		var pipe := MeshInstance3D.new()
		var p_cyl := CylinderMesh.new()
		p_cyl.top_radius = 0.16
		p_cyl.bottom_radius = 0.16
		p_cyl.height = 66.0
		pipe.mesh = p_cyl
		pipe.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		pipe.position = Vector3(0.0, dy, z_rear + 1.2)
		pipe.material_override = mat_cryo
		parent.add_child(pipe)

# ==============================================================================
# 3. SIDE RUNWAYS, WALLS & EQUIPMENT ALCOVES
# ==============================================================================

func _build_side_and_front_architecture(parent: Node3D) -> void:
	var mat_wall := SpacecraftMaterials.get_mat("hangar_wall_dark")
	var mat_steel := SpacecraftMaterials.get_mat("hangar_truss_steel")
	var mat_gantry := SpacecraftMaterials.get_mat("gantry_yellow")
	var mat_grate := SpacecraftMaterials.get_mat("hangar_catwalk_grate")
	var mat_cryo := SpacecraftMaterials.get_mat("pipe_cryo_insulation")

	for side_x in [-34.0, 34.0]:
		var dir = 1.0 if side_x > 0 else -1.0

		# Structural Side Wall
		var wall := MeshInstance3D.new()
		var w_box := BoxMesh.new()
		w_box.size = Vector3(1.2, 36.0, 68.0)
		wall.mesh = w_box
		wall.position = Vector3(side_x, 18.0, 0.0)
		wall.material_override = mat_wall
		parent.add_child(wall)

		# Vertical structural columns along side wall
		for z_col in [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]:
			var col := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(1.1, 36.0, 0.85)
			col.mesh = c_box
			col.position = Vector3(side_x - dir * 0.6, 18.0, z_col)
			col.material_override = mat_steel
			parent.add_child(col)

		# Longitudinal Crane Runway Girder (Runs entire length of hall at y = 26m)
		var runway_x = side_x - dir * 6.0
		var runway := MeshInstance3D.new()
		var rw_box := BoxMesh.new()
		rw_box.size = Vector3(1.4, 1.8, 66.0)
		runway.mesh = rw_box
		runway.position = Vector3(runway_x, 26.0, 0.0)
		runway.material_override = mat_steel
		parent.add_child(runway)

		# Steel Crane Rail on top of girder
		var rail := MeshInstance3D.new()
		var r_box := BoxMesh.new()
		r_box.size = Vector3(0.2, 0.25, 66.0)
		rail.mesh = r_box
		rail.position = Vector3(runway_x, 27.0, 0.0)
		rail.material_override = mat_gantry
		parent.add_child(rail)

		# Runway Catwalk with Yellow Safety Railing
		var catwalk := MeshInstance3D.new()
		var cw_box := BoxMesh.new()
		cw_box.size = Vector3(1.2, 0.15, 66.0)
		catwalk.mesh = cw_box
		catwalk.position = Vector3(runway_x - dir * 1.3, 25.4, 0.0)
		catwalk.material_override = mat_grate
		parent.add_child(catwalk)

		var cw_rail := MeshInstance3D.new()
		var cr_box := BoxMesh.new()
		cr_box.size = Vector3(0.06, 1.0, 66.0)
		cw_rail.mesh = cr_box
		cw_rail.position = Vector3(runway_x - dir * 1.85, 26.0, 0.0)
		cw_rail.material_override = mat_gantry
		parent.add_child(cw_rail)

		# --- Ground Equipment Alcoves (Machinery & Gas Bottle Racks) ---
		# High-Voltage Transformer Unit
		var transf := MeshInstance3D.new()
		var tf_box := BoxMesh.new()
		tf_box.size = Vector3(3.2, 3.5, 5.0)
		transf.mesh = tf_box
		transf.position = Vector3(side_x - dir * 3.5, 1.75, -12.0)
		transf.material_override = mat_steel
		parent.add_child(transf)

		# High-Pressure Nitrogen/Helium Gas Bottle Bank (Vertical cascade cylinders)
		for r_row in range(4):
			for r_col in range(2):
				var bottle := MeshInstance3D.new()
				var b_cyl := CylinderMesh.new()
				b_cyl.top_radius = 0.28
				b_cyl.bottom_radius = 0.28
				b_cyl.height = 2.8
				bottle.mesh = b_cyl
				bottle.position = Vector3(side_x - dir * (2.8 + r_col * 0.7), 1.4, 6.0 + r_row * 0.8)
				bottle.material_override = mat_cryo
				parent.add_child(bottle)

		# Wall-mounted Industrial Floodlights along the crane runway
		for z_light in [-16.0, 0.0, 16.0]:
			var side_light := OmniLight3D.new()
			side_light.light_color = Color(0.72, 0.85, 1.0)
			side_light.light_energy = 1.05
			side_light.omni_range = 28.0
			side_light.position = Vector3(runway_x - dir * 2.0, 24.5, z_light)
			parent.add_child(side_light)

	# --- Front Portal Frame (At z = +34m, enclosing front of hall) ---
	var front_portal := MeshInstance3D.new()
	var fp_box := BoxMesh.new()
	fp_box.size = Vector3(72.0, 36.0, 1.2)
	front_portal.mesh = fp_box
	front_portal.position = Vector3(0.0, 18.0, 34.0)
	front_portal.material_override = mat_wall
	parent.add_child(front_portal)

	# Vertical structural columns along front portal wall
	for x_col in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		var col := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(1.1, 36.0, 0.85)
		col.mesh = c_box
		col.position = Vector3(x_col, 18.0, 33.4)
		col.material_override = mat_steel
		parent.add_child(col)

# ==============================================================================
# 4. CEILING SPACE-FRAME TRUSSES & OVERHEAD BRIDGE CRANE
# ==============================================================================

func _build_ceiling_trusses_and_crane(parent: Node3D) -> void:
	var mat_truss := SpacecraftMaterials.get_mat("hangar_truss_steel")
	var mat_crane := SpacecraftMaterials.get_mat("industrial_crane_safety")
	var mat_steel := SpacecraftMaterials.get_mat("gantry_dark_steel")
	var mat_highbay := SpacecraftMaterials.get_mat("highbay_light_fixture")

	# --- A. 5 Massive Space-Frame Triangular Roof Trusses (Spanning 56m) ---
	for z_truss in [-20.0, -10.0, 0.0, 10.0, 20.0]:
		var truss_root := Node3D.new()
		truss_root.position = Vector3(0.0, 32.5, z_truss)
		parent.add_child(truss_root)

		# Top Chord Beam
		var top_chord := MeshInstance3D.new()
		var tc_box := BoxMesh.new()
		tc_box.size = Vector3(56.0, 0.6, 0.6)
		top_chord.mesh = tc_box
		top_chord.position = Vector3(0.0, 1.8, 0.0)
		top_chord.material_override = mat_truss
		truss_root.add_child(top_chord)

		# Bottom Chord Beam
		var bot_chord := MeshInstance3D.new()
		var bc_box := BoxMesh.new()
		bc_box.size = Vector3(56.0, 0.6, 0.6)
		bot_chord.mesh = bc_box
		bot_chord.position = Vector3(0.0, -1.8, 0.0)
		bot_chord.material_override = mat_truss
		truss_root.add_child(bot_chord)

		# Diagonal Web Struts across Truss
		for i in range(-12, 13):
			var strut := MeshInstance3D.new()
			var st_box := BoxMesh.new()
			st_box.size = Vector3(0.25, 4.2, 0.25)
			strut.mesh = st_box
			strut.position = Vector3(i * 2.3, 0.0, 0.0)
			strut.rotation_degrees = Vector3(0.0, 0.0, 35.0 if (i % 2 == 0) else -35.0)
			strut.material_override = mat_truss
			truss_root.add_child(strut)

		# Suspended High-Bay Industrial LED Floodlight Fixtures
		for lx in [-14.0, 0.0, 14.0]:
			var fixture := MeshInstance3D.new()
			var fx_box := BoxMesh.new()
			fx_box.size = Vector3(1.2, 0.4, 0.8)
			fixture.mesh = fx_box
			fixture.position = Vector3(lx, -2.4, 0.0)
			fixture.material_override = mat_highbay
			truss_root.add_child(fixture)

	# --- B. Double-Girder Overhead Bridge Crane (At y = 26.8m, z = -2.5m) ---
	var crane_root := Node3D.new()
	crane_root.name = "OverheadBridgeCrane"
	crane_root.position = Vector3(0.0, 26.8, -2.5)
	parent.add_child(crane_root)

	# Dual heavy structural box girders spanning 52m
	for z_girder in [-1.4, 1.4]:
		var girder := MeshInstance3D.new()
		var g_box := BoxMesh.new()
		g_box.size = Vector3(52.0, 1.8, 0.9)
		girder.mesh = g_box
		girder.position = Vector3(0.0, 0.0, z_girder)
		girder.material_override = mat_crane
		crane_root.add_child(girder)

	# End Trucks (Wheels on crane rails at each runway)
	for ex in [-26.0, 26.0]:
		var truck := MeshInstance3D.new()
		var tr_box := BoxMesh.new()
		tr_box.size = Vector3(1.2, 0.8, 4.5)
		truck.mesh = tr_box
		truck.position = Vector3(ex, 0.4, 0.0)
		truck.material_override = mat_steel
		crane_root.add_child(truck)

	# Crane Hoist Trolley (Centered over pad)
	var trolley := MeshInstance3D.new()
	var t_box := BoxMesh.new()
	t_box.size = Vector3(4.8, 1.2, 3.6)
	trolley.mesh = t_box
	trolley.position = Vector3(1.8, 1.2, 0.0)
	trolley.material_override = mat_crane
	crane_root.add_child(trolley)

	# Wire Rope Cable Drums & Sheaves on Trolley
	for side_d in [-1.0, 1.0]:
		var drum := MeshInstance3D.new()
		var d_cyl := CylinderMesh.new()
		d_cyl.top_radius = 0.55
		d_cyl.bottom_radius = 0.55
		d_cyl.height = 1.4
		drum.mesh = d_cyl
		drum.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		drum.position = Vector3(1.8, 2.0, side_d * 0.9)
		drum.material_override = mat_steel
		crane_root.add_child(drum)

	# Crane Operator Control Cab (Suspended under left girder)
	var cab := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(1.8, 2.4, 1.8)
	cab.mesh = c_box
	cab.position = Vector3(-18.0, -1.4, 0.0)
	cab.material_override = mat_crane
	crane_root.add_child(cab)

# ==============================================================================
# 5. DUAL VERTICAL SERVICE GANTRIES (Flanking Central Vehicle)
# ==============================================================================

func _build_gantry_tower(parent: Node3D, x_center: float, tower_name: String) -> void:
	var tower := Node3D.new()
	tower.name = tower_name
	parent.add_child(tower)

	var mat_gantry := SpacecraftMaterials.get_mat("gantry_yellow")
	var mat_steel := SpacecraftMaterials.get_mat("gantry_dark_steel")

	var z_offsets = [-2.4, 2.4]
	var x_inner = x_center + (1.1 if x_center < 0 else -1.1)
	var x_outer = x_center + (-1.1 if x_center < 0 else 1.1)

	# 4 Vertical structural columns per gantry (Dark steel launch tower trusses matching reference 01_helios4_hangar.png)
	for z_pos in z_offsets:
		for x_pos in [x_inner, x_outer]:
			var col := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(0.32, 24.0, 0.32)
			col.mesh = c_box
			col.position = Vector3(x_pos, 12.0, z_pos)
			col.material_override = mat_steel
			tower.add_child(col)

	# Diagonal lattice cross-bracing along the outer face of gantry towers
	for py in [2.2, 6.4, 10.6, 14.8, 19.0, 23.0]:
		var strut1 := MeshInstance3D.new()
		var s1_box := BoxMesh.new()
		s1_box.size = Vector3(0.1, 0.1, 5.0)
		strut1.mesh = s1_box
		strut1.position = Vector3(x_outer, py, 0.0)
		strut1.rotation = Vector3(0.42, 0.0, 0.0)
		strut1.material_override = mat_steel
		tower.add_child(strut1)

		var strut2 := MeshInstance3D.new()
		var s2_box := BoxMesh.new()
		s2_box.size = Vector3(0.1, 0.1, 5.0)
		strut2.mesh = s2_box
		strut2.position = Vector3(x_outer, py, 0.0)
		strut2.rotation = Vector3(-0.42, 0.0, 0.0)
		strut2.material_override = mat_steel
		tower.add_child(strut2)

	# 4 Work Platforms with safety railings
	var platform_heights = [3.5, 7.8, 12.2, 16.5]
	for idx in range(platform_heights.size()):
		var py = platform_heights[idx]

		# Floor deck
		var deck := MeshInstance3D.new()
		var d_box := BoxMesh.new()
		d_box.size = Vector3(2.6, 0.24, 5.2)
		deck.mesh = d_box
		deck.position = Vector3(x_center, py, 0.0)
		deck.material_override = mat_steel
		tower.add_child(deck)

		# Extended walkway bridge pointing toward rocket
		var bridge := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(1.6, 0.2, 2.0)
		bridge.mesh = b_box
		var bridge_x = x_center + (1.7 if x_center < 0 else -1.7)
		bridge.position = Vector3(bridge_x, py, 0.0)
		bridge.material_override = mat_gantry
		tower.add_child(bridge)

		# Safety Railings
		var rail_x = bridge_x + (0.8 if x_center < 0 else -0.8)
		var rail := MeshInstance3D.new()
		var r_box := BoxMesh.new()
		r_box.size = Vector3(0.08, 0.95, 2.0)
		rail.mesh = r_box
		rail.position = Vector3(rail_x, py + 0.5, 0.0)
		rail.material_override = mat_gantry
		tower.add_child(rail)

		# Glowing Worklight Lamp Fixture
		var fixture := MeshInstance3D.new()
		var fix_sph := SphereMesh.new()
		fix_sph.radius = 0.16
		fix_sph.height = 0.32
		fixture.mesh = fix_sph
		fixture.position = Vector3(bridge_x, py + 0.95, 0.0)
		var fix_mat := StandardMaterial3D.new()
		fix_mat.albedo_color = Color(1.0, 0.88, 0.45)
		fix_mat.emission_enabled = true
		fix_mat.emission = Color(1.0, 0.78, 0.28)
		fix_mat.emission_energy_multiplier = 3.5
		fixture.material_override = fix_mat
		tower.add_child(fixture)

		# Amber Industrial Work Spotlight on platform
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.74, 0.28)
		light.light_energy = 1.35
		light.omni_range = 8.5
		light.position = Vector3(bridge_x, py + 1.2, 0.0)
		tower.add_child(light)

# ==============================================================================
# 6. ARTICULATED ROBOTIC WELDING ARMS WITH SPARKS
# ==============================================================================

func _build_robotic_welding_arms(parent: Node3D) -> void:
	var mat_yellow := SpacecraftMaterials.get_mat("gantry_yellow")
	var mat_steel := SpacecraftMaterials.get_mat("gantry_dark_steel")

	# --- ARM 1: Overhead Crane Robot Arm (Welding from ceiling onto upper stage) ---
	var arm_top := Node3D.new()
	arm_top.name = "RoboticArm_Overhead"
	arm_top.position = Vector3(1.8, 25.5, -2.2)
	parent.add_child(arm_top)

	# Turret
	var sh1 := MeshInstance3D.new()
	var sh1_cyl := CylinderMesh.new()
	sh1_cyl.top_radius = 0.45
	sh1_cyl.bottom_radius = 0.45
	sh1_cyl.height = 0.6
	sh1.mesh = sh1_cyl
	sh1.material_override = mat_steel
	arm_top.add_child(sh1)

	# Upper arm extending down toward rocket
	var boom_top := MeshInstance3D.new()
	var bt_box := BoxMesh.new()
	bt_box.size = Vector3(0.38, 5.2, 0.38)
	boom_top.mesh = bt_box
	boom_top.position = Vector3(-0.9, -2.4, 0.9)
	boom_top.rotation_degrees = Vector3(25.0, 20.0, 32.0)
	boom_top.material_override = mat_yellow
	arm_top.add_child(boom_top)

	# Forearm reaching near fairing rim
	var fore_top := MeshInstance3D.new()
	var ft_box := BoxMesh.new()
	ft_box.size = Vector3(0.3, 4.4, 0.3)
	fore_top.mesh = ft_box
	fore_top.position = Vector3(-1.6, -5.8, 2.0)
	fore_top.rotation_degrees = Vector3(-20.0, 15.0, 65.0)
	fore_top.material_override = mat_yellow
	arm_top.add_child(fore_top)

	# Torch head
	var torch_top := MeshInstance3D.new()
	var tt_cyl := CylinderMesh.new()
	tt_cyl.top_radius = 0.05
	tt_cyl.bottom_radius = 0.1
	tt_cyl.height = 0.45
	torch_top.mesh = tt_cyl
	torch_top.position = Vector3(-2.1, -7.2, 2.4)
	torch_top.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	torch_top.material_override = mat_steel
	arm_top.add_child(torch_top)

	# Welding Light 1 (Overhead)
	weld_light_1 = OmniLight3D.new()
	weld_light_1.position = Vector3(-2.2, -7.3, 2.4)
	weld_light_1.light_color = Color(1.0, 0.9, 0.45)
	weld_light_1.light_energy = 1.9
	weld_light_1.omni_range = 8.5
	arm_top.add_child(weld_light_1)

	# Spark Emitter 1 (Overhead Sparks shower down)
	spark_emitter_1 = CPUParticles3D.new()
	spark_emitter_1.position = Vector3(-2.2, -7.3, 2.4)
	spark_emitter_1.amount = 45
	spark_emitter_1.lifetime = 0.75
	spark_emitter_1.explosiveness = 0.15
	spark_emitter_1.direction = Vector3(-0.2, -1.0, 0.3)
	spark_emitter_1.spread = 50.0
	spark_emitter_1.initial_velocity_min = 2.5
	spark_emitter_1.initial_velocity_max = 6.0
	spark_emitter_1.gravity = Vector3(0.0, -14.0, 0.0)
	spark_emitter_1.scale_amount_min = 0.03
	spark_emitter_1.scale_amount_max = 0.08
	spark_emitter_1.color = Color(1.0, 0.88, 0.35)
	spark_emitter_1.material_override = SpacecraftMaterials.get_mat("welding_spark_mat")
	arm_top.add_child(spark_emitter_1)

	# --- ARM 2: Left Gantry Platform Arm (Welding Booster Core) ---
	var arm_mid := Node3D.new()
	arm_mid.name = "RoboticArm_MidLeft"
	arm_mid.position = Vector3(-3.8, 4.2, 0.6)
	parent.add_child(arm_mid)

	var boom_mid := MeshInstance3D.new()
	var bm_box := BoxMesh.new()
	bm_box.size = Vector3(0.28, 2.0, 0.28)
	boom_mid.mesh = bm_box
	boom_mid.position = Vector3(0.8, 0.7, -0.3)
	boom_mid.rotation_degrees = Vector3(-15.0, 20.0, -45.0)
	boom_mid.material_override = mat_yellow
	arm_mid.add_child(boom_mid)

	var fore_mid := MeshInstance3D.new()
	var fm_box := BoxMesh.new()
	fm_box.size = Vector3(0.22, 1.8, 0.22)
	fore_mid.mesh = fm_box
	fore_mid.position = Vector3(1.8, 0.3, -0.5)
	fore_mid.rotation_degrees = Vector3(15.0, 15.0, -85.0)
	fore_mid.material_override = mat_yellow
	arm_mid.add_child(fore_mid)

	weld_light_2 = OmniLight3D.new()
	weld_light_2.position = Vector3(2.5, 0.1, -0.6)
	weld_light_2.light_color = Color(0.95, 0.85, 0.35)
	weld_light_2.light_energy = 1.4
	weld_light_2.omni_range = 6.0
	arm_mid.add_child(weld_light_2)

	spark_emitter_2 = CPUParticles3D.new()
	spark_emitter_2.position = Vector3(2.5, 0.1, -0.6)
	spark_emitter_2.amount = 35
	spark_emitter_2.lifetime = 0.6
	spark_emitter_2.direction = Vector3(0.3, -1.0, 0.1)
	spark_emitter_2.spread = 45.0
	spark_emitter_2.initial_velocity_min = 2.0
	spark_emitter_2.initial_velocity_max = 5.0
	spark_emitter_2.gravity = Vector3(0.0, -12.0, 0.0)
	spark_emitter_2.scale_amount_min = 0.02
	spark_emitter_2.scale_amount_max = 0.06
	spark_emitter_2.color = Color(1.0, 0.75, 0.2)
	spark_emitter_2.material_override = SpacecraftMaterials.get_mat("welding_spark_mat")
	arm_mid.add_child(spark_emitter_2)

	# --- ARM 3: Right Gantry Platform Arm (Inspecting Flank) ---
	var arm_r := Node3D.new()
	arm_r.name = "RoboticArm_MidRight"
	arm_r.position = Vector3(3.8, 4.2, -0.4)
	parent.add_child(arm_r)

	var boom_r := MeshInstance3D.new()
	var br_box := BoxMesh.new()
	br_box.size = Vector3(0.28, 2.0, 0.28)
	boom_r.mesh = br_box
	boom_r.position = Vector3(-0.8, 0.7, 0.2)
	boom_r.rotation_degrees = Vector3(15.0, -20.0, 45.0)
	boom_r.material_override = mat_yellow
	arm_r.add_child(boom_r)

	var fore_r := MeshInstance3D.new()
	var fr_box := BoxMesh.new()
	fr_box.size = Vector3(0.22, 1.8, 0.22)
	fore_r.mesh = fr_box
	fore_r.position = Vector3(-1.8, 0.3, 0.4)
	fore_r.rotation_degrees = Vector3(-15.0, -15.0, 85.0)
	fore_r.material_override = mat_yellow
	arm_r.add_child(fore_r)

# ==============================================================================
# 7. ATMOSPHERIC BASE STEAM / VENTS
# ==============================================================================

func _build_base_steam(parent: Node3D) -> void:
	var steam := CPUParticles3D.new()
	steam.name = "PadSteamVents"
	steam.position = Vector3(0.0, 0.5, 0.0)
	steam.amount = 40
	steam.lifetime = 3.8
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	steam.emission_ring_radius = 2.8
	steam.emission_ring_inner_radius = 2.2
	steam.direction = Vector3(0.0, 1.0, 0.0)
	steam.spread = 25.0
	steam.initial_velocity_min = 0.4
	steam.initial_velocity_max = 1.2
	steam.gravity = Vector3(0.0, 0.2, 0.0)
	steam.scale_amount_min = 0.4
	steam.scale_amount_max = 2.0
	steam.color = Color(0.85, 0.9, 0.98, 0.08)

	var mat_steam := StandardMaterial3D.new()
	mat_steam.albedo_color = Color(0.88, 0.92, 0.98, 0.08)
	mat_steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_steam.roughness = 0.9
	steam.material_override = mat_steam
	parent.add_child(steam)

# ==============================================================================
# STAGE 1: HEAVY QUAD-BOOSTER PROPULSION CORE (Matching Reference 01)
# ==============================================================================

func _build_stage1(parent: Node3D) -> void:
	var mat_steel := SpacecraftMaterials.get_mat("rocket_machined_steel")
	var mat_dark := SpacecraftMaterials.get_mat("rocket_dark_carbon")

	# --- A. Central Structural Core Column ---
	var core_spine := MeshInstance3D.new()
	var cs_cyl := CylinderMesh.new()
	cs_cyl.top_radius = 1.1
	cs_cyl.bottom_radius = 1.1
	cs_cyl.height = 5.6
	cs_cyl.radial_segments = 24
	core_spine.mesh = cs_cyl
	core_spine.position = Vector3(0.0, 3.4, 0.0)
	core_spine.material_override = mat_dark
	parent.add_child(core_spine)

	# Central Vertical Pipe Conduits / Raceways
	for angle in [0.0, 90.0, 180.0, 270.0]:
		var rad = deg_to_rad(angle)
		var pipe := MeshInstance3D.new()
		var p_cyl := CylinderMesh.new()
		p_cyl.top_radius = 0.08
		p_cyl.bottom_radius = 0.08
		p_cyl.height = 5.4
		pipe.mesh = p_cyl
		pipe.position = Vector3(cos(rad) * 1.15, 3.4, sin(rad) * 1.15)
		pipe.material_override = mat_steel
		parent.add_child(pipe)

	# --- B. 4 Massive Strap-on Booster Propellant Tanks ---
	# Arranged in symmetric quad cluster around the core spine
	var tank_offsets = [
		Vector3(-0.95, 3.4, -0.95),
		Vector3(0.95, 3.4, -0.95),
		Vector3(-0.95, 3.4, 0.95),
		Vector3(0.95, 3.4, 0.95)
	]

	for t_pos in tank_offsets:
		var tank_root := Node3D.new()
		tank_root.position = t_pos
		parent.add_child(tank_root)

		# Main Cylindrical Tank Barrel
		var tank_mesh := MeshInstance3D.new()
		var tm_cyl := CylinderMesh.new()
		tm_cyl.top_radius = 0.68
		tm_cyl.bottom_radius = 0.68
		tm_cyl.height = 4.4
		tm_cyl.radial_segments = 24
		tank_mesh.mesh = tm_cyl
		tank_mesh.material_override = mat_steel
		tank_root.add_child(tank_mesh)

		# Hemispherical Top Dome Cap
		var cap_top := MeshInstance3D.new()
		var ct_sph := SphereMesh.new()
		ct_sph.radius = 0.68
		ct_sph.height = 0.68
		cap_top.mesh = ct_sph
		cap_top.position = Vector3(0.0, 2.2, 0.0)
		cap_top.material_override = mat_steel
		tank_root.add_child(cap_top)

		# Hemispherical Bottom Dome Cap
		var cap_bot := MeshInstance3D.new()
		var cb_sph := SphereMesh.new()
		cb_sph.radius = 0.68
		cb_sph.height = 0.68
		cap_bot.mesh = cb_sph
		cap_bot.position = Vector3(0.0, -2.2, 0.0)
		cap_bot.material_override = mat_steel
		tank_root.add_child(cap_bot)

		# Circumferential Structural Weld Seam Ribs
		for y_rib in [-1.4, -0.4, 0.6, 1.6]:
			var rib := MeshInstance3D.new()
			var r_cyl := CylinderMesh.new()
			r_cyl.top_radius = 0.70
			r_cyl.bottom_radius = 0.70
			r_cyl.height = 0.06
			rib.mesh = r_cyl
			rib.position = Vector3(0.0, y_rib, 0.0)
			rib.material_override = mat_dark
			tank_root.add_child(rib)

		# Vertical Conduit Spine on exterior of tank
		var spine := MeshInstance3D.new()
		var sp_box := BoxMesh.new()
		sp_box.size = Vector3(0.08, 4.4, 0.12)
		spine.mesh = sp_box
		var sp_dir = t_pos.normalized()
		spine.position = sp_dir * 0.72
		spine.material_override = mat_dark
		tank_root.add_child(spine)

	# --- C. Base Thrust Puck & Skirt ---
	var thrust_puck := MeshInstance3D.new()
	var tp_cyl := CylinderMesh.new()
	tp_cyl.top_radius = 1.95
	tp_cyl.bottom_radius = 2.1
	tp_cyl.height = 0.6
	tp_cyl.radial_segments = 32
	thrust_puck.mesh = tp_cyl
	thrust_puck.position = Vector3(0.0, 0.9, 0.0)
	thrust_puck.material_override = mat_dark
	parent.add_child(thrust_puck)

	# --- D. 4x Titanium Aerodynamic Grid Fins ---
	grid_fins_node = Node3D.new()
	grid_fins_node.name = "GridFinsCluster"
	parent.add_child(grid_fins_node)
	_build_grid_fins(grid_fins_node)

	# --- E. 4-Bell Massive Rocket Engine Nozzle Cluster ---
	engine_cluster_node = Node3D.new()
	engine_cluster_node.name = "EngineCluster"
	parent.add_child(engine_cluster_node)
	_build_engine_cluster(engine_cluster_node)

func _build_grid_fins(parent: Node3D) -> void:
	var mat_fin := SpacecraftMaterials.get_mat("titanium")
	var mat_hinge := SpacecraftMaterials.get_mat("rocket_machined_steel")

	for a in [0.0, 90.0, 180.0, 270.0]:
		var rad = deg_to_rad(a)
		var fin_mount := Node3D.new()
		fin_mount.position = Vector3(cos(rad) * 2.05, 1.25, sin(rad) * 2.05)
		fin_mount.rotation.y = -rad
		parent.add_child(fin_mount)

		# Hinge bracket
		var hinge := MeshInstance3D.new()
		var h_box := BoxMesh.new()
		h_box.size = Vector3(0.16, 0.25, 0.28)
		hinge.mesh = h_box
		hinge.position = Vector3(0.12, 0.0, 0.0)
		hinge.material_override = mat_hinge
		fin_mount.add_child(hinge)

		# Perforated Grid Fin blade
		var fin := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(0.06, 0.8, 0.9)
		fin.mesh = f_box
		fin.position = Vector3(0.55, 0.0, 0.0)
		fin.material_override = mat_fin
		fin_mount.add_child(fin)

		# Honeycomb waffle ribs
		for slat in [-0.25, 0.0, 0.25]:
			var s := MeshInstance3D.new()
			var s_box := BoxMesh.new()
			s_box.size = Vector3(0.08, 0.04, 0.85)
			s.mesh = s_box
			s.position = Vector3(0.55, slat, 0.0)
			s.material_override = mat_hinge
			fin_mount.add_child(s)

func _build_engine_cluster(parent: Node3D) -> void:
	var mat_bell := SpacecraftMaterials.get_mat("rocket_inconel_bell")
	var mat_copper := SpacecraftMaterials.get_mat("rocket_copper_chamber")
	var mat_steel := SpacecraftMaterials.get_mat("rocket_machined_steel")

	# 4 Rocket Engines positioned under the 4 booster tanks
	var offsets = [
		Vector3(-0.95, 0.0, -0.95),
		Vector3(0.95, 0.0, -0.95),
		Vector3(-0.95, 0.0, 0.95),
		Vector3(0.95, 0.0, 0.95)
	]

	for off in offsets:
		var eng_mount := Node3D.new()
		eng_mount.position = off
		parent.add_child(eng_mount)

		# Copper Combustion Chamber
		var chamber := MeshInstance3D.new()
		var ch_cyl := CylinderMesh.new()
		ch_cyl.top_radius = 0.22
		ch_cyl.bottom_radius = 0.18
		ch_cyl.height = 0.4
		chamber.mesh = ch_cyl
		chamber.position = Vector3(0.0, 0.65, 0.0)
		chamber.material_override = mat_copper
		eng_mount.add_child(chamber)

		# Flared Inconel Expansion Nozzle Bell (Wide bell matching reference)
		var bell := MeshInstance3D.new()
		var b_cyl := CylinderMesh.new()
		b_cyl.top_radius = 0.16
		b_cyl.bottom_radius = 0.50
		b_cyl.height = 0.95
		b_cyl.radial_segments = 24
		bell.mesh = b_cyl
		bell.position = Vector3(0.0, 0.1, 0.0)
		bell.material_override = mat_bell
		eng_mount.add_child(bell)

		# Stiffening Lip Ring on bell exit
		var lip := MeshInstance3D.new()
		var l_cyl := CylinderMesh.new()
		l_cyl.top_radius = 0.51
		l_cyl.bottom_radius = 0.51
		l_cyl.height = 0.06
		lip.mesh = l_cyl
		lip.position = Vector3(0.0, -0.37, 0.0)
		lip.material_override = mat_steel
		eng_mount.add_child(lip)

		# Dual Gimbal Hydraulic Actuators
		for side in [-1.0, 1.0]:
			var piston := MeshInstance3D.new()
			var p_cyl := CylinderMesh.new()
			p_cyl.top_radius = 0.025
			p_cyl.bottom_radius = 0.025
			p_cyl.height = 0.55
			piston.mesh = p_cyl
			piston.position = Vector3(side * 0.22, 0.5, 0.0)
			piston.rotation_degrees = Vector3(0.0, 0.0, side * 14.0)
			piston.material_override = mat_steel
			eng_mount.add_child(piston)

# ==============================================================================
# STAGE 2: VACUUM UPPER STAGE & OPEN INTERSTAGE TRUSS
# ==============================================================================

func _build_stage2(parent: Node3D) -> void:
	var mat_steel := SpacecraftMaterials.get_mat("rocket_machined_steel")
	var mat_dark := SpacecraftMaterials.get_mat("rocket_dark_carbon")
	var mat_bell := SpacecraftMaterials.get_mat("rocket_inconel_bell")
	var mat_copv := SpacecraftMaterials.get_mat("carbon_fiber")

	# --- A. Open-Lattice Cylindrical Interstage Truss ---
	# Connects booster top to upper stage (y = 0.0 to 1.6)
	if not include_hangar:
		var skirt := MeshInstance3D.new()
		var s_cyl := CylinderMesh.new()
		s_cyl.top_radius = 1.45
		s_cyl.bottom_radius = 1.45
		s_cyl.height = 1.6
		s_cyl.radial_segments = 32
		skirt.mesh = s_cyl
		skirt.position = Vector3(0.0, 0.8, 0.0)
		skirt.material_override = mat_dark
		parent.add_child(skirt)

	for ring_y in [0.08, 1.52]:
		var ring := MeshInstance3D.new()
		var r_cyl := CylinderMesh.new()
		r_cyl.top_radius = 1.45
		r_cyl.bottom_radius = 1.45
		r_cyl.height = 0.1
		ring.mesh = r_cyl
		ring.position = Vector3(0.0, ring_y, 0.0)
		ring.material_override = mat_steel
		parent.add_child(ring)

	# Diagonal criss-cross tubular X-bracing struts (16 struts forming the lattice cage)
	for i in range(16):
		var a = i * (360.0 / 16.0)
		var rad = deg_to_rad(a)
		var strut := MeshInstance3D.new()
		var s_cyl := CylinderMesh.new()
		s_cyl.top_radius = 0.045
		s_cyl.bottom_radius = 0.045
		s_cyl.height = 1.65
		strut.mesh = s_cyl
		strut.position = Vector3(cos(rad) * 1.42, 0.8, sin(rad) * 1.42)
		strut.rotation_degrees = Vector3(0.0, -a, 24.0 if (i % 2 == 0) else -24.0)
		strut.material_override = mat_steel
		parent.add_child(strut)

	# Visible Vacuum Engine Bell inside the Interstage Truss
	var vac_bell := MeshInstance3D.new()
	var vb_cyl := CylinderMesh.new()
	vb_cyl.top_radius = 0.18
	vb_cyl.bottom_radius = 0.75
	vb_cyl.height = 1.25
	vb_cyl.radial_segments = 24
	vac_bell.mesh = vb_cyl
	vac_bell.position = Vector3(0.0, 0.7, 0.0)
	vac_bell.material_override = mat_bell
	parent.add_child(vac_bell)

	# --- B. Stage 2 Upper Propellant Tank ---
	var s2_tank := MeshInstance3D.new()
	var s2_cyl := CylinderMesh.new()
	s2_cyl.top_radius = 1.35
	s2_cyl.bottom_radius = 1.35
	s2_cyl.height = 2.2
	s2_cyl.radial_segments = 32
	s2_tank.mesh = s2_cyl
	s2_tank.position = Vector3(0.0, 2.7, 0.0)
	s2_tank.material_override = mat_steel
	parent.add_child(s2_tank)

	# Equipment collar / avionics ring on top of tank
	var collar := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 1.38
	c_cyl.bottom_radius = 1.38
	c_cyl.height = 0.35
	collar.mesh = c_cyl
	collar.position = Vector3(0.0, 3.9, 0.0)
	collar.material_override = mat_dark
	parent.add_child(collar)

	# 4x Spherical Helium COPV Pressurant Bottles
	for angle in [45.0, 135.0, 225.0, 315.0]:
		var rad = deg_to_rad(angle)
		var copv := MeshInstance3D.new()
		var c_sph := SphereMesh.new()
		c_sph.radius = 0.28
		c_sph.height = 0.56
		copv.mesh = c_sph
		copv.position = Vector3(cos(rad) * 1.38, 2.7, sin(rad) * 1.38)
		copv.material_override = mat_copv
		parent.add_child(copv)

# ==============================================================================
# STAGE 3 / PROBE: HELIOS-4 SOLAR WEATHER OBSERVATORY (Matching Reference 01)
# ==============================================================================

func _build_probe(parent: Node3D) -> void:
	var mat_gold := SpacecraftMaterials.get_mat("gold_mli")
	var mat_dish := SpacecraftMaterials.get_mat("antenna_reflector")
	var mat_feed := SpacecraftMaterials.get_mat("antenna_feed")
	var mat_carbon := SpacecraftMaterials.get_mat("carbon_fiber")
	var mat_steel := SpacecraftMaterials.get_mat("rocket_machined_steel")
	var mat_sensor := SpacecraftMaterials.get_mat("sensor_body")

	# Conical Payload Adapter Ring
	var adapter := MeshInstance3D.new()
	var a_cyl := CylinderMesh.new()
	a_cyl.top_radius = 0.8
	a_cyl.bottom_radius = 1.3
	a_cyl.height = 0.6
	adapter.mesh = a_cyl
	adapter.position = Vector3(0.0, 0.3, 0.0)
	adapter.material_override = mat_carbon
	parent.add_child(adapter)

	# Central Spacecraft Bus (Cube in Brilliant Gold MLI Foil)
	var bus := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(1.15, 1.25, 1.15)
	bus.mesh = b_box
	bus.position = Vector3(0.0, 1.25, 0.0)
	bus.material_override = mat_gold
	parent.add_child(bus)

	# 4x Corner RCS Thruster Pods
	for cx in [-0.58, 0.58]:
		for cz in [-0.58, 0.58]:
			var rcs := MeshInstance3D.new()
			var r_box := BoxMesh.new()
			r_box.size = Vector3(0.12, 0.12, 0.12)
			rcs.mesh = r_box
			rcs.position = Vector3(cx, 1.5, cz)
			rcs.material_override = mat_steel
			parent.add_child(rcs)

	# Deployable GaAs Solar Array Wings (Left & Right)
	solar_wing_left = Node3D.new()
	solar_wing_left.name = "SolarWing_Left"
	solar_wing_left.position = Vector3(-0.62, 1.25, 0.0)
	parent.add_child(solar_wing_left)
	_build_solar_wing(solar_wing_left, -1.0)

	solar_wing_right = Node3D.new()
	solar_wing_right.name = "SolarWing_Right"
	solar_wing_right.position = Vector3(0.62, 1.25, 0.0)
	parent.add_child(solar_wing_right)
	_build_solar_wing(solar_wing_right, 1.0)

	# Parabolic High-Gain Dish Antenna on 2-Axis Gimbal
	var dish_pivot := Node3D.new()
	dish_pivot.name = "HighGainDishPivot"
	dish_pivot.position = Vector3(0.0, 1.95, 0.25)
	dish_pivot.rotation_degrees = Vector3(-28.0, 15.0, 0.0)
	parent.add_child(dish_pivot)

	var dish := MeshInstance3D.new()
	var d_sph := SphereMesh.new()
	d_sph.radius = 0.65
	d_sph.height = 0.26
	dish.mesh = d_sph
	dish.material_override = mat_dish
	dish_pivot.add_child(dish)

	# Antenna Feedhorn
	var feed := MeshInstance3D.new()
	var f_cyl := CylinderMesh.new()
	f_cyl.top_radius = 0.04
	f_cyl.bottom_radius = 0.06
	f_cyl.height = 0.38
	feed.mesh = f_cyl
	feed.position = Vector3(0.0, 0.28, 0.0)
	feed.material_override = mat_feed
	dish_pivot.add_child(feed)

	# Triaxial Fluxgate Magnetometer Boom (Extends diagonally upward-right)
	mag_boom = Node3D.new()
	mag_boom.name = "MagnetometerBoom"
	mag_boom.position = Vector3(0.45, 1.8, -0.4)
	mag_boom.rotation_degrees = Vector3(38.0, 42.0, -25.0)
	parent.add_child(mag_boom)

	var mast := MeshInstance3D.new()
	var m_cyl := CylinderMesh.new()
	m_cyl.top_radius = 0.025
	m_cyl.bottom_radius = 0.04
	m_cyl.height = 3.6
	mast.mesh = m_cyl
	mast.position = Vector3(0.0, 1.8, 0.0)
	mast.material_override = mat_carbon
	mag_boom.add_child(mast)

	var mag_sensor := MeshInstance3D.new()
	var ms_cyl := CylinderMesh.new()
	ms_cyl.top_radius = 0.08
	ms_cyl.bottom_radius = 0.08
	ms_cyl.height = 0.24
	mag_sensor.mesh = ms_cyl
	mag_sensor.position = Vector3(0.0, 3.6, 0.0)
	mag_sensor.material_override = mat_gold
	mag_boom.add_child(mag_sensor)

	# Faraday Cup Plasma Analyzer
	var faraday := MeshInstance3D.new()
	var fc_cyl := CylinderMesh.new()
	fc_cyl.top_radius = 0.12
	fc_cyl.bottom_radius = 0.06
	fc_cyl.height = 0.25
	faraday.mesh = fc_cyl
	faraday.position = Vector3(-0.35, 1.5, -0.6)
	faraday.rotation_degrees = Vector3(45.0, 0.0, 0.0)
	faraday.material_override = mat_sensor
	parent.add_child(faraday)

func _build_solar_wing(parent: Node3D, dir: float) -> void:
	var mat_panel := SpacecraftMaterials.get_mat("solar_panel")
	var mat_steel := SpacecraftMaterials.get_mat("rocket_machined_steel")

	# 2 Large Articulated Panels per Wing
	for i in [1, 2]:
		var panel_root := Node3D.new()
		panel_root.position = Vector3(dir * (i * 1.15 - 0.5), 0.0, 0.0)
		parent.add_child(panel_root)

		# Deep blue photovoltaic front face
		var front := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(1.05, 0.85, 0.03)
		front.mesh = p_box
		front.material_override = mat_panel
		panel_root.add_child(front)

		# Silver interconnect busbars on panel
		for bar_x in [-0.3, 0.0, 0.3]:
			var bar := MeshInstance3D.new()
			var b_box := BoxMesh.new()
			b_box.size = Vector3(0.02, 0.84, 0.035)
			bar.mesh = b_box
			bar.position = Vector3(bar_x, 0.0, 0.0)
			bar.material_override = mat_steel
			panel_root.add_child(bar)

# ==============================================================================
# SPLIT PAYLOAD FAIRINGS
# ==============================================================================

func _build_fairings() -> void:
	var mat_fairing := SpacecraftMaterials.get_mat("rocket_dark_carbon")
	var mat_tip := SpacecraftMaterials.get_mat("rocket_machined_steel")

	# Left Fairing Half
	fairing_left = Node3D.new()
	fairing_left.name = "FairingHalf_Left"
	fairing_left.position = Vector3(0.0, 10.1, 0.0)
	add_child(fairing_left)

	var shell_l := MeshInstance3D.new()
	var c_l := CylinderMesh.new()
	c_l.top_radius = 0.5
	c_l.bottom_radius = 1.38
	c_l.height = 4.8
	c_l.radial_segments = 24
	shell_l.mesh = c_l
	shell_l.position = Vector3(0.0, 2.4, 0.0)
	shell_l.rotation_degrees = Vector3.ZERO
	shell_l.material_override = mat_fairing
	fairing_left.add_child(shell_l)

	# Sleek ogive nose cone tip
	var tip_l := MeshInstance3D.new()
	var c_tip_l := CylinderMesh.new()
	c_tip_l.top_radius = 0.04
	c_tip_l.bottom_radius = 0.5
	c_tip_l.height = 1.6
	c_tip_l.radial_segments = 24
	tip_l.mesh = c_tip_l
	tip_l.position = Vector3(0.0, 5.6, 0.0)
	tip_l.material_override = mat_tip
	fairing_left.add_child(tip_l)

	# Right Fairing Half
	fairing_right = Node3D.new()
	fairing_right.name = "FairingHalf_Right"
	fairing_right.position = Vector3(0.0, 10.1, 0.0)
	add_child(fairing_right)

	var shell_r := MeshInstance3D.new()
	var c_r := CylinderMesh.new()
	c_r.top_radius = 0.5
	c_r.bottom_radius = 1.38
	c_r.height = 4.8
	c_r.radial_segments = 24
	shell_r.mesh = c_r
	shell_r.position = Vector3(0.0, 2.4, 0.0)
	shell_r.rotation_degrees = Vector3.ZERO
	shell_r.material_override = mat_fairing
	fairing_right.add_child(shell_r)

	var tip_r := MeshInstance3D.new()
	var c_tip_r := CylinderMesh.new()
	c_tip_r.top_radius = 0.04
	c_tip_r.bottom_radius = 0.5
	c_tip_r.height = 1.6
	c_tip_r.radial_segments = 24
	tip_r.mesh = c_tip_r
	tip_r.position = Vector3(0.0, 5.6, 0.0)
	tip_r.material_override = mat_tip
	fairing_right.add_child(tip_r)

func set_fairing_open_instant(is_open: bool) -> void:
	fairing_open = is_open
	if not fairing_left or not fairing_right:
		return
	if is_open:
		fairing_left.rotation_degrees.z = 24.0
		fairing_left.position.x = -1.4
		fairing_right.rotation_degrees.z = -24.0
		fairing_right.position.x = 1.4
	else:
		fairing_left.rotation_degrees.z = 0.0
		fairing_left.position.x = 0.0
		fairing_right.rotation_degrees.z = 0.0
		fairing_right.position.x = 0.0

func update_fairing_pose(is_open: bool) -> void:
	fairing_open = is_open
	if not fairing_left or not fairing_right:
		return

	var tween := create_tween()
	tween.set_parallel(true)
	if is_open:
		tween.tween_property(fairing_left, "rotation_degrees:z", 24.0, 0.45)
		tween.tween_property(fairing_left, "position:x", -1.4, 0.45)
		tween.tween_property(fairing_right, "rotation_degrees:z", -24.0, 0.45)
		tween.tween_property(fairing_right, "position:x", 1.4, 0.45)
	else:
		tween.tween_property(fairing_left, "rotation_degrees:z", 0.0, 0.45)
		tween.tween_property(fairing_left, "position:x", 0.0, 0.45)
		tween.tween_property(fairing_right, "rotation_degrees:z", 0.0, 0.45)
		tween.tween_property(fairing_right, "position:x", 0.0, 0.45)

# ==============================================================================
# HOLOGRAPHIC 3D CALLOUT TARGETS & MINI PREVIEWS (Matching Reference 01)
# ==============================================================================

func _build_holographic_callouts() -> void:
	# Left Callout: Floating 3D Engine Cluster Preview + Leader Lines to Rocket Base
	_create_floating_preview_callout(
		"propulsion_engines",
		Vector3(-2.8, 4.2, 2.0),
		1.6, 1.4,
		"engine",
		Vector3(-0.95, 0.6, 0.0)
	)

	# Right Callout: Floating 3D Solar Array Preview + Leader Lines to Probe
	_create_floating_preview_callout(
		"solar_wings",
		Vector3(2.8, 6.8, 2.0),
		1.8, 1.3,
		"solar",
		Vector3(1.2, 11.8, 0.0)
	)

	# Subsystem Callouts for interaction
	_create_wireframe_callout("grid_fins", Vector3(2.0, 1.8, 1.4), 1.4, 1.1)
	_create_wireframe_callout("interstage_vacuum", Vector3(-2.0, 7.2, 1.4), 1.5, 1.3)
	_create_wireframe_callout("probe_bus", Vector3(-2.0, 11.8, 1.4), 1.6, 1.5)

func _create_floating_preview_callout(id: String, pos: Vector3, w: float, h: float, preview_type: String, target_world_pos: Vector3) -> void:
	var callout_root := Node3D.new()
	callout_root.name = "Callout_" + id
	callout_root.position = pos
	add_child(callout_root)

	var mat_cyan := SpacecraftMaterials.get_mat("hologram_bracket_cyan")

	# 1. Corner L-brackets
	var corner_bars := _create_bracket_geometry(callout_root, w, h, mat_cyan)

	# 2. Mini 3D Preview Model inside the bracket box
	var preview_node := Node3D.new()
	preview_node.name = "PreviewModel"
	callout_root.add_child(preview_node)

	if preview_type == "engine":
		mini_engine_preview = preview_node
		_build_mini_engine_preview(preview_node)
	elif preview_type == "solar":
		mini_solar_preview = preview_node
		_build_mini_solar_preview(preview_node)

	# 3. Cyan Leader Line connecting bracket to rocket component
	var leader := MeshInstance3D.new()
	var l_cyl := CylinderMesh.new()
	l_cyl.top_radius = 0.012
	l_cyl.bottom_radius = 0.012

	var delta_vec = target_world_pos - pos
	var dist = delta_vec.length()
	l_cyl.height = dist
	leader.mesh = l_cyl
	if delta_vec.length_squared() > 0.0001:
		var dir = delta_vec.normalized()
		var up = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		leader.transform = Transform3D().looking_at(dir, up)
		leader.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	leader.position = delta_vec * 0.5
	leader.material_override = mat_cyan
	callout_root.add_child(leader)

	callouts[id] = {
		"root": callout_root,
		"corner_bars": corner_bars,
		"leader": leader
	}

func _build_mini_engine_preview(parent: Node3D) -> void:
	var mat_bell := SpacecraftMaterials.get_mat("rocket_inconel_bell")
	var mat_copper := SpacecraftMaterials.get_mat("rocket_copper_chamber")
	var mat_steel := SpacecraftMaterials.get_mat("rocket_machined_steel")

	var offsets = [
		Vector3(-0.25, 0.0, -0.25),
		Vector3(0.25, 0.0, -0.25),
		Vector3(-0.25, 0.0, 0.25),
		Vector3(0.25, 0.0, 0.25)
	]

	for off in offsets:
		var ch := MeshInstance3D.new()
		var ch_cyl := CylinderMesh.new()
		ch_cyl.top_radius = 0.07
		ch_cyl.bottom_radius = 0.05
		ch_cyl.height = 0.12
		ch.mesh = ch_cyl
		ch.position = off + Vector3(0.0, 0.15, 0.0)
		ch.material_override = mat_copper
		parent.add_child(ch)

		var b := MeshInstance3D.new()
		var b_cyl := CylinderMesh.new()
		b_cyl.top_radius = 0.05
		b_cyl.bottom_radius = 0.16
		b_cyl.height = 0.3
		b.mesh = b_cyl
		b.position = off + Vector3(0.0, -0.06, 0.0)
		b.material_override = mat_bell
		parent.add_child(b)

	# Mini manifold ring
	var m_ring := MeshInstance3D.new()
	var mr_cyl := CylinderMesh.new()
	mr_cyl.top_radius = 0.4
	mr_cyl.bottom_radius = 0.4
	mr_cyl.height = 0.04
	m_ring.mesh = mr_cyl
	m_ring.position = Vector3(0.0, 0.22, 0.0)
	m_ring.material_override = mat_steel
	parent.add_child(m_ring)

func _build_mini_solar_preview(parent: Node3D) -> void:
	var mat_panel := SpacecraftMaterials.get_mat("solar_panel")
	var mat_steel := SpacecraftMaterials.get_mat("rocket_machined_steel")

	var panel := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(0.8, 0.55, 0.02)
	panel.mesh = p_box
	panel.material_override = mat_panel
	parent.add_child(panel)

	# Silver grid lines
	for bx in [-0.2, 0.0, 0.2]:
		var bar := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.015, 0.54, 0.025)
		bar.mesh = b_box
		bar.position = Vector3(bx, 0.0, 0.0)
		bar.material_override = mat_steel
		parent.add_child(bar)

func _create_wireframe_callout(id: String, pos: Vector3, w: float, h: float) -> void:
	var callout_root := Node3D.new()
	callout_root.name = "Callout_" + id
	callout_root.position = pos
	add_child(callout_root)

	var mat_cyan := SpacecraftMaterials.get_mat("hologram_bracket_cyan")
	var corner_bars := _create_bracket_geometry(callout_root, w, h, mat_cyan)

	callouts[id] = {
		"root": callout_root,
		"corner_bars": corner_bars,
		"leader": null
	}

func _create_bracket_geometry(parent: Node3D, w: float, h: float, mat: Material) -> Node3D:
	var hw = w * 0.5
	var hh = h * 0.5
	var arm_len = min(w, h) * 0.28
	var bar_th = 0.02

	var corner_bars := Node3D.new()
	corner_bars.name = "BracketBars"
	parent.add_child(corner_bars)

	var corners = [
		Vector2(-hw, hh),
		Vector2(hw, hh),
		Vector2(-hw, -hh),
		Vector2(hw, -hh)
	]

	for i in range(4):
		var pt = corners[i]
		var dir_x = 1.0 if pt.x < 0 else -1.0
		var dir_y = -1.0 if pt.y > 0 else 1.0

		var h_bar := MeshInstance3D.new()
		var hb_box := BoxMesh.new()
		hb_box.size = Vector3(arm_len, bar_th, bar_th)
		h_bar.mesh = hb_box
		h_bar.position = Vector3(pt.x + dir_x * arm_len * 0.5, pt.y, 0.0)
		h_bar.material_override = mat
		corner_bars.add_child(h_bar)

		var v_bar := MeshInstance3D.new()
		var vb_box := BoxMesh.new()
		vb_box.size = Vector3(bar_th, arm_len, bar_th)
		v_bar.mesh = vb_box
		v_bar.position = Vector3(pt.x, pt.y + dir_y * arm_len * 0.5, 0.0)
		v_bar.material_override = mat
		corner_bars.add_child(v_bar)

	return corner_bars

func highlight_subsystem(subsystem_id: String) -> void:
	active_highlight = subsystem_id
	var mat_cyan := SpacecraftMaterials.get_mat("hologram_bracket_cyan")
	var mat_amber := SpacecraftMaterials.get_mat("hologram_bracket_amber")

	for id in callouts:
		var c = callouts[id]
		var bars = c["corner_bars"] as Node3D
		var is_target = (id == subsystem_id)
		var target_mat = mat_amber if is_target else mat_cyan

		for child in bars.get_children():
			if child is MeshInstance3D:
				child.material_override = target_mat

		var leader = c.get("leader") as MeshInstance3D
		if leader:
			leader.material_override = target_mat

		if is_target:
			var tween := create_tween()
			tween.tween_property(bars, "scale", Vector3(1.2, 1.2, 1.2), 0.2)
			tween.tween_property(bars, "scale", Vector3(1.0, 1.0, 1.0), 0.2)

func animate_part_pulse(part_key: String) -> void:
	if not is_inside_tree():
		return
	var candidates: Array = []
	match part_key:
		"propulsion", "propulsion_engines", "stage1_engine":
			candidates = [engine_cluster_node, stage1_node]
		"grid_fins":
			candidates = [grid_fins_node]
		"solar_wings":
			candidates = [solar_wing_left, solar_wing_right]
		"probe_bus", "avionics", "structural":
			candidates = [probe_node, stage2_node]
		"fairing":
			candidates = [fairing_left, fairing_right]
		_:
			candidates = [stage1_node, stage2_node, probe_node]
	for raw_node in candidates:
		var node := raw_node as Node3D
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		var base_scale: Vector3 = node.get_meta("_pulse_base_scale", node.scale)
		node.set_meta("_pulse_base_scale", base_scale)
		if node.has_meta("_pulse_tween"):
			var old_tw = node.get_meta("_pulse_tween")
			if old_tw is Tween and old_tw.is_valid():
				old_tw.kill()
		node.scale = base_scale * 0.90
		var tw := create_tween()
		tw.tween_property(node, "scale", base_scale * 1.045, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "scale", base_scale, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		node.set_meta("_pulse_tween", tw)

func animate_attachment(part_key: String) -> void:
	var candidates: Array = []
	match part_key:
		"propulsion", "propulsion_engines", "stage1_engine":
			candidates = [engine_cluster_node, stage2_node]
		"solar_wings", "power":
			candidates = [solar_wing_left, solar_wing_right]
		"grid_fins":
			candidates = [grid_fins_node]
		"fairing":
			candidates = [fairing_left, fairing_right]
		_:
			candidates = [probe_node]
	for raw_node in candidates:
		var node := raw_node as Node3D
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		var target_position: Vector3 = node.position
		var target_scale: Vector3 = node.scale
		node.position = target_position + Vector3(0.0, 0.62, 0.0)
		node.scale = target_scale * 0.72
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(node, "position", target_position, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "scale", target_scale, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
