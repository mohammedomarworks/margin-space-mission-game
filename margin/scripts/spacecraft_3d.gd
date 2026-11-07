class_name Spacecraft3D
extends Node3D

# Mount nodes for the 9 subsystem categories
var _mounts: Dictionary = {}

# Current active component visual nodes
var _active_nodes: Dictionary = {}

# Category positions for camera focus
var _category_positions: Dictionary = {
	ComponentDatabase.Category.STRUCTURE: Vector3(0.0, 0.0, 0.0),
	ComponentDatabase.Category.POWER_GENERATION: Vector3(1.3, 0.0, 0.0),
	ComponentDatabase.Category.BATTERY: Vector3(0.0, 0.1, 0.35),
	ComponentDatabase.Category.PROPULSION: Vector3(0.0, -0.9, 0.0),
	ComponentDatabase.Category.COMMUNICATIONS: Vector3(0.0, 0.85, 0.2),
	ComponentDatabase.Category.COMPUTER: Vector3(-0.35, 0.1, 0.1),
	ComponentDatabase.Category.ADCS: Vector3(0.35, 0.1, -0.1),
	ComponentDatabase.Category.THERMAL: Vector3(0.0, 0.0, -0.55),
	ComponentDatabase.Category.INSTRUMENTS: Vector3(0.0, 0.95, -0.2)
}

func _init() -> void:
	_setup_mounts()

func _ready() -> void:
	if _mounts.is_empty():
		_setup_mounts()

func _setup_mounts() -> void:
	for cat in ComponentDatabase.Category.values():
		var cat_name: String = ComponentDatabase.get_category_id_string(cat)
		var mount := Node3D.new()
		mount.name = "Mount_" + cat_name
		add_child(mount)
		_mounts[cat] = mount

func update_spacecraft(components: Dictionary) -> void:
	for cat in components:
		update_component(cat, components[cat])

func update_component(category: ComponentDatabase.Category, component_id: String) -> void:
	if not _mounts.has(category):
		return
	
	var mount: Node3D = _mounts[category]
	
	# Clear old nodes in mount
	for child in mount.get_children():
		child.queue_free()
	
	var comp: Dictionary = ComponentDatabase.get_component(component_id)
	if comp.is_empty():
		return
	
	var variant: String = comp.get("visual_variant", "")
	var node: Node3D = _build_variant_mesh(category, variant)
	if node:
		mount.add_child(node)
		_active_nodes[category] = node
		
		# Animate a smooth assembly pop / scaling tween
		node.scale = Vector3(0.8, 0.8, 0.8)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "scale", Vector3.ONE, 0.35)

func get_category_position(category: ComponentDatabase.Category) -> Vector3:
	return _category_positions.get(category, Vector3.ZERO)

# --- Procedural Mesh Builders for Subsystems ---

func _build_variant_mesh(category: ComponentDatabase.Category, variant: String) -> Node3D:
	var root := Node3D.new()
	
	match category:
		ComponentDatabase.Category.STRUCTURE:
			_build_structure(root, variant)
		ComponentDatabase.Category.POWER_GENERATION:
			_build_power(root, variant)
		ComponentDatabase.Category.BATTERY:
			_build_battery(root, variant)
		ComponentDatabase.Category.PROPULSION:
			_build_propulsion(root, variant)
		ComponentDatabase.Category.COMMUNICATIONS:
			_build_comms(root, variant)
		ComponentDatabase.Category.COMPUTER:
			_build_computer(root, variant)
		ComponentDatabase.Category.ADCS:
			_build_adcs(root, variant)
		ComponentDatabase.Category.THERMAL:
			_build_thermal(root, variant)
		ComponentDatabase.Category.INSTRUMENTS:
			_build_instruments(root, variant)
	
	return root

func _build_structure(root: Node3D, variant: String) -> void:
	var mat_bus: StandardMaterial3D
	match variant:
		"aluminum_frame":
			mat_bus = SpacecraftMaterials.get_mat("aluminum")
		"carbon_fiber":
			mat_bus = SpacecraftMaterials.get_mat("carbon_fiber")
		"titanium_isogrid":
			mat_bus = SpacecraftMaterials.get_mat("titanium")
		_:
			mat_bus = SpacecraftMaterials.get_mat("aluminum")
	
	# Main central bus chassis
	var bus_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 1.1, 0.9)
	bus_mesh.mesh = box
	bus_mesh.material_override = mat_bus
	root.add_child(bus_mesh)
	
	# Top and Bottom Equipment Decks
	var top_deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(1.0, 0.05, 1.0)
	top_deck.mesh = deck_mesh
	top_deck.position = Vector3(0.0, 0.575, 0.0)
	top_deck.material_override = SpacecraftMaterials.get_mat("titanium")
	root.add_child(top_deck)
	
	var bot_deck := MeshInstance3D.new()
	bot_deck.mesh = deck_mesh
	bot_deck.position = Vector3(0.0, -0.575, 0.0)
	bot_deck.material_override = SpacecraftMaterials.get_mat("titanium")
	root.add_child(bot_deck)
	
	# Launch Vehicle Separation Ring at bottom
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.44
	ring.mesh = torus
	ring.position = Vector3(0.0, -0.62, 0.0)
	ring.material_override = SpacecraftMaterials.get_mat("gold_mli")
	root.add_child(ring)

func _build_power(root: Node3D, variant: String) -> void:
	match variant:
		"body_panels":
			# Solar cells mounted directly to bus faces (+X, -X, +Z)
			var side_offsets = [
				Vector3(0.46, 0.0, 0.0),
				Vector3(-0.46, 0.0, 0.0),
				Vector3(0.0, 0.0, 0.46)
			]
			var side_rotations = [
				Vector3(0.0, 90.0, 0.0),
				Vector3(0.0, 90.0, 0.0),
				Vector3(0.0, 0.0, 0.0)
			]
			for i in range(side_offsets.size()):
				var panel := MeshInstance3D.new()
				var pbox := BoxMesh.new()
				pbox.size = Vector3(0.75, 0.9, 0.02)
				panel.mesh = pbox
				panel.position = side_offsets[i]
				panel.rotation_degrees = side_rotations[i]
				panel.material_override = SpacecraftMaterials.get_mat("solar_panel")
				root.add_child(panel)
		
		"deployable_wings":
			# Articulated dual solar wings on +X and -X
			for side in [-1.0, 1.0]:
				var wing_root := Node3D.new()
				wing_root.position = Vector3(side * 0.5, 0.0, 0.0)
				root.add_child(wing_root)
				
				# Solar Array Drive Mechanism (SADM) gimbal cylinder
				var gimbal := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.06
				cyl.bottom_radius = 0.06
				cyl.height = 0.25
				gimbal.mesh = cyl
				gimbal.rotation_degrees = Vector3(0.0, 0.0, 90.0)
				gimbal.position = Vector3(side * 0.12, 0.0, 0.0)
				gimbal.material_override = SpacecraftMaterials.get_mat("titanium")
				wing_root.add_child(gimbal)
				
				# Solar wing panel (GaAs)
				var wing := MeshInstance3D.new()
				var wbox := BoxMesh.new()
				wbox.size = Vector3(1.2, 0.75, 0.03)
				wing.mesh = wbox
				wing.position = Vector3(side * 0.85, 0.0, 0.0)
				wing.material_override = SpacecraftMaterials.get_mat("solar_panel")
				wing_root.add_child(wing)
				
				# Wing frame/backing
				var backing := MeshInstance3D.new()
				var bbox := BoxMesh.new()
				bbox.size = Vector3(1.24, 0.79, 0.01)
				backing.mesh = bbox
				backing.position = Vector3(side * 0.85, 0.0, -0.018)
				backing.material_override = SpacecraftMaterials.get_mat("solar_back")
				wing_root.add_child(backing)
		
		"rollout_wings":
			# ROSA cylindrical canister hubs with unrolled blankets
			for side in [-1.0, 1.0]:
				var hub := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.08
				cyl.bottom_radius = 0.08
				cyl.height = 0.95
				hub.mesh = cyl
				hub.position = Vector3(side * 1.6, 0.0, 0.0)
				hub.material_override = SpacecraftMaterials.get_mat("titanium")
				root.add_child(hub)
				
				# Slim composite blanket
				var blanket := MeshInstance3D.new()
				var bbox := BoxMesh.new()
				bbox.size = Vector3(1.05, 0.88, 0.01)
				blanket.mesh = bbox
				blanket.position = Vector3(side * 1.05, 0.0, 0.0)
				blanket.material_override = SpacecraftMaterials.get_mat("solar_panel")
				root.add_child(blanket)

func _build_battery(root: Node3D, variant: String) -> void:
	var batt := MeshInstance3D.new()
	var box := BoxMesh.new()
	match variant:
		"batt_compact":
			box.size = Vector3(0.24, 0.18, 0.28)
			batt.mesh = box
			batt.position = Vector3(0.0, 0.1, 0.47)
			batt.material_override = SpacecraftMaterials.get_mat("avionics_box")
		"batt_dual":
			box.size = Vector3(0.38, 0.22, 0.28)
			batt.mesh = box
			batt.position = Vector3(0.0, 0.1, 0.47)
			batt.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
		"batt_solid":
			box.size = Vector3(0.32, 0.24, 0.3)
			batt.mesh = box
			batt.position = Vector3(0.0, 0.1, 0.47)
			batt.material_override = SpacecraftMaterials.get_mat("titanium")
	root.add_child(batt)
	
	# Battery status LED
	var led := MeshInstance3D.new()
	var lmesh := BoxMesh.new()
	lmesh.size = Vector3(0.04, 0.02, 0.02)
	led.mesh = lmesh
	led.position = batt.position + Vector3(0.08, 0.05, 0.15)
	led.material_override = SpacecraftMaterials.get_mat("led_cyan")
	root.add_child(led)

func _build_propulsion(root: Node3D, variant: String) -> void:
	match variant:
		"prop_coldgas":
			# Silver spherical bottle + 4 mini nozzles
			var tank := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.44
			tank.mesh = sphere
			tank.position = Vector3(0.0, -0.75, 0.0)
			tank.material_override = SpacecraftMaterials.get_mat("silver_mli")
			root.add_child(tank)
			
			for rot in [0.0, 90.0, 180.0, 270.0]:
				var noz := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.02
				cyl.bottom_radius = 0.04
				cyl.height = 0.08
				noz.mesh = cyl
				noz.position = Vector3(0.0, -0.92, 0.0)
				noz.rotation_degrees = Vector3(180.0, rot, 0.0)
				noz.material_override = SpacecraftMaterials.get_mat("aluminum")
				root.add_child(noz)
		
		"prop_hydrazine":
			# Central titanium tank with gold MLI wrap + bell engine
			var tank := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.32
			sphere.height = 0.64
			tank.mesh = sphere
			tank.position = Vector3(0.0, -0.68, 0.0)
			tank.material_override = SpacecraftMaterials.get_mat("gold_mli")
			root.add_child(tank)
			
			# Main engine nozzle (bell)
			var nozzle := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.06
			cyl.bottom_radius = 0.2
			cyl.height = 0.35
			nozzle.mesh = cyl
			nozzle.position = Vector3(0.0, -1.05, 0.0)
			nozzle.material_override = SpacecraftMaterials.get_mat("thruster_nozzle")
			root.add_child(nozzle)
			
			# 4 RCS Thruster Quad pods on bus corners
			for angle in [45.0, 135.0, 225.0, 315.0]:
				var rad = deg_to_rad(angle)
				var pod := MeshInstance3D.new()
				var pbox := BoxMesh.new()
				pbox.size = Vector3(0.08, 0.08, 0.08)
				pod.mesh = pbox
				pod.position = Vector3(sin(rad) * 0.52, -0.5, cos(rad) * 0.52)
				pod.material_override = SpacecraftMaterials.get_mat("titanium")
				root.add_child(pod)
		
		"prop_ion":
			# Xenon tank + cylindrical Hall effect thruster with blue plasma emitter ring
			var tank := MeshInstance3D.new()
			var cyl_tank := CylinderMesh.new()
			cyl_tank.top_radius = 0.2
			cyl_tank.bottom_radius = 0.2
			cyl_tank.height = 0.4
			tank.mesh = cyl_tank
			tank.position = Vector3(0.0, -0.72, 0.0)
			tank.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
			root.add_child(tank)
			
			var thruster := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.16
			cyl.bottom_radius = 0.16
			cyl.height = 0.22
			thruster.mesh = cyl
			thruster.position = Vector3(0.0, -0.98, 0.0)
			thruster.material_override = SpacecraftMaterials.get_mat("thruster_nozzle")
			root.add_child(thruster)
			
			var plasma := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.08
			torus.outer_radius = 0.14
			plasma.mesh = torus
			plasma.position = Vector3(0.0, -1.1, 0.0)
			plasma.material_override = SpacecraftMaterials.get_mat("led_cyan")
			root.add_child(plasma)

func _build_comms(root: Node3D, variant: String) -> void:
	match variant:
		"comm_patch":
			# Low-gain patch antennas on top deck
			var patch := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.18, 0.04, 0.18)
			patch.mesh = box
			patch.position = Vector3(0.2, 0.62, 0.2)
			patch.material_override = SpacecraftMaterials.get_mat("antenna_feed")
			root.add_child(patch)
		
		"comm_dish":
			# High-gain parabolic dish on gimbal mast
			var mast := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.03
			cyl.bottom_radius = 0.03
			cyl.height = 0.35
			mast.mesh = cyl
			mast.position = Vector3(0.2, 0.75, 0.2)
			mast.material_override = SpacecraftMaterials.get_mat("titanium")
			root.add_child(mast)
			
			var dish := MeshInstance3D.new()
			var cyl_dish := CylinderMesh.new()
			cyl_dish.top_radius = 0.4
			cyl_dish.bottom_radius = 0.1
			cyl_dish.height = 0.14
			dish.mesh = cyl_dish
			dish.position = Vector3(0.25, 0.98, 0.25)
			dish.rotation_degrees = Vector3(35.0, -25.0, 15.0)
			dish.material_override = SpacecraftMaterials.get_mat("antenna_reflector")
			root.add_child(dish)
			
			# Feed horn tripod
			var feed := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.04
			sphere.height = 0.08
			feed.mesh = sphere
			feed.position = dish.position + Vector3(0.08, 0.12, 0.08)
			feed.material_override = SpacecraftMaterials.get_mat("antenna_feed")
			root.add_child(feed)
		
		"comm_optical":
			# Gold-wire dish + optical laser telescope
			var dish := MeshInstance3D.new()
			var cyl_dish := CylinderMesh.new()
			cyl_dish.top_radius = 0.42
			cyl_dish.bottom_radius = 0.08
			cyl_dish.height = 0.12
			dish.mesh = cyl_dish
			dish.position = Vector3(0.25, 0.95, 0.25)
			dish.rotation_degrees = Vector3(25.0, -20.0, 0.0)
			dish.material_override = SpacecraftMaterials.get_mat("gold_mli")
			root.add_child(dish)
			
			var laser := MeshInstance3D.new()
			var cyl_laser := CylinderMesh.new()
			cyl_laser.top_radius = 0.06
			cyl_laser.bottom_radius = 0.06
			cyl_laser.height = 0.28
			laser.mesh = cyl_laser
			laser.position = Vector3(-0.25, 0.74, 0.2)
			laser.rotation_degrees = Vector3(25.0, -20.0, 0.0)
			laser.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
			root.add_child(laser)
			
			var lens := MeshInstance3D.new()
			var cyl_lens := CylinderMesh.new()
			cyl_lens.top_radius = 0.055
			cyl_lens.bottom_radius = 0.055
			cyl_lens.height = 0.02
			lens.mesh = cyl_lens
			lens.position = laser.position + Vector3(0.0, 0.14, 0.0)
			lens.material_override = SpacecraftMaterials.get_mat("sensor_lens")
			root.add_child(lens)

func _build_computer(root: Node3D, variant: String) -> void:
	var box := BoxMesh.new()
	var comp := MeshInstance3D.new()
	match variant:
		"comp_radhard":
			box.size = Vector3(0.22, 0.32, 0.18)
			comp.mesh = box
			comp.position = Vector3(-0.47, 0.15, 0.1)
			comp.material_override = SpacecraftMaterials.get_mat("avionics_box")
		"comp_vpx":
			box.size = Vector3(0.24, 0.26, 0.22)
			comp.mesh = box
			comp.position = Vector3(-0.47, 0.15, 0.1)
			comp.material_override = SpacecraftMaterials.get_mat("aluminum")
		"comp_edgeai":
			box.size = Vector3(0.2, 0.24, 0.2)
			comp.mesh = box
			comp.position = Vector3(-0.47, 0.15, 0.1)
			comp.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
	root.add_child(comp)
	
	# Status LED indicator row
	for i in range(3):
		var led := MeshInstance3D.new()
		var lmesh := BoxMesh.new()
		lmesh.size = Vector3(0.015, 0.015, 0.015)
		led.mesh = lmesh
		led.position = comp.position + Vector3(-0.11, 0.08 - i * 0.06, 0.04)
		led.material_override = SpacecraftMaterials.get_mat("led_green" if i < 2 else "led_amber")
		root.add_child(led)

func _build_adcs(root: Node3D, variant: String) -> void:
	match variant:
		"adcs_3wheels":
			# 3 orthogonal reaction wheel discs
			var wheel_axes = [
				Vector3(0.0, 0.0, 0.0),
				Vector3(90.0, 0.0, 0.0),
				Vector3(0.0, 0.0, 90.0)
			]
			for i in range(3):
				var wheel := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.09
				cyl.bottom_radius = 0.09
				cyl.height = 0.04
				wheel.mesh = cyl
				wheel.position = Vector3(0.47, -0.15 + i * 0.12, -0.1)
				wheel.rotation_degrees = wheel_axes[i]
				wheel.material_override = SpacecraftMaterials.get_mat("titanium")
				root.add_child(wheel)
		
		"adcs_pyramid":
			# 4 wheels in pyramid base
			for i in range(4):
				var angle = i * 90.0
				var rad = deg_to_rad(angle)
				var wheel := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.075
				cyl.bottom_radius = 0.075
				cyl.height = 0.035
				wheel.mesh = cyl
				wheel.position = Vector3(0.47, 0.0, -0.1) + Vector3(0.0, sin(rad) * 0.1, cos(rad) * 0.1)
				wheel.rotation_degrees = Vector3(25.0, angle, 0.0)
				wheel.material_override = SpacecraftMaterials.get_mat("titanium")
				root.add_child(wheel)
			
			# Dual Star Trackers (angled optical tubes)
			for j in [-1.0, 1.0]:
				var tracker := MeshInstance3D.new()
				var cyl_t := CylinderMesh.new()
				cyl_t.top_radius = 0.03
				cyl_t.bottom_radius = 0.04
				cyl_t.height = 0.16
				tracker.mesh = cyl_t
				tracker.position = Vector3(0.35, 0.65, j * 0.25)
				tracker.rotation_degrees = Vector3(j * 35.0, 0.0, 25.0)
				tracker.material_override = SpacecraftMaterials.get_mat("sensor_body")
				root.add_child(tracker)
		
		"adcs_cmg":
			# CMG spherical rotors
			for i in range(2):
				var cmg := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = 0.11
				sphere.height = 0.22
				cmg.mesh = sphere
				cmg.position = Vector3(0.47, -0.1 + i * 0.25, -0.1)
				cmg.material_override = SpacecraftMaterials.get_mat("silver_mli")
				root.add_child(cmg)

func _build_thermal(root: Node3D, variant: String) -> void:
	match variant:
		"thermal_gold_foil":
			# Gold MLI blanket panels on -Z face and edges
			var blanket := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.85, 1.05, 0.04)
			blanket.mesh = box
			blanket.position = Vector3(0.0, 0.0, -0.47)
			blanket.material_override = SpacecraftMaterials.get_mat("gold_mli")
			root.add_child(blanket)
		
		"thermal_radiator_panels":
			# White quartz ceramic radiator plate with heat pipes
			var rad := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.88, 1.08, 0.03)
			rad.mesh = box
			rad.position = Vector3(0.0, 0.0, -0.47)
			rad.material_override = SpacecraftMaterials.get_mat("radiator_white")
			root.add_child(rad)
			
			# Ammonia heat pipe lines
			for y in [-0.3, 0.0, 0.3]:
				var pipe := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.012
				cyl.bottom_radius = 0.012
				cyl.height = 0.82
				pipe.mesh = cyl
				pipe.position = Vector3(0.0, y, -0.49)
				pipe.rotation_degrees = Vector3(0.0, 0.0, 90.0)
				pipe.material_override = SpacecraftMaterials.get_mat("titanium")
				root.add_child(pipe)
		
		"thermal_cryo_louvers":
			# Mechanical louver slats + cryo-cooler cylinder
			var frame := MeshInstance3D.new()
			var fbox := BoxMesh.new()
			fbox.size = Vector3(0.88, 1.08, 0.03)
			frame.mesh = fbox
			frame.position = Vector3(0.0, 0.0, -0.47)
			frame.material_override = SpacecraftMaterials.get_mat("aluminum")
			root.add_child(frame)
			
			# Louver blades
			for i in range(5):
				var blade := MeshInstance3D.new()
				var bbox := BoxMesh.new()
				bbox.size = Vector3(0.78, 0.08, 0.01)
				blade.mesh = bbox
				blade.position = Vector3(0.0, -0.38 + i * 0.19, -0.49)
				blade.rotation_degrees = Vector3(30.0, 0.0, 0.0)
				blade.material_override = SpacecraftMaterials.get_mat("silver_mli")
				root.add_child(blade)
			
			# Stirling cryo-cooler cylinder
			var cryo := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.08
			cyl.bottom_radius = 0.08
			cyl.height = 0.28
			cryo.mesh = cyl
			cryo.position = Vector3(0.0, 0.7, -0.35)
			cryo.material_override = SpacecraftMaterials.get_mat("titanium")
			root.add_child(cryo)

func _build_instruments(root: Node3D, variant: String) -> void:
	match variant:
		"inst_lp_neutron":
			# Lunar Prospector Neutron Spectrometer: Dual He-3 tubes + pre-amp
			var base_box := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.45, 0.12, 0.28)
			base_box.mesh = box
			base_box.position = Vector3(0.0, 0.66, -0.15)
			base_box.material_override = SpacecraftMaterials.get_mat("sensor_body")
			root.add_child(base_box)
			
			# 2 Helium-3 proportional counter tubes pointing nadir
			for x in [-0.14, 0.14]:
				var tube := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.05
				cyl.bottom_radius = 0.05
				cyl.height = 0.36
				tube.mesh = cyl
				tube.position = Vector3(x, 0.86, -0.15)
				tube.material_override = SpacecraftMaterials.get_mat("titanium")
				root.add_child(tube)
				
				# Cadmium/polyethylene moderator wrapping
				var wrap := MeshInstance3D.new()
				var wcyl := CylinderMesh.new()
				wcyl.top_radius = 0.055
				wcyl.bottom_radius = 0.055
				wcyl.height = 0.18
				wrap.mesh = wcyl
				wrap.position = Vector3(x, 0.86, -0.15)
				wrap.material_override = SpacecraftMaterials.get_mat("gold_mli")
				root.add_child(wrap)
		
		"inst_lend_gamma":
			# LEND heritage: Collimated Germanium detector + neutron sensor cluster
			var collimator := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.16
			cyl.bottom_radius = 0.12
			cyl.height = 0.42
			collimator.mesh = cyl
			collimator.position = Vector3(0.0, 0.82, -0.15)
			collimator.material_override = SpacecraftMaterials.get_mat("sensor_body")
			root.add_child(collimator)
			
			# Germanium sensor core lens
			var core := MeshInstance3D.new()
			var core_cyl := CylinderMesh.new()
			core_cyl.top_radius = 0.11
			core_cyl.bottom_radius = 0.11
			core_cyl.height = 0.04
			core.mesh = core_cyl
			core.position = Vector3(0.0, 1.04, -0.15)
			core.material_override = SpacecraftMaterials.get_mat("sensor_lens")
			root.add_child(core)
			
			# Shielding bands
			var band := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.14
			torus.outer_radius = 0.17
			band.mesh = torus
			band.position = Vector3(0.0, 0.85, -0.15)
			band.material_override = SpacecraftMaterials.get_mat("gold_mli")
			root.add_child(band)
		
		"inst_sar_radar":
			# SAR radar feed horn antenna array + infrared spectrometer aperture
			var antenna := MeshInstance3D.new()
			var abox := BoxMesh.new()
			abox.size = Vector3(0.68, 0.08, 0.45)
			antenna.mesh = abox
			antenna.position = Vector3(0.0, 0.68, -0.15)
			antenna.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
			root.add_child(antenna)
			
			# Dual radar feed horns
			for x in [-0.2, 0.2]:
				var horn := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.09
				cyl.bottom_radius = 0.03
				cyl.height = 0.25
				horn.mesh = cyl
				horn.position = Vector3(x, 0.84, -0.15)
				horn.material_override = SpacecraftMaterials.get_mat("antenna_feed")
				root.add_child(horn)
			
			# Infrared Imaging Spectrometer lens barrel
			var ir := MeshInstance3D.new()
			var cyl_ir := CylinderMesh.new()
			cyl_ir.top_radius = 0.075
			cyl_ir.bottom_radius = 0.075
			cyl_ir.height = 0.3
			ir.mesh = cyl_ir
			ir.position = Vector3(0.0, 0.86, -0.15)
			ir.material_override = SpacecraftMaterials.get_mat("sensor_lens")
			root.add_child(ir)
		
		"inst_radiometer":
			# Optical Multi-Spectral Climate Radiometer housing + nadir telescope
			var rbox := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.52, 0.18, 0.32)
			rbox.mesh = b
			rbox.position = Vector3(0.0, 0.70, -0.15)
			rbox.material_override = SpacecraftMaterials.get_mat("sensor_body")
			root.add_child(rbox)
			
			var telescope := MeshInstance3D.new()
			var tcyl := CylinderMesh.new()
			tcyl.top_radius = 0.12
			tcyl.bottom_radius = 0.09
			tcyl.height = 0.28
			telescope.mesh = tcyl
			telescope.position = Vector3(0.0, 0.90, -0.15)
			telescope.material_override = SpacecraftMaterials.get_mat("sensor_lens")
			root.add_child(telescope)
		
		"inst_ghg_spectrometer":
			# Greenhouse Gas Grating Spectrometer body + dual optical collimator slits
			var sbox := MeshInstance3D.new()
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.60, 0.22, 0.38)
			sbox.mesh = b2
			sbox.position = Vector3(0.0, 0.72, -0.15)
			sbox.material_override = SpacecraftMaterials.get_mat("gold_mli")
			root.add_child(sbox)
			
			for x in [-0.15, 0.15]:
				var slit := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.06
				c.bottom_radius = 0.06
				c.height = 0.24
				slit.mesh = c
				slit.position = Vector3(x, 0.92, -0.15)
				slit.material_override = SpacecraftMaterials.get_mat("sensor_lens")
				root.add_child(slit)
		
		"inst_ice_sar":
			# SAR Interferometric Antenna Boom
			var mast := MeshInstance3D.new()
			var mbox := BoxMesh.new()
			mbox.size = Vector3(0.85, 0.06, 0.18)
			mast.mesh = mbox
			mast.position = Vector3(0.0, 0.75, -0.15)
			mast.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
			root.add_child(mast)
			
			for x in [-0.35, 0.35]:
				var horn := MeshInstance3D.new()
				var hc := CylinderMesh.new()
				hc.top_radius = 0.08
				hc.bottom_radius = 0.03
				hc.height = 0.20
				horn.mesh = hc
				horn.position = Vector3(x, 0.88, -0.15)
				horn.material_override = SpacecraftMaterials.get_mat("antenna_feed")
				root.add_child(horn)
		
		"inst_plasma_boom":
			# DSCOVR-inspired Deployable Magnetometer Boom & Faraday Cup Plasma Sensor
			var boom := MeshInstance3D.new()
			var bcyl := CylinderMesh.new()
			bcyl.top_radius = 0.02
			bcyl.bottom_radius = 0.03
			bcyl.height = 1.40
			boom.mesh = bcyl
			boom.position = Vector3(0.0, 1.20, -0.20)
			boom.rotation_degrees = Vector3(25.0, 0.0, 0.0)
			boom.material_override = SpacecraftMaterials.get_mat("carbon_fiber")
			root.add_child(boom)
			
			# Fluxgate Magnetometer sensor head at tip
			var mag_head := MeshInstance3D.new()
			var msphere := SphereMesh.new()
			msphere.radius = 0.06
			msphere.height = 0.12
			mag_head.mesh = msphere
			mag_head.position = Vector3(0.0, 1.80, -0.48)
			mag_head.material_override = SpacecraftMaterials.get_mat("gold_mli")
			root.add_child(mag_head)
			
			# Faraday Cup Solar Wind Plasma Analyzer
			var cup := MeshInstance3D.new()
			var ccyl := CylinderMesh.new()
			ccyl.top_radius = 0.08
			ccyl.bottom_radius = 0.05
			ccyl.height = 0.16
			cup.mesh = ccyl
			cup.position = Vector3(0.0, 0.78, 0.22)
			cup.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
			cup.material_override = SpacecraftMaterials.get_mat("sensor_lens")
			root.add_child(cup)
