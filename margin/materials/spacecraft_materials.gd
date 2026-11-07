class_name SpacecraftMaterials
extends RefCounted

static var _materials: Dictionary = {}

static func get_mat(name: String) -> StandardMaterial3D:
	if _materials.has(name):
		return _materials[name]
	
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.35
	mat.metallic = 0.8
	
	match name:
		"gold_mli":
			mat.albedo_color = Color(0.96, 0.74, 0.18)
			mat.metallic = 0.94
			mat.roughness = 0.22
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.8
			mat.clearcoat_roughness = 0.15
			mat.rim_enabled = true
			mat.rim = 0.35
			mat.rim_tint = 0.5
		
		"silver_mli":
			mat.albedo_color = Color(0.90, 0.92, 0.95)
			mat.metallic = 0.96
			mat.roughness = 0.18
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.7
			mat.clearcoat_roughness = 0.15
		
		"carbon_fiber":
			mat.albedo_color = Color(0.12, 0.13, 0.16)
			mat.metallic = 0.4
			mat.roughness = 0.45
			mat.rim_enabled = true
			mat.rim = 0.2
		
		"titanium":
			mat.albedo_color = Color(0.70, 0.72, 0.76)
			mat.metallic = 0.90
			mat.roughness = 0.30
		
		"aluminum":
			mat.albedo_color = Color(0.80, 0.82, 0.86)
			mat.metallic = 0.86
			mat.roughness = 0.34
		
		"solar_panel":
			mat.albedo_color = Color(0.04, 0.08, 0.22)
			mat.metallic = 0.88
			mat.roughness = 0.12
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.9
			mat.clearcoat_roughness = 0.1
			mat.rim_enabled = true
			mat.rim = 0.4
			mat.rim_tint = 0.8
		
		"solar_back":
			mat.albedo_color = Color(0.15, 0.16, 0.18)
			mat.metallic = 0.4
			mat.roughness = 0.55
		
		"radiator_white":
			mat.albedo_color = Color(0.95, 0.96, 0.98)
			mat.metallic = 0.08
			mat.roughness = 0.16
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.6
		
		"antenna_reflector":
			mat.albedo_color = Color(0.94, 0.95, 0.97)
			mat.metallic = 0.75
			mat.roughness = 0.22
			mat.rim_enabled = true
			mat.rim = 0.3
		
		"antenna_feed":
			mat.albedo_color = Color(0.92, 0.72, 0.25)
			mat.metallic = 0.92
			mat.roughness = 0.25
		
		"thruster_nozzle":
			mat.albedo_color = Color(0.18, 0.19, 0.22)
			mat.metallic = 0.92
			mat.roughness = 0.32
			mat.rim_enabled = true
			mat.rim = 0.35
		
		"sensor_body":
			mat.albedo_color = Color(0.24, 0.26, 0.30)
			mat.metallic = 0.75
			mat.roughness = 0.35
		
		"sensor_lens":
			mat.albedo_color = Color(0.05, 0.15, 0.24)
			mat.metallic = 0.1
			mat.roughness = 0.05
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.45, 0.65)
			mat.emission_energy_multiplier = 0.6
		
		"avionics_box":
			mat.albedo_color = Color(0.32, 0.34, 0.38)
			mat.metallic = 0.8
			mat.roughness = 0.32
		
		"led_green":
			mat.albedo_color = Color(0.2, 0.95, 0.45)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.95, 0.45)
			mat.emission_energy_multiplier = 2.5
		
		"led_amber":
			mat.albedo_color = Color(0.98, 0.68, 0.12)
			mat.emission_enabled = true
			mat.emission = Color(0.98, 0.68, 0.12)
			mat.emission_energy_multiplier = 2.5
		
		"led_cyan":
			mat.albedo_color = Color(0.15, 0.85, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.15, 0.85, 1.0)
			mat.emission_energy_multiplier = 3.0
		
		"led_red":
			mat.albedo_color = Color(0.98, 0.25, 0.25)
			mat.emission_enabled = true
			mat.emission = Color(0.98, 0.25, 0.25)
			mat.emission_energy_multiplier = 2.5
		
		"highlight_glow":
			mat.albedo_color = Color(0.0, 0.75, 1.0, 0.35)
			mat.emission_enabled = true
			mat.emission = Color(0.0, 0.85, 1.0)
			mat.emission_energy_multiplier = 2.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		# --- INDUSTRIAL HANGAR & ROCKET SPECIFIC MATERIALS ---
		"rocket_white_gloss":
			mat.albedo_color = Color(0.93, 0.94, 0.96)
			mat.metallic = 0.20
			mat.roughness = 0.25
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.6
			mat.clearcoat_roughness = 0.15
			mat.rim_enabled = true
			mat.rim = 0.25
		
		"rocket_dark_carbon":
			mat.albedo_color = Color(0.14, 0.15, 0.18)
			mat.metallic = 0.45
			mat.roughness = 0.38
		
		"rocket_machined_steel":
			mat.albedo_color = Color(0.68, 0.72, 0.78)
			mat.metallic = 0.94
			mat.roughness = 0.26
			mat.rim_enabled = true
			mat.rim = 0.4
		
		"rocket_copper_chamber":
			mat.albedo_color = Color(0.86, 0.48, 0.26)
			mat.metallic = 0.92
			mat.roughness = 0.24
		
		"rocket_inconel_bell":
			mat.albedo_color = Color(0.22, 0.23, 0.26)
			mat.metallic = 0.95
			mat.roughness = 0.28
			mat.rim_enabled = true
			mat.rim = 0.5
			mat.rim_tint = 0.6
		
		"hangar_floor_concrete":
			mat.albedo_color = Color(0.11, 0.12, 0.15)
			mat.metallic = 0.25
			mat.roughness = 0.65
		
		"hangar_blast_deck":
			mat.albedo_color = Color(0.18, 0.20, 0.23)
			mat.metallic = 0.82
			mat.roughness = 0.40
		
		"hazard_stripe_yellow":
			mat.albedo_color = Color(0.95, 0.72, 0.05)
			mat.metallic = 0.4
			mat.roughness = 0.4
		
		"hazard_stripe_black":
			mat.albedo_color = Color(0.08, 0.08, 0.10)
			mat.metallic = 0.3
			mat.roughness = 0.5
		
		"gantry_yellow":
			mat.albedo_color = Color(0.92, 0.64, 0.06) # Industrial yellow
			mat.metallic = 0.55
			mat.roughness = 0.38
			mat.rim_enabled = true
			mat.rim = 0.3
		
		"gantry_dark_steel":
			mat.albedo_color = Color(0.16, 0.18, 0.22)
			mat.metallic = 0.88
			mat.roughness = 0.34
		
		"hangar_wall_ribbed":
			mat.albedo_color = Color(0.08, 0.10, 0.13)
			mat.metallic = 0.80
			mat.roughness = 0.45
		
		"hydraulic_chrome":
			mat.albedo_color = Color(0.94, 0.96, 0.98)
			mat.metallic = 0.98
			mat.roughness = 0.08
		
		"welding_spark_mat":
			mat.albedo_color = Color(1.0, 0.88, 0.35)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.85, 0.25)
			mat.emission_energy_multiplier = 4.0
		
		"hologram_bracket_cyan":
			mat.albedo_color = Color(0.12, 0.85, 1.0, 0.4)
			mat.emission_enabled = true
			mat.emission = Color(0.15, 0.85, 1.0)
			mat.emission_energy_multiplier = 3.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		"hologram_bracket_amber":
			mat.albedo_color = Color(1.0, 0.68, 0.12, 0.5)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.68, 0.12)
			mat.emission_energy_multiplier = 3.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		# --- ENVIRONMENT ART PASS: HIGH-FIDELITY AEROSPACE FACILITY ---
		"hangar_wall_dark":
			mat.albedo_color = Color(0.06, 0.08, 0.11)
			mat.metallic = 0.75
			mat.roughness = 0.42
			mat.rim_enabled = true
			mat.rim = 0.2
		
		"hangar_door_steel":
			mat.albedo_color = Color(0.12, 0.14, 0.18)
			mat.metallic = 0.85
			mat.roughness = 0.32
			mat.rim_enabled = true
			mat.rim = 0.3
		
		"hangar_truss_steel":
			mat.albedo_color = Color(0.14, 0.16, 0.20)
			mat.metallic = 0.90
			mat.roughness = 0.28
		
		"hangar_control_room_glass":
			mat.albedo_color = Color(0.15, 0.45, 0.65)
			mat.metallic = 0.2
			mat.roughness = 0.1
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.6, 0.8)
			mat.emission_energy_multiplier = 1.6
		
		"hangar_catwalk_grate":
			mat.albedo_color = Color(0.18, 0.20, 0.24)
			mat.metallic = 0.88
			mat.roughness = 0.38
		
		"vent_duct_galvanized":
			mat.albedo_color = Color(0.42, 0.45, 0.50)
			mat.metallic = 0.85
			mat.roughness = 0.35
		
		"pipe_cryo_insulation":
			mat.albedo_color = Color(0.85, 0.88, 0.92)
			mat.metallic = 0.55
			mat.roughness = 0.28
		
		"industrial_crane_safety":
			mat.albedo_color = Color(0.95, 0.52, 0.05)
			mat.metallic = 0.45
			mat.roughness = 0.38
		
		"worklight_fixture":
			mat.albedo_color = Color(1.0, 0.75, 0.25)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.75, 0.2)
			mat.emission_energy_multiplier = 4.0
		
		"highbay_light_fixture":
			mat.albedo_color = Color(0.85, 0.92, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.9, 1.0)
			mat.emission_energy_multiplier = 4.5
		
		"hazard_line_white":
			mat.albedo_color = Color(0.90, 0.92, 0.95)
			mat.metallic = 0.2
			mat.roughness = 0.4
		
		"drain_grate":
			mat.albedo_color = Color(0.12, 0.13, 0.16)
			mat.metallic = 0.90
			mat.roughness = 0.35
	
	_materials[name] = mat
	return mat
