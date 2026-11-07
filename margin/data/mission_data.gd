class_name MissionData
extends RefCounted

const MissionScenario = preload("res://margin/data/mission_scenario.gd")

# --- GAME SCENARIO CONSTRAINTS ---
# Note: The following budget, mass, and duration figures are educational game scenario
# constraints designed for gameplay balance, not certified NASA mission requirements or
# flight-qualified launcher performance specifications.
const MISSION_ID: String = "lunar_south_pole"
const MISSION_TITLE: String = "LUNAR SOUTH POLE — VOLATILE MAPPING"
const MISSION_SUBTITLE: String = "Discovery-Class Orbital Hydrogen Survey"

const SCENARIO_BUDGET_CAP_M: float = 180.0 # Game scenario budget limit ($180M USD)
const SCENARIO_MASS_LIMIT_KG: float = 380.0 # Game scenario spacecraft wet mass envelope (380 kg)
const SCENARIO_DURATION_DAYS: int = 365 # Game scenario nominal science mission duration (1 Earth year)
const MIN_SCIENCE_POINTS: float = 70.0 # Scenario threshold for mission success

# Backward-compatibility aliases for existing references
const BUDGET_CAP_M: float = SCENARIO_BUDGET_CAP_M
const MASS_LIMIT_KG: float = SCENARIO_MASS_LIMIT_KG
const NOMINAL_DURATION_DAYS: int = SCENARIO_DURATION_DAYS

# --- NOMINAL ORBITAL PHYSICS (100 km Low Lunar Polar Orbit) ---
const TARGET_ORBIT_ALT_KM: float = 100.0 # 100 km circular polar orbit
const ORBIT_PERIOD_MIN: float = 118.0 # ~1.97 hours per revolution
const MAX_ORBITAL_ECLIPSE_MIN: float = 48.0 # Maximum duration the spacecraft spends inside the Moon's shadow cone per orbit
const ECLIPSE_DURATION_MIN: float = MAX_ORBITAL_ECLIPSE_MIN # Backward-compatibility alias

# Maneuver Delta-V Breakdown & Trajectory Examples:
# Mid-Course Correction (MCC) & Stationkeeping (SK) Game Assumptions:
const REF_MCC_DELTA_V_MS: float = 20.0 # Mid-course trajectory corrections (educational game assumption)
const REF_STATIONKEEPING_DELTA_V_MS: float = 150.0 # 1-year low-altitude mascon maintenance (educational game assumption)

# Cited NASA/JPL Trajectory Monograph Reference Examples (particular reference examples, not universal requirements):
# Source: https://descanso.jpl.nasa.gov/monograph/series12/LunarTraj--Overall.pdf
const JPL_REF_DIRECT_DURATION_DAYS: float = 4.036
const JPL_REF_DIRECT_LOI_MS: float = 839.878 # Specific direct transfer into 100 km circular orbit

const JPL_REF_LOW_ENERGY_DURATION_DAYS: float = 83.706
const JPL_REF_LOW_ENERGY_LOI_MS: float = 669.543 # Specific low-energy WSB transfer into low polar orbit

# Baseline Scenario Requirements for 100 km Low Circular Polar Orbit:
const SCENARIO_LOW_ENERGY_REQ_DV_MS: float = 839.543 # 20.0 MCC + 669.543 LOI + 150.0 SK
const SCENARIO_DIRECT_REQ_DV_MS: float = 1009.878 # 20.0 MCC + 839.878 LOI + 150.0 SK

# Baseline reference requirement aliases (defaulting to Low-Energy transfer):
const REQUIRED_DELTA_V_MS: float = SCENARIO_LOW_ENERGY_REQ_DV_MS
const REF_LOI_DELTA_V_MS: float = JPL_REF_LOW_ENERGY_LOI_MS

# --- SCIENTIFIC OBJECTIVE & CAUTION ---
const SCIENTIFIC_GOAL: String = "Map epithermal neutron flux depressions across the lunar south pole (80°S–90°S) to identify candidate hydrogen-rich regolith deposits within permanently shadowed regions (PSRs)."
const SCIENTIFIC_CAUTION: String = "Hydrogen enhancement detected via neutron flux moderation is an indicator of concentrated hydrogen, but is NOT definitive proof of pure surface water ice at every location. Solar-wind implanted protons and hydrated minerals can also produce hydrogen enhancements."

# --- RELIABLE NASA HERITAGE REFERENCES & SOURCES ---
const REF_LUNAR_PROSPECTOR_NAME: String = "Lunar Prospector (1998) Helium-3 Neutron Spectrometer (LP-NS)"
const REF_LUNAR_PROSPECTOR_URL: String = "https://science.nasa.gov/mission/lunar-prospector/"

const REF_LRO_LEND_NAME: String = "Lunar Reconnaissance Orbiter (2009) Lunar Exploration Neutron Detector (LEND)"
const REF_LRO_LEND_URL: String = "https://lunar.gsfc.nasa.gov/lend.html"

const REF_MINI_RF_NAME: String = "LRO Miniature Radio Frequency (Mini-RF) Polarimetric Synthetic Aperture Radar"
const REF_MINI_RF_URL: String = "https://www.nasa.gov/mission/mini-rf/"

# --- DYNAMIC SCENARIO PROXIES ---
static func get_active_id() -> String:
	return MissionScenario.get_active_scenario().id

static func get_active_title() -> String:
	return MissionScenario.get_active_scenario().title

static func get_active_subtitle() -> String:
	return MissionScenario.get_active_scenario().subtitle

static func get_active_target_body() -> String:
	return MissionScenario.get_active_scenario().target_body

static func get_active_budget_cap_m() -> float:
	return MissionScenario.get_active_scenario().budget_cap_m

static func get_active_mass_limit_kg() -> float:
	return MissionScenario.get_active_scenario().mass_limit_kg

static func get_active_duration_days() -> int:
	return MissionScenario.get_active_scenario().duration_days

static func get_active_min_science_points() -> float:
	return MissionScenario.get_active_scenario().min_science_points

static func get_active_required_delta_v_ms() -> float:
	return MissionScenario.get_active_scenario().required_delta_v_ms

static func get_active_scientific_goal() -> String:
	return MissionScenario.get_active_scenario().scientific_goal

static func get_active_scientific_caution() -> String:
	return MissionScenario.get_active_scenario().scientific_caution
