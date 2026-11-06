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
			mat.albedo_color = Color(0.96, 0.72, 0.16)
			mat.metallic = 0.92
			mat.roughness = 0.28
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.5
			mat.clearcoat_roughness = 0.2
		
		"silver_mli":
			mat.albedo_color = Color(0.88, 0.90, 0.94)
			mat.metallic = 0.95
			mat.roughness = 0.22
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.6
		
		"carbon_fiber":
			mat.albedo_color = Color(0.12, 0.13, 0.15)
			mat.metallic = 0.3
			mat.roughness = 0.45
		
		"titanium":
			mat.albedo_color = Color(0.68, 0.70, 0.74)
			mat.metallic = 0.88
			mat.roughness = 0.32
		
		"aluminum":
			mat.albedo_color = Color(0.78, 0.80, 0.84)
			mat.metallic = 0.85
			mat.roughness = 0.38
		
		"solar_panel":
			mat.albedo_color = Color(0.06, 0.12, 0.28)
			mat.metallic = 0.82
			mat.roughness = 0.15
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.8
		
		"solar_back":
			mat.albedo_color = Color(0.16, 0.16, 0.18)
			mat.metallic = 0.4
			mat.roughness = 0.5
		
		"radiator_white":
			mat.albedo_color = Color(0.94, 0.95, 0.97)
			mat.metallic = 0.05
			mat.roughness = 0.18
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.5
		
		"antenna_reflector":
			mat.albedo_color = Color(0.92, 0.92, 0.94)
			mat.metallic = 0.6
			mat.roughness = 0.25
		
		"antenna_feed":
			mat.albedo_color = Color(0.85, 0.65, 0.2)
			mat.metallic = 0.9
			mat.roughness = 0.3
		
		"thruster_nozzle":
			mat.albedo_color = Color(0.18, 0.17, 0.19)
			mat.metallic = 0.9
			mat.roughness = 0.5
		
		"sensor_body":
			mat.albedo_color = Color(0.22, 0.24, 0.28)
			mat.metallic = 0.7
			mat.roughness = 0.35
		
		"sensor_lens":
			mat.albedo_color = Color(0.05, 0.15, 0.22)
			mat.metallic = 0.1
			mat.roughness = 0.05
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.35, 0.45)
			mat.emission_energy_multiplier = 0.4
		
		"avionics_box":
			mat.albedo_color = Color(0.3, 0.32, 0.36)
			mat.metallic = 0.75
			mat.roughness = 0.35
		
		"led_green":
			mat.albedo_color = Color(0.2, 0.9, 0.4)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.9, 0.4)
			mat.emission_energy_multiplier = 2.0
		
		"led_amber":
			mat.albedo_color = Color(0.95, 0.65, 0.1)
			mat.emission_enabled = true
			mat.emission = Color(0.95, 0.65, 0.1)
			mat.emission_energy_multiplier = 2.0
		
		"led_cyan":
			mat.albedo_color = Color(0.1, 0.8, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.8, 0.95)
			mat.emission_energy_multiplier = 2.5
		
		"highlight_glow":
			mat.albedo_color = Color(0.0, 0.7, 1.0, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.0, 0.8, 1.0)
			mat.emission_energy_multiplier = 1.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_materials[name] = mat
	return mat
