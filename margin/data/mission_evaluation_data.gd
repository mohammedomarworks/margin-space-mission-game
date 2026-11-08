class_name MissionEvaluationData
extends RefCounted

# ==============================================================================
# MARGIN: MISSION EVALUATION & DEBRIEF DATABASE
# Manages evaluation persistence, local JSON storage (user://),
# team contribution models, and real NASA benchmark references.
# ==============================================================================

const SAVED_MISSIONS_PATH: String = "user://margin_saved_missions.json"

# In-memory holder for the active debrief report
static var active_debrief_report: Dictionary = {}

# --- LOCAL FILE STORAGE (Browser-compatible via Godot user:// IndexedDB) ---

static func save_mission_report(report: Dictionary) -> bool:
	var all_saved = load_all_saved_missions()
	
	# Create entry with timestamp and unique ID
	var entry: Dictionary = report.duplicate(true)
	if not entry.has("saved_at"):
		entry["saved_at"] = Time.get_datetime_string_from_system()
	if not entry.has("save_id"):
		entry["save_id"] = "mission_" + str(Time.get_unix_time_from_system())
	
	# Prepend latest run to the front
	all_saved.insert(0, entry)
	
	# Limit saved mission history to last 20 runs
	if all_saved.size() > 20:
		all_saved.resize(20)
	
	var file := FileAccess.open(SAVED_MISSIONS_PATH, FileAccess.WRITE)
	if file == null:
		printerr("[MissionEvaluationData] Failed to open %s for write: %s" % [SAVED_MISSIONS_PATH, FileAccess.get_open_error()])
		return false
	
	var json_str: String = JSON.stringify(all_saved, "\t")
	file.store_string(json_str)
	file.close()
	return true

static func load_all_saved_missions() -> Array[Dictionary]:
	if not FileAccess.file_exists(SAVED_MISSIONS_PATH):
		return []
	
	var file := FileAccess.open(SAVED_MISSIONS_PATH, FileAccess.READ)
	if file == null:
		return []
	
	var content: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var err = json.parse(content)
	if err != OK or not (json.data is Array):
		return []
	
	var result: Array[Dictionary] = []
	for item in json.data:
		if item is Dictionary:
			result.append(item)
	return result

static func delete_saved_mission(save_id: String) -> bool:
	var all_saved = load_all_saved_missions()
	var found_idx: int = -1
	for i in range(all_saved.size()):
		if all_saved[i].get("save_id", "") == save_id:
			found_idx = i
			break
	
	if found_idx == -1:
		return false
	
	all_saved.remove_at(found_idx)
	var file := FileAccess.open(SAVED_MISSIONS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(all_saved, "\t"))
	file.close()
	return true

static func clear_all_saved_missions() -> bool:
	if FileAccess.file_exists(SAVED_MISSIONS_PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			return dir.remove("margin_saved_missions.json") == OK
	return true

# --- COMPARISON ENGINE ---

static func compare_missions(report_a: Dictionary, report_b: Dictionary) -> Dictionary:
	var score_a: float = report_a.get("total_weighted_score", 0.0)
	var score_b: float = report_b.get("total_weighted_score", 0.0)
	
	var sci_a: float = report_a.get("science_score_total", 0.0)
	var sci_b: float = report_b.get("science_score_total", 0.0)
	
	var cost_a: float = report_a.get("total_cost_m", 0.0)
	var cost_b: float = report_b.get("total_cost_m", 0.0)
	
	var wet_a: float = report_a.get("wet_mass_kg", 0.0)
	var wet_b: float = report_b.get("wet_mass_kg", 0.0)
	
	var prop_a: float = report_a.get("propellant_remaining_kg", 0.0)
	var prop_b: float = report_b.get("propellant_remaining_kg", 0.0)
	
	var down_a: float = report_a.get("data_downlinked_total_gbit", 0.0)
	var down_b: float = report_b.get("data_downlinked_total_gbit", 0.0)
	
	var better_design: String = "Design A"
	if score_b > score_a:
		better_design = "Design B"
	elif score_b == score_a and cost_b < cost_a:
		better_design = "Design B"
	
	return {
		"better_design": better_design,
		"score_delta": score_b - score_a,
		"science_delta": sci_b - sci_a,
		"cost_delta": cost_b - cost_a,
		"mass_delta": wet_b - wet_a,
		"propellant_delta": prop_b - prop_a,
		"downlink_delta": down_b - down_a,
		"design_a_name": report_a.get("mission_name", "Design A"),
		"design_b_name": report_b.get("mission_name", "Design B"),
		"design_a_outcome": report_a.get("outcome_name", "UNKNOWN"),
		"design_b_outcome": report_b.get("outcome_name", "UNKNOWN")
	}

# --- REAL NASA BENCHMARK COMPARISONS VS SIMULATION ---

static func get_nasa_benchmarks(scenario_id: String = "") -> Dictionary:
	if scenario_id == "earth_climate_sentinel":
		return get_earth_climate_benchmarks()
	return get_lunar_benchmarks()

static func get_lunar_benchmarks() -> Dictionary:
	return {
		"lunar_prospector": {
			"mission": "NASA Lunar Prospector (1998)",
			"type": "Discovery Program Class",
			"cost_m": 63.0, # 1998 USD
			"dry_mass_kg": 158.0,
			"wet_mass_kg": 296.0,
			"instrument": "Helium-3 Proportional Counter Neutron Spectrometer (LP-NS)",
			"orbit_km": "100 km circular polar (later lowered to 30 km)",
			"key_findings": "Identified significant epithermal neutron flux depressions at both lunar poles, indicating ~1.5 wt% water-equivalent hydrogen deposits in polar regolith.",
			"caution_distinction": "Simulated mission models epithermal neutron moderation as a hydrogen concentration proxy. Lunar Prospector detected hydrogen, but could not resolve whether hydrogen was in water ice, hydroxyl, or solar wind protons.",
			"source_url": "https://science.nasa.gov/mission/lunar-prospector/"
		},
		"lro_lend": {
			"mission": "NASA Lunar Reconnaissance Orbiter (2009)",
			"type": "Lunar Precursor Robotic Program",
			"cost_m": 583.0,
			"dry_mass_kg": 1018.0,
			"wet_mass_kg": 1916.0,
			"instrument": "Lunar Exploration Neutron Detector (LEND)",
			"orbit_km": "50 km circular polar (later quasi-frozen 30x200 km)",
			"key_findings": "Collimated sensors localized hydrogen concentrations within specific PSR craters like Cabeus and Shoemaker with 10 km spatial resolution.",
			"caution_distinction": "LEND provided narrower collimated spatial resolution than LP-NS, showing that some permanently shadowed regions have high hydrogen while adjacent cold traps do not.",
			"source_url": "https://lunar.gsfc.nasa.gov/lend.html"
		},
		"lcross": {
			"mission": "NASA LCROSS Kinetic Impactor (2009)",
			"type": "Targeted Impact Ground Truth",
			"cost_m": 79.0,
			"dry_mass_kg": 621.0, # Shepherding spacecraft
			"wet_mass_kg": 891.0,
			"instrument": "Near-IR / Visible Spectrometers & Photometers",
			"orbit_km": "Lunar impact trajectory into Cabeus crater floor",
			"key_findings": "Directly confirmed 5.5 ± 1.5 wt% pure water ice vapor and hydroxyl (OH) along with volatiles (CO, NH3, CH4) in the Cabeus impact ejecta plume.",
			"caution_distinction": "LCROSS provided ground-truth kinetic verification for Cabeus crater. Orbital neutron spectrometers measure hydrogen proxies; LCROSS verified actual volatile chemistry at that specific impact site.",
			"source_url": "https://www.nasa.gov/mission/lcross/"
		}
	}

static func get_earth_climate_benchmarks() -> Dictionary:
	return {
		"esa_sentinel_3": {
			"mission": "ESA Sentinel-3 (2016)",
			"type": "Copernicus Operational Earth Observation",
			"cost_m": 550.0,
			"dry_mass_kg": 1150.0,
			"wet_mass_kg": 1250.0,
			"instrument": "OLCI (Ocean & Land Colour) / SLSTR (Sea Surface Temp)",
			"orbit_km": "814.5 km Sun-Synchronous, 98.65° inclination",
			"key_findings": "Operational monitoring of ocean surface skin temperatures, vegetation indices, and coastal water turbidity.",
			"caution_distinction": "Optical and thermal radiometers measure ocean skin temperature and chlorophyll proxies. They provide surface indicators only and cannot measure full-depth AMOC transport.",
			"source_url": "https://sentinels.copernicus.eu/web/sentinel/missions/sentinel-3"
		},
		"nasa_oco_2": {
			"mission": "NASA Orbiting Carbon Observatory-2 (2014)",
			"type": "Earth System Science Pathfinder",
			"cost_m": 468.0,
			"dry_mass_kg": 454.0,
			"wet_mass_kg": 454.0,
			"instrument": "High-Resolution 3-Band Grating Spectrometer (O2-A, CO2)",
			"orbit_km": "705 km Sun-Synchronous, 98.2° inclination",
			"key_findings": "High-precision column-averaged CO2 mole fraction (XCO2) mapping continental sinks and emissions.",
			"caution_distinction": "Atmospheric column spectrometry measures total gas columns; deriving surface carbon sources requires atmospheric transport inversion modeling.",
			"source_url": "https://ocov2.jpl.nasa.gov/"
		},
		"esa_cryosat_2": {
			"mission": "ESA CryoSat-2 (2010)",
			"type": "Earth Explorer Opportunity Mission",
			"cost_m": 175.0,
			"dry_mass_kg": 669.0,
			"wet_mass_kg": 720.0,
			"instrument": "SIRAL (SAR Interferometric Radar Altimeter, Ku-band)",
			"orbit_km": "720 km Polar, 92.0° inclination",
			"key_findings": "Pioneered Ku-band SAR interferometry for polar ice sheets and sea ice freeboard thickness profiling.",
			"caution_distinction": "Modeled on CryoSat-2 SIRAL's ice-focused SAR and interferometric radar altimetry heritage. It is a dedicated cryosphere altimeter, not a polarimetric SAR or open-ocean dynamic topography altimeter (such as Jason-3 or Sentinel-6), and does not measure steric sea-surface height or full-depth AMOC transport. Educational mass (58 kg), power (-135 W), and cost ($42.0M) in MARGIN are gameplay estimates rather than actual CryoSat-2 spacecraft specifications.",
			"source_url": "https://earth.esa.int/eogateway/missions/cryosat"
		}
	}
