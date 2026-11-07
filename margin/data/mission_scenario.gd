class_name MissionScenario
extends RefCounted

# ==============================================================================
# MARGIN: MISSION SCENARIO ARCHITECTURE
# Polymorphic scenario configuration supporting multiple aerospace missions:
# - LSP-01: Lunar South Pole — Volatile Mapping (Discovery-Class Lunar Orbiter)
# - ECS-01: Earth Climate Sentinel — Polar Ice & Atmosphere (LEO Sun-Synchronous)
# ==============================================================================

var id: String = "lunar_south_pole"
var code: String = "LSP-01"
var title: String = "LUNAR SOUTH POLE — VOLATILE MAPPING"
var subtitle: String = "Discovery-Class Orbital Hydrogen Survey"
var target_body: String = "Moon"
var mission_type: String = "Lunar Polar Orbiter"

# Scenario Constraints (Educational Models)
var budget_cap_m: float = 180.0
var mass_limit_kg: float = 380.0
var duration_days: int = 365
var min_science_points: float = 70.0

# Orbital Baseline & Maneuvers
var target_altitude_km: float = 100.0
var orbit_period_min: float = 118.0
var max_eclipse_min: float = 48.0
var ref_mcc_delta_v_ms: float = 20.0
var ref_loi_delta_v_ms: float = 669.543
var ref_stationkeeping_delta_v_ms: float = 150.0
var required_delta_v_ms: float = 839.543

# Allowed Configurations
var default_orbit_id: String = "orbit_low_circular"
var default_transfer_id: String = "transfer_low_energy"
var default_vehicle_id: String = "lv_commercial_medium"
var allowed_orbit_ids: Array = ["orbit_low_circular", "orbit_elliptical_frozen", "orbit_high_circular"]
var allowed_transfer_ids: Array = ["transfer_low_energy", "transfer_direct"]

# Scientific Objectives & Text
var scientific_goal: String = ""
var scientific_caution: String = ""
var target_system_name: String = "Craters"
var coverage_label: String = "Polar Crater Coverage"
var educational_notes: String = ""
var heritage_references: Array = []

# --- GLOBAL ACTIVE SCENARIO REGISTRY ---
static var _active_scenario_id: String = "lunar_south_pole"

static func get_active_scenario_id() -> String:
	return _active_scenario_id

static func is_sandbox_active() -> bool:
	return _active_scenario_id == "sandbox"

static func set_active_scenario(p_id: String) -> void:
	if p_id == "sandbox" or p_id == "creative_sandbox" or p_id == "sbx":
		_active_scenario_id = "sandbox"
	elif p_id == "earth_climate_sentinel" or p_id == "ecs_01" or p_id == "earth":
		_active_scenario_id = "earth_climate_sentinel"
	elif p_id == "helios_4" or p_id == "helios4" or p_id == "helios":
		_active_scenario_id = "helios_4"
	else:
		_active_scenario_id = "lunar_south_pole"

static func get_active_scenario():
	return get_scenario(_active_scenario_id)

static func get_all_scenarios() -> Dictionary:
	return {
		"lunar_south_pole": _create_lunar_scenario(),
		"earth_climate_sentinel": _create_earth_scenario(),
		"helios_4": _create_helios4_scenario(),
		"sandbox": _create_sandbox_scenario()
	}

static func get_scenario(p_id: String):
	var all_scenarios = get_all_scenarios()
	if all_scenarios.has(p_id):
		return all_scenarios[p_id]
	if p_id == "sandbox" or p_id == "creative_sandbox" or p_id == "sbx":
		return all_scenarios["sandbox"]
	if p_id == "earth_climate_sentinel" or p_id == "ecs_01" or p_id == "earth":
		return all_scenarios["earth_climate_sentinel"]
	if p_id == "helios_4" or p_id == "helios4" or p_id == "helios":
		return all_scenarios["helios_4"]
	return all_scenarios["lunar_south_pole"]

# --- SCENARIO FACTORIES ---

static func _create_lunar_scenario():
	var s = (load("res://margin/data/mission_scenario.gd") as GDScript).new()
	s.id = "lunar_south_pole"
	s.code = "LSP-01"
	s.title = "LUNAR SOUTH POLE — VOLATILE MAPPING"
	s.subtitle = "Discovery-Class Orbital Hydrogen Survey"
	s.target_body = "Moon"
	s.mission_type = "Lunar Polar Orbiter"
	
	s.budget_cap_m = 180.0
	s.mass_limit_kg = 380.0
	s.duration_days = 365
	s.min_science_points = 70.0
	
	s.target_altitude_km = 100.0
	s.orbit_period_min = 118.0
	s.max_eclipse_min = 48.0
	s.ref_mcc_delta_v_ms = 20.0
	s.ref_loi_delta_v_ms = 669.543
	s.ref_stationkeeping_delta_v_ms = 150.0
	s.required_delta_v_ms = 839.543
	
	s.default_orbit_id = "orbit_low_circular"
	s.default_transfer_id = "transfer_low_energy"
	s.default_vehicle_id = "lv_commercial_medium"
	s.allowed_orbit_ids = ["orbit_low_circular", "orbit_elliptical_frozen", "orbit_high_circular"]
	s.allowed_transfer_ids = ["transfer_low_energy", "transfer_direct"]
	
	s.scientific_goal = "Map epithermal neutron flux depressions across the lunar south pole (80°S–90°S) to identify candidate hydrogen-rich regolith deposits within permanently shadowed regions (PSRs)."
	s.scientific_caution = "Hydrogen enhancement detected via neutron flux moderation is a proxy indicator of hydrogen and does not constitute definitive proof of pure surface water ice at every location. Solar-wind implanted protons and hydrated minerals can also produce enhancements."
	s.target_system_name = "Craters"
	s.coverage_label = "Polar Crater Coverage"
	s.educational_notes = "Educational flight models cited from NASA/JPL trajectory monographs (Series 12). 83.7d BLT requires 669.5 m/s LOI; 4.0d direct requires 839.9 m/s LOI."
	
	s.heritage_references = [
		{ "name": "NASA Lunar Prospector (1998) LP-NS", "url": "https://science.nasa.gov/mission/lunar-prospector/" },
		{ "name": "NASA LRO Lunar Exploration Neutron Detector (LEND)", "url": "https://lunar.gsfc.nasa.gov/lend.html" },
		{ "name": "LRO Miniature Radio Frequency (Mini-RF) Radar", "url": "https://www.nasa.gov/mission/mini-rf/" }
	]
	return s

static func _create_earth_scenario():
	var s = (load("res://margin/data/mission_scenario.gd") as GDScript).new()
	s.id = "earth_climate_sentinel"
	s.code = "ECS-01"
	s.title = "EARTH CLIMATE SENTINEL — POLAR ICE & ATMOSPHERE"
	s.subtitle = "Earth System Science Pathfinder (ESSP) Class Climate Observatory"
	s.target_body = "Earth"
	s.mission_type = "Sun-Synchronous Low Earth Orbit (LEO) Satellite"
	
	s.budget_cap_m = 140.0 # Educational budget constraint
	s.mass_limit_kg = 550.0 # Generous LEO mass envelope compared to translunar rideshare
	s.duration_days = 365
	s.min_science_points = 75.0
	
	s.target_altitude_km = 705.0
	s.orbit_period_min = 98.8
	s.max_eclipse_min = 35.0 # Shorter shadow in LEO (35 min vs 48 min lunar)
	s.ref_mcc_delta_v_ms = 5.0 # Minor injection trim
	s.ref_loi_delta_v_ms = 45.0 # Circularization into 705 km slot
	s.ref_stationkeeping_delta_v_ms = 25.0 # Low-drag Sun-Synchronous stationkeeping
	s.required_delta_v_ms = 75.0 # Total onboard delta-V required
	
	s.default_orbit_id = "orbit_earth_sso"
	s.default_transfer_id = "transfer_leo_direct"
	s.default_vehicle_id = "lv_rideshare_small" # Small rideshare can carry 650 kg to LEO!
	s.allowed_orbit_ids = ["orbit_earth_sso", "orbit_earth_polar_leo"]
	s.allowed_transfer_ids = ["transfer_leo_direct"]
	
	s.scientific_goal = "Continuously quantify multi-spectral cryosphere albedo, greenhouse gas column concentrations (CO2/CH4), and polar ice sheet elevation changes across 6 critical global climate sentinels."
	s.scientific_caution = "Educational Model Notice: Satellite remote sensing derives atmospheric concentrations and ice volume proxies through radiative transfer models and radar echo travel times. Cloud masking, aerosols, and seasonal surface water introduce physical measurement uncertainties."
	s.target_system_name = "Climate Sentinels"
	s.coverage_label = "Global Climate Grid Coverage"
	s.educational_notes = "Educational approximations: 705 km Sun-Synchronous orbit balances 10:30 LTDN ground illumination with manageable atmospheric drag (~25 m/s/yr). Downlink passes utilize high-latitude polar stations (Svalbard & McMurdo)."
	
	s.heritage_references = [
		{ "name": "ESA Sentinel-3 Ocean and Land Colour Instrument (OLCI)", "url": "https://sentinels.copernicus.eu/web/sentinel/missions/sentinel-3" },
		{ "name": "NASA Orbiting Carbon Observatory-2 (OCO-2)", "url": "https://ocov2.jpl.nasa.gov/" },
		{ "name": "ESA CryoSat-2 SAR Interferometric Radar Altimeter (SIRAL)", "url": "https://earth.esa.int/eogateway/missions/cryosat" }
	]
	return s

static func _create_helios4_scenario():
	var s = (load("res://margin/data/mission_scenario.gd") as GDScript).new()
	s.id = "helios_4"
	s.code = "HELIOS-4"
	s.title = "HELIOS-4: THE LAST LINE OF DEFENSE"
	s.subtitle = "Sun-Earth L1 Solar Weather Early-Warning Sentinel"
	s.target_body = "Sun-Earth L1"
	s.mission_type = "Deep Space Halo-Orbit Sentinel"
	
	s.budget_cap_m = 185.0
	s.mass_limit_kg = 1250.0
	s.duration_days = 1095 # 3-year baseline mission
	s.min_science_points = 80.0
	
	# L1 is ~1.5 million km sunward from Earth (NOT the midpoint!)
	s.target_altitude_km = 1500000.0
	s.orbit_period_min = 259200.0 # ~180-day halo orbit period around L1
	s.max_eclipse_min = 0.0 # Quasi-continuous solar illumination (halo orbit prevents Earth eclipses)
	s.ref_mcc_delta_v_ms = 45.0 # Mid-course correction maneuvers
	s.ref_loi_delta_v_ms = 280.0 # Halo orbit insertion burn
	s.ref_stationkeeping_delta_v_ms = 120.0 # 3-year stationkeeping budget (halo orbits are dynamically unstable)
	s.required_delta_v_ms = 445.0 # Total probe ΔV
	
	s.default_orbit_id = "orbit_l1_halo"
	s.default_transfer_id = "transfer_earth_l1"
	s.default_vehicle_id = "lv_commercial_medium"
	s.allowed_orbit_ids = ["orbit_l1_halo", "orbit_l1_lissajous"]
	s.allowed_transfer_ids = ["transfer_earth_l1", "transfer_wsb_l1"]
	
	s.scientific_goal = "Station an uncrewed solar-weather early-warning observatory in a stable halo orbit around Sun-Earth L1 to provide continuous plasma, magnetic field, and energetic particle warnings 15 to 60 minutes before CMEs impact Earth."
	s.scientific_caution = "Sun-Earth L1 is approximately 1.5 million km sunward (only 1% of the distance to the Sun), not the midpoint. Halo orbits around L1 require continuous stationkeeping propellant because libration point collinear orbits are dynamically unstable. The spacecraft is uncrewed."
	s.target_system_name = "Solar Weather Monitors"
	s.coverage_label = "L1 Early Warning Telemetry"
	s.educational_notes = "Inspired by NASA's DSCOVR and SOHO missions. DSCOVR PlasMag instruments measure solar wind velocity, density, and magnetic field direction (especially Bz)."
	
	s.heritage_references = [
		{ "name": "NASA Deep Space Climate Observatory (DSCOVR) PlasMag", "url": "https://www.nesdis.noaa.gov/our-satellites/currently-flying/dscovr" },
		{ "name": "ESA/NASA Solar and Heliospheric Observatory (SOHO)", "url": "https://soho.nascom.nasa.gov/" },
		{ "name": "NASA Advanced Composition Explorer (ACE)", "url": "https://izw1.caltech.edu/ACE/" }
	]
	return s

static func _create_sandbox_scenario():
	var s = (load("res://margin/data/mission_scenario.gd") as GDScript).new()
	s.id = "sandbox"
	s.code = "SBX-00"
	s.title = "CREATIVE SANDBOX — UNRESTRICTED ARCHITECTURE"
	s.subtitle = "Unconstrained Engineering Testbed & Spacecraft Prototyping Laboratory"
	s.target_body = "Experimental Space"
	s.mission_type = "Unconstrained Spacecraft Testbed"
	
	s.budget_cap_m = 999.0 # Unlimited budget
	s.mass_limit_kg = 9999.0 # Relaxed mass envelope
	s.duration_days = 365
	s.min_science_points = 0.0 # No pass/fail requirement
	
	s.target_altitude_km = 100.0
	s.orbit_period_min = 118.0
	s.max_eclipse_min = 48.0
	s.ref_mcc_delta_v_ms = 0.0
	s.ref_loi_delta_v_ms = 0.0
	s.ref_stationkeeping_delta_v_ms = 0.0
	s.required_delta_v_ms = 0.0
	
	s.default_orbit_id = "orbit_low_circular"
	s.default_transfer_id = "transfer_low_energy"
	s.default_vehicle_id = "lv_heavy_dedicated"
	s.allowed_orbit_ids = ["orbit_low_circular", "orbit_elliptical_frozen", "orbit_high_circular", "orbit_earth_sso", "orbit_earth_polar_leo"]
	s.allowed_transfer_ids = ["transfer_low_energy", "transfer_direct", "transfer_leo_direct"]
	
	s.scientific_goal = "Experimental sandbox: Test, configure, and evaluate arbitrary combinations of aerospace hardware without fiscal or mass caps."
	s.scientific_caution = "Experimental Sandbox Mode. Telemetry is computed for engineering study; competitive mission achievements are disengaged."
	s.target_system_name = "Experimental Targets"
	s.coverage_label = "Test Grid Coverage"
	s.educational_notes = "Sandbox environment enables stress-testing extreme multi-payload configurations."
	return s
