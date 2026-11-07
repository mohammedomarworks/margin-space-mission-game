class_name Helios4Rocket3D
extends Node3D

# ==============================================================================
# HELIOS-4 PROCEDURAL 3D MODULAR LAUNCH VEHICLE & PROBE
# Full interactive 3D assembly:
# - Stage 1: Cluster engines, booster fuel tank, aerodynamic grid fins
# - Stage 2: Interstage truss, vacuum engine, upper propellant tank
# - Stage 3 / Payload: Dual split fairing halves, HELIOS-4 solar sentinel bus,
#   gold MLI, articulated GaAs solar wings, high-gain dish, magnetometer boom
# ==============================================================================

const SpacecraftMaterials = preload("res://margin/materials/spacecraft_materials.gd")

var fairing_open: bool = true

# Node references
var stage1_node: Node3D = null
var stage2_node: Node3D = null
var probe_node: Node3D = null
var fairing_left: Node3D = null
var fairing_right: Node3D = null
var solar_wing_left: Node3D = null
var solar_wing_right: Node3D = null
var mag_boom: Node3D = null

func _ready() -> void:
	rebuild_vehicle()

func rebuild_vehicle() -> void:
	for child in get_children():
		child.queue_free()
		
	# --- BASE LAUNCH TABLE & GANTRY ---
	_build_gantry_scaffolding()
	
	# --- STAGE 1: BOOSTER CORE ---
	stage1_node = Node3D.new()
	stage1_node.name = "Stage1_Booster"
	add_child(stage1_node)
	_build_stage1(stage1_node)
	
	# --- STAGE 2: UPPER STAGE ---
	stage2_node = Node3D.new()
	stage2_node.name = "Stage2_Upper"
	stage2_node.position = Vector3(0.0, 7.8, 0.0)
	add_child(stage2_node)
	_build_stage2(stage2_node)
	
	# --- STAGE 3: HELIOS-4 PROBE ---
	probe_node = Node3D.new()
	probe_node.name = "Stage3_Probe"
	probe_node.position = Vector3(0.0, 11.8, 0.0)
	add_child(probe_node)
	_build_probe(probe_node)
	
	# --- SPLIT PAYLOAD FAIRING ---
	_build_fairings()
	update_fairing_pose(fairing_open)

func _build_gantry_scaffolding() -> void:
	var gantry := Node3D.new()
	gantry.name = "GantryStructure"
	add_child(gantry)
	
	var mat_yellow := StandardMaterial3D.new()
	mat_yellow.albedo_color = Color(0.92, 0.65, 0.12, 1) # Construction yellow
	mat_yellow.metallic = 0.6
	mat_yellow.roughness = 0.5
	
	var mat_steel := StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.2, 0.22, 0.26, 1)
	mat_steel.metallic = 0.8
	mat_steel.roughness = 0.4
	
	# Launch Table / Base ring
	var table := MeshInstance3D.new()
	var t_cyl := CylinderMesh.new()
	t_cyl.top_radius = 2.4
	t_cyl.bottom_radius = 2.8
	t_cyl.height = 1.0
	table.mesh = t_cyl
	table.position = Vector3(0.0, -0.5, 0.0)
	table.material_override = mat_steel
	gantry.add_child(table)
	
	# Four vertical gantry towers
	for angle in [45.0, 135.0, 225.0, 315.0]:
		var rad = deg_to_rad(angle)
		var tower := MeshInstance3D.new()
		var t_box := BoxMesh.new()
		t_box.size = Vector3(0.4, 16.0, 0.4)
		tower.mesh = t_box
		tower.position = Vector3(cos(rad) * 3.6, 7.5, sin(rad) * 3.6)
		tower.material_override = mat_yellow
		gantry.add_child(tower)
		
		# Cross struts
		for h in [3.0, 7.0, 11.0, 14.5]:
			var walkway := MeshInstance3D.new()
			var w_box := BoxMesh.new()
			w_box.size = Vector3(1.2, 0.15, 0.8)
			walkway.mesh = w_box
			walkway.position = Vector3(cos(rad) * 2.8, h, sin(rad) * 2.8)
			walkway.rotation.y = -rad
			walkway.material_override = mat_steel
			gantry.add_child(walkway)

func _build_stage1(parent: Node3D) -> void:
	var mat_booster := StandardMaterial3D.new()
	mat_booster.albedo_color = Color(0.92, 0.94, 0.96, 1) # White aerospace tank
	mat_booster.roughness = 0.35
	mat_booster.metallic = 0.2
	
	# Main booster tank
	var tank := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.2
	cyl.height = 7.0
	tank.mesh = cyl
	tank.position = Vector3(0.0, 3.8, 0.0)
	tank.material_override = mat_booster
	parent.add_child(tank)
	
	# 4x Aerodynamic Grid Fins at base
	var mat_fin := StandardMaterial3D.new()
	mat_fin.albedo_color = Color(0.18, 0.2, 0.24, 1)
	mat_fin.metallic = 0.8
	
	for a in [0.0, 90.0, 180.0, 270.0]:
		var rad = deg_to_rad(a)
		var fin := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(0.1, 0.6, 0.7)
		fin.mesh = f_box
		fin.position = Vector3(cos(rad) * 1.45, 1.2, sin(rad) * 1.45)
		fin.rotation.y = -rad
		fin.material_override = mat_fin
		parent.add_child(fin)
		
	# 4x Booster Rocket Engine Bells
	var mat_nozzle := StandardMaterial3D.new()
	mat_nozzle.albedo_color = Color(0.15, 0.16, 0.18, 1)
	mat_nozzle.metallic = 0.9
	mat_nozzle.roughness = 0.3
	
	for offset in [Vector3(-0.45, 0, -0.45), Vector3(0.45, 0, -0.45), Vector3(-0.45, 0, 0.45), Vector3(0.45, 0, 0.45)]:
		var bell := MeshInstance3D.new()
		var n_cyl := CylinderMesh.new()
		n_cyl.top_radius = 0.2
		n_cyl.bottom_radius = 0.38
		n_cyl.height = 0.8
		bell.mesh = n_cyl
		bell.position = offset + Vector3(0.0, -0.1, 0.0)
		bell.material_override = mat_nozzle
		parent.add_child(bell)

func _build_stage2(parent: Node3D) -> void:
	# Interstage lattice truss (open grid connecting stage 1 to stage 2)
	var mat_truss := StandardMaterial3D.new()
	mat_truss.albedo_color = Color(0.25, 0.27, 0.3, 1)
	mat_truss.metallic = 0.7
	
	var interstage := MeshInstance3D.new()
	var i_cyl := CylinderMesh.new()
	i_cyl.top_radius = 1.15
	i_cyl.bottom_radius = 1.18
	i_cyl.height = 1.2
	interstage.mesh = i_cyl
	interstage.position = Vector3(0.0, 0.6, 0.0)
	interstage.material_override = mat_truss
	parent.add_child(interstage)
	
	# Stage 2 Vacuum Engine inside interstage
	var vac_nozzle := MeshInstance3D.new()
	var v_cyl := CylinderMesh.new()
	v_cyl.top_radius = 0.15
	v_cyl.bottom_radius = 0.55
	v_cyl.height = 0.95
	vac_nozzle.mesh = v_cyl
	vac_nozzle.position = Vector3(0.0, 0.5, 0.0)
	vac_nozzle.material_override = SpacecraftMaterials.get_mat("engine_nozzle")
	parent.add_child(vac_nozzle)
	
	# Stage 2 Propellant Tank
	var mat_s2 := StandardMaterial3D.new()
	mat_s2.albedo_color = Color(0.88, 0.9, 0.94, 1)
	mat_s2.metallic = 0.3
	
	var s2_tank := MeshInstance3D.new()
	var s2_cyl := CylinderMesh.new()
	s2_cyl.top_radius = 1.1
	s2_cyl.bottom_radius = 1.1
	s2_cyl.height = 2.4
	s2_tank.mesh = s2_cyl
	s2_tank.position = Vector3(0.0, 2.4, 0.0)
	s2_tank.material_override = mat_s2
	parent.add_child(s2_tank)

func _build_probe(parent: Node3D) -> void:
	# Payload Adapter Cone
	var adapter := MeshInstance3D.new()
	var a_cyl := CylinderMesh.new()
	a_cyl.top_radius = 0.75
	a_cyl.bottom_radius = 1.05
	a_cyl.height = 0.6
	adapter.mesh = a_cyl
	adapter.position = Vector3(0.0, 0.3, 0.0)
	adapter.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
	parent.add_child(adapter)
	
	# HELIOS-4 Spacecraft Bus: Gold Multi-Layer Insulation (MLI)
	var bus := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(1.1, 1.2, 1.1)
	bus.mesh = b_box
	bus.position = Vector3(0.0, 1.2, 0.0)
	bus.material_override = SpacecraftMaterials.get_mat("gold_mli")
	parent.add_child(bus)
	
	# Deployable Solar Wings
	solar_wing_left = Node3D.new()
	solar_wing_left.position = Vector3(-0.6, 1.2, 0.0)
	parent.add_child(solar_wing_left)
	_build_solar_panel(solar_wing_left, -1.0)
	
	solar_wing_right = Node3D.new()
	solar_wing_right.position = Vector3(0.6, 1.2, 0.0)
	parent.add_child(solar_wing_right)
	_build_solar_panel(solar_wing_right, 1.0)
	
	# High-Gain Reflector Dish on Gimbal
	var dish := MeshInstance3D.new()
	var d_sph := SphereMesh.new()
	d_sph.radius = 0.5
	d_sph.height = 0.25
	dish.mesh = d_sph
	dish.position = Vector3(0.0, 2.0, 0.3)
	dish.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	dish.material_override = SpacecraftMaterials.get_mat("dish_reflector")
	parent.add_child(dish)
	
	# Feed horn
	var feed := MeshInstance3D.new()
	var f_cyl := CylinderMesh.new()
	f_cyl.top_radius = 0.03
	f_cyl.bottom_radius = 0.03
	f_cyl.height = 0.35
	feed.mesh = f_cyl
	feed.position = Vector3(0.0, 2.2, 0.45)
	feed.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	feed.material_override = SpacecraftMaterials.get_mat("antenna_feed")
	parent.add_child(feed)
	
	# Long Magnetometer Boom (pointing sunward)
	mag_boom = Node3D.new()
	mag_boom.position = Vector3(0.0, 1.8, -0.4)
	parent.add_child(mag_boom)
	
	var boom_rod := MeshInstance3D.new()
	var r_cyl := CylinderMesh.new()
	r_cyl.top_radius = 0.02
	r_cyl.bottom_radius = 0.03
	r_cyl.height = 2.0
	boom_rod.mesh = r_cyl
	boom_rod.position = Vector3(0.0, 0.8, -0.5)
	boom_rod.rotation_degrees = Vector3(35.0, 0.0, 0.0)
	boom_rod.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
	mag_boom.add_child(boom_rod)
	
	# Triaxial Fluxgate Sensor Head
	var mag_head := MeshInstance3D.new()
	var m_sph := SphereMesh.new()
	m_sph.radius = 0.08
	m_sph.height = 0.16
	mag_head.mesh = m_sph
	mag_head.position = Vector3(0.0, 1.6, -1.05)
	mag_head.material_override = SpacecraftMaterials.get_mat("gold_mli")
	mag_boom.add_child(mag_head)
	
	# Faraday Cup Plasma Analyzer
	var cup := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 0.1
	c_cyl.bottom_radius = 0.06
	c_cyl.height = 0.22
	cup.mesh = c_cyl
	cup.position = Vector3(0.35, 1.5, -0.55)
	cup.rotation_degrees = Vector3(45.0, 0.0, 0.0)
	cup.material_override = SpacecraftMaterials.get_mat("sensor_lens")
	parent.add_child(cup)

func _build_solar_panel(parent: Node3D, dir: float) -> void:
	var hinge := MeshInstance3D.new()
	var h_cyl := CylinderMesh.new()
	h_cyl.top_radius = 0.04
	h_cyl.bottom_radius = 0.04
	h_cyl.height = 0.3
	hinge.mesh = h_cyl
	hinge.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	hinge.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
	parent.add_child(hinge)
	
	# 2-panel articulated solar wing
	for i in [1, 2]:
		var panel := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(0.95, 0.8, 0.04)
		panel.mesh = p_box
		panel.position = Vector3(dir * (i * 1.0 - 0.4), 0.0, 0.0)
		panel.material_override = SpacecraftMaterials.get_mat("solar_cells")
		parent.add_child(panel)

func _build_fairings() -> void:
	var mat_fairing := StandardMaterial3D.new()
	mat_fairing.albedo_color = Color(0.94, 0.95, 0.98, 0.85)
	mat_fairing.metallic = 0.3
	mat_fairing.roughness = 0.3
	mat_fairing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	fairing_left = Node3D.new()
	fairing_left.name = "FairingHalf_Left"
	fairing_left.position = Vector3(0.0, 11.5, 0.0)
	add_child(fairing_left)
	
	var shell_l := MeshInstance3D.new()
	var c_l := CylinderMesh.new()
	c_l.top_radius = 0.4
	c_l.bottom_radius = 1.2
	c_l.height = 4.2
	shell_l.mesh = c_l
	shell_l.position = Vector3(-0.6, 2.1, 0.0)
	shell_l.material_override = mat_fairing
	fairing_left.add_child(shell_l)
	
	fairing_right = Node3D.new()
	fairing_right.name = "FairingHalf_Right"
	fairing_right.position = Vector3(0.0, 11.5, 0.0)
	add_child(fairing_right)
	
	var shell_r := MeshInstance3D.new()
	var c_r := CylinderMesh.new()
	c_r.top_radius = 0.4
	c_r.bottom_radius = 1.2
	c_r.height = 4.2
	shell_r.mesh = c_r
	shell_r.position = Vector3(0.6, 2.1, 0.0)
	shell_r.material_override = mat_fairing
	fairing_right.add_child(shell_r)

func update_fairing_pose(is_open: bool) -> void:
	fairing_open = is_open
	if not fairing_left or not fairing_right:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	if is_open:
		# Swing fairing halves open like clam-shell
		tween.tween_property(fairing_left, "rotation_degrees:z", 24.0, 0.4)
		tween.tween_property(fairing_left, "position:x", -1.1, 0.4)
		tween.tween_property(fairing_right, "rotation_degrees:z", -24.0, 0.4)
		tween.tween_property(fairing_right, "position:x", 1.1, 0.4)
	else:
		# Close fairing halves snugly over probe
		tween.tween_property(fairing_left, "rotation_degrees:z", 0.0, 0.4)
		tween.tween_property(fairing_left, "position:x", 0.0, 0.4)
		tween.tween_property(fairing_right, "rotation_degrees:z", 0.0, 0.4)
		tween.tween_property(fairing_right, "position:x", 0.0, 0.4)
