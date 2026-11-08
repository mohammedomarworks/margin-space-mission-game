class_name LunarFrontierWorld
extends Node3D

const LunarHopper = preload("res://margin/scripts/lunar_hopper.gd")

signal target_entered(target_id: String, target_name: String)
signal target_exited(target_id: String)
signal lander_beacon_entered()
signal lander_beacon_exited()

# Science Target Registry
var science_targets: Dictionary = {
	"target_alpha": {
		"id": "target_alpha",
		"name": "Cold-Trap Volatiles (Shackleton Rim)",
		"position": Vector3(45.0, 0.0, -50.0),
		"color": Color(0.15, 0.65, 1.0),
		"scanned": false,
		"node": null,
		"waypoint": null,
		"area": null
	},
	"target_beta": {
		"id": "target_beta",
		"name": "Pyroclastic Glass Outcrop (Shoemaker Ridge)",
		"position": Vector3(-55.0, 2.2, -30.0),
		"color": Color(1.0, 0.62, 0.12),
		"scanned": false,
		"node": null,
		"waypoint": null,
		"area": null
	},
	"target_gamma": {
		"id": "target_gamma",
		"name": "Impact Melt Breccia (Faustini Slope)",
		"position": Vector3(30.0, -1.2, 55.0),
		"color": Color(0.2, 0.95, 0.65),
		"scanned": false,
		"node": null,
		"waypoint": null,
		"area": null
	}
}

var terrain_body: StaticBody3D
var lander_node: Node3D
var lander_beacon_area: Area3D
var beacon_beam: MeshInstance3D
var earth_node: MeshInstance3D
var obstacles_root: Node3D
var active_target_in_range: String = ""
var is_player_in_beacon: bool = false

func _ready() -> void:
	_build_celestial_environment()
	_build_terrain()
	_build_lunar_lander()
	_build_science_targets()
	_build_crater_obstacles()

# --- Elevation Function for Lunar Terrain & Craters ---
func get_terrain_height(x: float, z: float) -> float:
	var dist_from_center: float = Vector2(x, z).length()

	# 1. Base rolling hills
	var h: float = sin(x * 0.04) * cos(z * 0.04) * 2.2 + sin(x * 0.08 + z * 0.07) * 1.0

	# 2. Central Landing Basin (Radius 16m is completely flat)
	if dist_from_center < 16.0:
		h *= (dist_from_center / 16.0) * (dist_from_center / 16.0)
	
	# 3. Shackleton Depression Crater (around 45, -50)
	var d_shack = Vector2(x - 45.0, z + 50.0).length()
	if d_shack < 26.0:
		h -= 3.5 * cos((d_shack / 26.0) * (PI * 0.5))

	# 4. Shoemaker Ridge (around -55, -30)
	var d_shoe = Vector2(x + 55.0, z + 30.0).length()
	if d_shoe < 28.0:
		h += 2.8 * cos((d_shoe / 28.0) * (PI * 0.5))

	# 5. Faustini Slope (around 30, 55)
	var d_faust = Vector2(x - 30.0, z - 55.0).length()
	if d_faust < 24.0:
		h -= 2.6 * cos((d_faust / 24.0) * (PI * 0.5))

	# 6. Perimeter Mountain Wall (Keeps player in bounds beyond 78m)
	if dist_from_center > 78.0:
		var edge_factor: float = clamp((dist_from_center - 78.0) / 22.0, 0.0, 1.0)
		h += edge_factor * edge_factor * 22.0

	return h

# --- Terrain Mesh & Collision Construction ---
func _build_terrain() -> void:
	terrain_body = StaticBody3D.new()
	terrain_body.name = "LunarTerrainBody"
	add_child(terrain_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var regolith_mat: StandardMaterial3D = StandardMaterial3D.new()
	regolith_mat.albedo_color = Color(0.44, 0.46, 0.50)
	regolith_mat.roughness = 0.94
	regolith_mat.metallic = 0.04
	st.set_material(regolith_mat)

	var size: float = 190.0
	var step: float = 3.2
	var half: float = size * 0.5
	var steps: int = int(size / step)

	for ix in range(steps):
		for iz in range(steps):
			var x0: float = -half + (ix * step)
			var x1: float = x0 + step
			var z0: float = -half + (iz * step)
			var z1: float = z0 + step

			var y00: float = get_terrain_height(x0, z0)
			var y10: float = get_terrain_height(x1, z0)
			var y01: float = get_terrain_height(x0, z1)
			var y11: float = get_terrain_height(x1, z1)

			var v00: Vector3 = Vector3(x0, y00, z0)
			var v10: Vector3 = Vector3(x1, y10, z0)
			var v01: Vector3 = Vector3(x0, y01, z1)
			var v11: Vector3 = Vector3(x1, y11, z1)

			# Tri 1: v00 -> v10 -> v01
			st.set_uv(Vector2(x0 * 0.05, z0 * 0.05))
			st.add_vertex(v00)
			st.set_uv(Vector2(x1 * 0.05, z0 * 0.05))
			st.add_vertex(v10)
			st.set_uv(Vector2(x0 * 0.05, z1 * 0.05))
			st.add_vertex(v01)

			# Tri 2: v10 -> v11 -> v01
			st.set_uv(Vector2(x1 * 0.05, z0 * 0.05))
			st.add_vertex(v10)
			st.set_uv(Vector2(x1 * 0.05, z1 * 0.05))
			st.add_vertex(v11)
			st.set_uv(Vector2(x0 * 0.05, z1 * 0.05))
			st.add_vertex(v01)

	st.generate_normals()
	var terrain_mesh: ArrayMesh = st.commit()

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.mesh = terrain_mesh
	mesh_inst.material_override = regolith_mat
	terrain_body.add_child(mesh_inst)

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(col_shape)

# --- Lunar Lander Base & Return Beacon ---
func _build_lunar_lander() -> void:
	lander_node = Node3D.new()
	lander_node.name = "LunarLanderBase"
	lander_node.position = Vector3(0.0, 0.0, 0.0)
	add_child(lander_node)

	var lander_body = StaticBody3D.new()
	lander_node.add_child(lander_body)

	# 1. Octagonal Gold Descent Stage
	var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.94, 0.76, 0.24)
	gold_mat.metallic = 0.9
	gold_mat.roughness = 0.25

	var descent_mesh: MeshInstance3D = MeshInstance3D.new()
	var oct_cyl: CylinderMesh = CylinderMesh.new()
	oct_cyl.radial_segments = 8
	oct_cyl.top_radius = 2.4
	oct_cyl.bottom_radius = 2.6
	oct_cyl.height = 1.8
	descent_mesh.mesh = oct_cyl
	descent_mesh.position = Vector3(0.0, 1.4, 0.0)
	descent_mesh.material_override = gold_mat
	lander_body.add_child(descent_mesh)

	# 2. Cylindrical White Ascent Stage
	var white_mat: StandardMaterial3D = StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.9, 0.92, 0.95)
	white_mat.metallic = 0.3
	white_mat.roughness = 0.35

	var ascent_mesh: MeshInstance3D = MeshInstance3D.new()
	var ascent_cyl: CylinderMesh = CylinderMesh.new()
	ascent_cyl.top_radius = 1.6
	ascent_cyl.bottom_radius = 1.8
	ascent_cyl.height = 2.2
	ascent_mesh.mesh = ascent_cyl
	ascent_mesh.position = Vector3(0.0, 3.4, 0.0)
	ascent_mesh.material_override = white_mat
	lander_body.add_child(ascent_mesh)

	# 3. Docking Port / Apex Dome
	var apex_mesh: MeshInstance3D = MeshInstance3D.new()
	var apex_dome: SphereMesh = SphereMesh.new()
	apex_dome.radius = 0.8
	apex_dome.height = 0.7
	apex_mesh.mesh = apex_dome
	apex_mesh.position = Vector3(0.0, 4.6, 0.0)
	apex_mesh.material_override = white_mat
	lander_body.add_child(apex_mesh)

	# 4. Lander Collision Shape
	var col: CollisionShape3D = CollisionShape3D.new()
	var col_cyl: CylinderShape3D = CylinderShape3D.new()
	col_cyl.radius = 2.7
	col_cyl.height = 4.8
	col.shape = col_cyl
	col.position = Vector3(0.0, 2.4, 0.0)
	lander_body.add_child(col)

	# 5. Landing Gear Struts & Footpads
	var leg_mat: StandardMaterial3D = StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.35, 0.38, 0.42)
	leg_mat.metallic = 0.9
	leg_mat.roughness = 0.3

	var leg_angles = [0.0, PI * 0.5, PI, PI * 1.5]
	for ang in leg_angles:
		var leg_offset = Vector3(cos(ang) * 2.8, 0.8, sin(ang) * 2.8)
		var leg: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.08
		cyl.height = 2.2
		leg.mesh = cyl
		leg.position = leg_offset
		leg.rotation = Vector3(sin(ang) * 0.4, 0.0, -cos(ang) * 0.4)
		leg.material_override = leg_mat
		lander_node.add_child(leg)

		var pad: MeshInstance3D = MeshInstance3D.new()
		var pad_cyl: CylinderMesh = CylinderMesh.new()
		pad_cyl.top_radius = 0.45
		pad_cyl.bottom_radius = 0.55
		pad_cyl.height = 0.12
		pad.mesh = pad_cyl
		pad.position = Vector3(cos(ang) * 3.6, 0.06, sin(ang) * 3.6)
		pad.material_override = gold_mat
		lander_node.add_child(pad)

	# 6. Glowing Return Beacon (Area3D + Beam + Light)
	lander_beacon_area = Area3D.new()
	lander_beacon_area.name = "ReturnBeaconArea"
	var beacon_col = CollisionShape3D.new()
	var beacon_cyl = CylinderShape3D.new()
	beacon_cyl.radius = 6.8
	beacon_cyl.height = 12.0
	beacon_col.shape = beacon_cyl
	beacon_col.position = Vector3(0.0, 4.0, 0.0)
	lander_beacon_area.add_child(beacon_col)
	lander_node.add_child(lander_beacon_area)

	lander_beacon_area.body_entered.connect(_on_beacon_body_entered)
	lander_beacon_area.body_exited.connect(_on_beacon_body_exited)

	# Vertical Skyward Cyan Beacon Beam
	beacon_beam = MeshInstance3D.new()
	var beam_cyl: CylinderMesh = CylinderMesh.new()
	beam_cyl.top_radius = 0.3
	beam_cyl.bottom_radius = 0.6
	beam_cyl.height = 55.0
	beacon_beam.mesh = beam_cyl
	beacon_beam.position = Vector3(0.0, 27.5, 0.0)

	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(0.15, 0.85, 1.0, 0.45)
	beacon_beam.material_override = beam_mat
	lander_node.add_child(beacon_beam)

	# Ground Glowing Circle Ring
	var ring_mesh: MeshInstance3D = MeshInstance3D.new()
	var ring_torus: TorusMesh = TorusMesh.new()
	ring_torus.inner_radius = 6.2
	ring_torus.outer_radius = 6.6
	ring_mesh.mesh = ring_torus
	ring_mesh.position = Vector3(0.0, 0.1, 0.0)
	ring_mesh.material_override = beam_mat
	lander_node.add_child(ring_mesh)

	# Beacon OmniLight
	var beacon_light = OmniLight3D.new()
	beacon_light.position = Vector3(0.0, 5.0, 0.0)
	beacon_light.light_color = Color(0.2, 0.85, 1.0)
	beacon_light.light_energy = 4.0
	beacon_light.omni_range = 14.0
	lander_node.add_child(beacon_light)

# --- 3 Distinct Science Collection Targets ---
func _build_science_targets() -> void:
	for target_key in science_targets.keys():
		var t_data = science_targets[target_key]
		var pos: Vector3 = t_data["position"]
		# Adjust pos.y to sit flush on terrain
		pos.y = get_terrain_height(pos.x, pos.z)
		t_data["position"] = pos

		var target_root = Node3D.new()
		target_root.name = "Target_" + t_data["id"]
		target_root.position = pos
		add_child(target_root)
		t_data["node"] = target_root

		# Physical Target Mesh (Deposits / Outcrop)
		var rock_body = StaticBody3D.new()
		target_root.add_child(rock_body)

		var rock_mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 1.3
		sphere.height = 1.8
		rock_mesh.mesh = sphere
		rock_mesh.position = Vector3(0.0, 0.7, 0.0)

		var rock_mat = StandardMaterial3D.new()
		rock_mat.albedo_color = t_data["color"] * 0.6
		rock_mat.emission_enabled = true
		rock_mat.emission = t_data["color"]
		rock_mat.emission_energy_multiplier = 0.8
		rock_mat.roughness = 0.5
		rock_mat.metallic = 0.6
		rock_mesh.material_override = rock_mat
		rock_body.add_child(rock_mesh)

		var rock_col = CollisionShape3D.new()
		var col_sph = SphereShape3D.new()
		col_sph.radius = 1.3
		rock_col.shape = col_sph
		rock_col.position = Vector3(0.0, 0.7, 0.0)
		rock_body.add_child(rock_col)

		# Floating Holographic Waypoint Pillar & Ring
		var waypoint_root = Node3D.new()
		waypoint_root.name = "Waypoint"
		waypoint_root.position = Vector3(0.0, 2.2, 0.0)
		target_root.add_child(waypoint_root)
		t_data["waypoint"] = waypoint_root

		var beam = MeshInstance3D.new()
		var beam_cyl = CylinderMesh.new()
		beam_cyl.top_radius = 0.15
		beam_cyl.bottom_radius = 0.35
		beam_cyl.height = 24.0
		beam.mesh = beam_cyl
		beam.position = Vector3(0.0, 12.0, 0.0)

		var beam_mat = StandardMaterial3D.new()
		beam_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.albedo_color = Color(t_data["color"].r, t_data["color"].g, t_data["color"].b, 0.55)
		beam.material_override = beam_mat
		waypoint_root.add_child(beam)

		var ring = MeshInstance3D.new()
		var ring_torus = TorusMesh.new()
		ring_torus.inner_radius = 1.2
		ring_torus.outer_radius = 1.5
		ring.mesh = ring_torus
		ring.position = Vector3(0.0, 0.4, 0.0)
		ring.material_override = beam_mat
		waypoint_root.add_child(ring)

		var light = OmniLight3D.new()
		light.position = Vector3(0.0, 1.5, 0.0)
		light.light_color = t_data["color"]
		light.light_energy = 2.5
		light.omni_range = 8.0
		waypoint_root.add_child(light)

		# Proximity Area3D
		var area = Area3D.new()
		area.name = "ProximityArea"
		var area_col = CollisionShape3D.new()
		var area_sph = SphereShape3D.new()
		area_sph.radius = 5.8
		area_col.shape = area_sph
		area_col.position = Vector3(0.0, 1.0, 0.0)
		area.add_child(area_col)
		target_root.add_child(area)
		t_data["area"] = area

		var tid: String = t_data["id"]
		var tname: String = t_data["name"]
		area.body_entered.connect(func(body):
			if body is LunarHopper and not t_data["scanned"]:
				active_target_in_range = tid
				emit_signal("target_entered", tid, tname)
		)
		area.body_exited.connect(func(body):
			if body is LunarHopper:
				if active_target_in_range == tid:
					active_target_in_range = ""
					emit_signal("target_exited", tid)
		)

func mark_target_scanned(target_id: String) -> void:
	if not science_targets.has(target_id):
		return
	var t_data = science_targets[target_id]
	t_data["scanned"] = true
	if t_data["waypoint"]:
		t_data["waypoint"].visible = false
	if active_target_in_range == target_id:
		active_target_in_range = ""
		emit_signal("target_exited", target_id)

func reset_science_targets() -> void:
	for target_key in science_targets.keys():
		var t_data = science_targets[target_key]
		t_data["scanned"] = false
		if t_data["waypoint"]:
			t_data["waypoint"].visible = true
	active_target_in_range = ""

# --- Crater Obstacles & Rock Hazards ---
func _build_crater_obstacles() -> void:
	obstacles_root = Node3D.new()
	obstacles_root.name = "CraterObstacles"
	add_child(obstacles_root)

	var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.32, 0.34, 0.38)
	rock_mat.roughness = 0.96
	rock_mat.metallic = 0.1

	# Seeded deterministic placement of 32 boulders
	var rock_positions = [
		Vector3(14.0, 0, -18.0), Vector3(-16.0, 0, -14.0), Vector3(22.0, 0, 16.0),
		Vector3(-24.0, 0, 20.0), Vector3(32.0, 0, -32.0), Vector3(-35.0, 0, -42.0),
		Vector3(48.0, 0, -22.0), Vector3(-45.0, 0, 12.0), Vector3(18.0, 0, 42.0),
		Vector3(-28.0, 0, 48.0), Vector3(52.0, 0, 28.0), Vector3(-58.0, 0, -15.0),
		Vector3(38.0, 0, -68.0), Vector3(-48.0, 0, -58.0), Vector3(12.0, 0, -75.0),
		Vector3(-18.0, 0, -72.0), Vector3(58.0, 0, -42.0), Vector3(-68.0, 0, 32.0),
		Vector3(42.0, 0, 68.0), Vector3(-52.0, 0, 62.0), Vector3(8.0, 0, 62.0),
		Vector3(-8.0, 0, 58.0), Vector3(64.0, 0, 8.0), Vector3(-62.0, 0, -52.0),
		Vector3(26.0, 0, -50.0), Vector3(-32.0, 0, -22.0), Vector3(15.0, 0, 28.0),
		Vector3(-12.0, 0, 35.0), Vector3(40.0, 0, 12.0), Vector3(-42.0, 0, -8.0),
		Vector3(28.0, 0, -12.0), Vector3(-20.0, 0, -38.0)
	]

	for i in range(rock_positions.size()):
		var p = rock_positions[i]
		p.y = get_terrain_height(p.x, p.z)

		var rock_body = StaticBody3D.new()
		rock_body.position = p
		obstacles_root.add_child(rock_body)

		var radius = 1.0 + ((i % 4) * 0.45)
		var height = radius * 1.5

		var mesh_inst = MeshInstance3D.new()
		var sph = SphereMesh.new()
		sph.radius = radius
		sph.height = height
		mesh_inst.mesh = sph
		mesh_inst.position = Vector3(0.0, height * 0.4, 0.0)
		mesh_inst.rotation = Vector3((i * 0.5), (i * 1.2), 0)
		mesh_inst.material_override = rock_mat
		rock_body.add_child(mesh_inst)

		var col = CollisionShape3D.new()
		var col_sph = SphereShape3D.new()
		col_sph.radius = radius * 0.95
		col.shape = col_sph
		col.position = Vector3(0.0, height * 0.4, 0.0)
		rock_body.add_child(col)

# --- Celestial Sky, Distant Earth & Solar Lighting ---
func _build_celestial_environment() -> void:
	# 1. Distant Blue Earth in Space
	earth_node = MeshInstance3D.new()
	var earth_sph = SphereMesh.new()
	earth_sph.radius = 18.0
	earth_sph.height = 36.0
	earth_node.mesh = earth_sph
	earth_node.position = Vector3(180.0, 120.0, -240.0)

	var earth_mat = StandardMaterial3D.new()
	earth_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	earth_mat.albedo_color = Color(0.12, 0.45, 0.92)
	earth_node.material_override = earth_mat
	add_child(earth_node)

	# 2. Grazing Lunar South Pole Sun (Elevation ~10°)
	var sun = DirectionalLight3D.new()
	sun.name = "LunarSun"
	sun.rotation_degrees = Vector3(-11.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func _on_beacon_body_entered(body: Node3D) -> void:
	if body is LunarHopper:
		is_player_in_beacon = true
		emit_signal("lander_beacon_entered")

func _on_beacon_body_exited(body: Node3D) -> void:
	if body is LunarHopper:
		is_player_in_beacon = false
		emit_signal("lander_beacon_exited")

func is_target_scanned(target_id: String) -> bool:
	if science_targets.has(target_id):
		return science_targets[target_id]["scanned"]
	return false

func get_scanned_count() -> int:
	var c: int = 0
	for k in science_targets.keys():
		if science_targets[k]["scanned"]:
			c += 1
	return c
