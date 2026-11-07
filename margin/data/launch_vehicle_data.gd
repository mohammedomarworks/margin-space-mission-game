class_name LaunchVehicleDatabase
extends RefCounted

const MissionScenario = preload("res://margin/data/mission_scenario.gd")

# ==============================================================================
# EDUCATIONAL LAUNCH VEHICLE PROFILES
# Note: These launch vehicle options are illustrative educational game models designed
# to explore real aerospace trade-offs in payload capacity, fairing volume, and cost.
# They are not certified commercial or NASA launch service quotes.
# ==============================================================================

static func get_all_vehicles() -> Dictionary:
	return {
		"lv_rideshare_small": {
			"id": "lv_rideshare_small",
			"name": "Small Lunar Rideshare Profile",
			"tier": "Secondary Rideshare / ESPA Slot",
			"tli_payload_capacity_kg": 260.0, # Maximum wet mass injected to Trans-Lunar Trajectory
			"leo_payload_capacity_kg": 650.0, # LEO capability envelope
			"payload_capacity_kg": 260.0,
			"fairing_volume_m3": 1.60,
			"fairing_max_diameter_m": 1.20,
			"fairing_max_height_m": 1.50,
			"launch_cost_m": 14.0,
			"reliability_pct": 96.0,
			"injection_role": "Launcher performs Trans-Lunar Injection (TLI). Spacecraft must perform its own lunar orbit capture and stationkeeping.",
			"description": "A co-manifested secondary payload slot sharing a primary mission to Trans-Lunar Injection. Highly economical, but enforces tight mass and fairing envelope restrictions.",
			"tradeoff_positive": "Lowest launch cost ($14.0M), preserving budget for scientific instruments.",
			"tradeoff_negative": "Strict 260.0 kg payload mass cap and 1.2m fairing diameter. Excludes heavy propellant loads or wide radar arrays.",
			"educational_insight": "Rideshare adapters (like ESPA rings) enable low-cost deep-space missions by utilizing excess rocket lift margin, but your satellite must fit within rigid dimensional and mass boundaries."
		},
		"lv_commercial_medium": {
			"id": "lv_commercial_medium",
			"name": "Medium Commercial EELV-Class",
			"tier": "Dedicated Medium-Lift Launcher",
			"tli_payload_capacity_kg": 450.0,
			"leo_payload_capacity_kg": 2800.0,
			"payload_capacity_kg": 450.0,
			"fairing_volume_m3": 5.80,
			"fairing_max_diameter_m": 1.80,
			"fairing_max_height_m": 2.60,
			"launch_cost_m": 32.0,
			"reliability_pct": 98.5,
			"injection_role": "Upper stage executes precision TLI burn directly delivering the spacecraft to translunar cruise trajectory.",
			"description": "Commercial workhorse rocket providing a balanced 450 kg TLI mass envelope and generous 1.8m diameter fairing for standard planetary probes.",
			"tradeoff_positive": "Comfortably accommodates wet masses up to 450 kg, deployable solar wings, and hydrazine tanks.",
			"tradeoff_negative": "Moderate budget impact ($32.0M), requiring sensible instrument selection to stay under the scenario budget.",
			"educational_insight": "A dedicated medium launcher provides custom launch windows and direct injection accuracy, eliminating rideshare co-passenger scheduling delays."
		},
		"lv_heavy_dedicated": {
			"id": "lv_heavy_dedicated",
			"name": "Heavy Exploration Dedicated Launcher",
			"tier": "Heavy-Lift System",
			"tli_payload_capacity_kg": 850.0,
			"leo_payload_capacity_kg": 8500.0,
			"payload_capacity_kg": 850.0,
			"fairing_volume_m3": 22.0,
			"fairing_max_diameter_m": 3.20,
			"fairing_max_height_m": 4.20,
			"launch_cost_m": 65.0,
			"reliability_pct": 99.2,
			"injection_role": "High-energy cryogenic upper stage injects the spacecraft into a high-speed direct translunar trajectory.",
			"description": "High-capacity heavy-lift exploration launcher providing massive volumetric fairing clearance and high-energy injection margins.",
			"tradeoff_positive": "Enormous 850 kg payload capacity and 3.2m fairing envelope. Easily carries heavy SAR radar suites and full electric propulsion systems.",
			"tradeoff_negative": "Heaviest budget impact ($65.0M), severely constraining the funds remaining for spacecraft bus and science payloads.",
			"educational_insight": "Heavy-lift launchers provide surplus mass and volume margins, but their steep cost often forces engineering teams to justify why a smaller rocket could not suffice."
		}
	}

static func get_vehicle(id: String) -> Dictionary:
	var vehicles = get_all_vehicles()
	if vehicles.has(id):
		return vehicles[id]
	# Educational profile aliases for backward compatibility:
	if id == "lv_falcon9_tli" or id == "falcon9" or id == "falcon_9":
		return vehicles["lv_commercial_medium"]
	if id == "lv_electron" or id == "electron" or id == "rideshare":
		return vehicles["lv_rideshare_small"]
	if id == "lv_sls_tli" or id == "sls" or id == "heavy":
		return vehicles["lv_heavy_dedicated"]
	return vehicles["lv_commercial_medium"]

static func get_default_vehicle_id() -> String:
	return "lv_commercial_medium"

static func get_vehicle_payload_capacity(vehicle_id: String, scenario_id: String = "") -> float:
	var v = get_vehicle(vehicle_id)
	if scenario_id == "":
		scenario_id = MissionScenario.get_active_scenario_id()
	if scenario_id == "earth_climate_sentinel" or scenario_id == "ecs_01":
		return v.get("leo_payload_capacity_kg", v.get("tli_payload_capacity_kg", 450.0))
	return v.get("tli_payload_capacity_kg", 450.0)
