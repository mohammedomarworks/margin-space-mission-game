class_name DestinationData
extends RefCounted

# ==============================================================================
# MARGIN — 3-DESTINATION MISSION SELECTOR DATA
# Three selectable targets, each with its own engineering requirement gates.
# Requirements are evaluated against live hangar telemetry so the player sees a
# real checklist (Mass / Power / Delta-V / Thermal / Science) before launch.
#
# Targets:
#   1. SUN-EARTH L1  (HELIOS-4)      — thermal + radiation shielding, solar wind
#                                      instruments, medium delta-V (3,200 m/s)
#   2. LUNAR SOUTH POLE (ARTEMIS-SCOUT) — high battery margin for eclipse shadow,
#                                      radar/spectrometer payload, low delta-V (2,600)
#   3. MARS ORBITER (ARES-VOYAGER)   — maximum delta-V (4,500+), large arrays for
#                                      weak sunlight, high-gain deep space dish
# ==============================================================================

const L1: String = "sun_earth_l1"
const MOON: String = "lunar_south_pole"
const MARS: String = "mars_orbiter"

const ORDER: Array = [L1, MOON, MARS]

# --- Requirement thresholds per destination ---
const REQUIREMENTS: Dictionary = {
	L1: {
		# Card displays the mission-level transfer budget (3,200 m/s).
		# The gate itself checks the probe's own onboard delta-V, because the
		# launch vehicle supplies the ascent portion.
		"mission_delta_v_ms": 3200.0,
		"min_probe_delta_v_ms": 420.0,
		"min_power_margin_w": 100.0,
		"min_battery_wh": 900.0,
		"min_solar_area_m2": 5.0,
		"min_science_score": 40.0,
		"min_thermal_flux_tolerance_w_m2": 1500.0,
		"required_instruments": ["faraday_cup", "magnetometer"],
		"requires_high_gain_dish": false,
		"requires_rad_hard": true
	},
	MOON: {
		"mission_delta_v_ms": 2600.0,
		"min_probe_delta_v_ms": 380.0,
		"min_power_margin_w": 100.0,
		"min_battery_wh": 1400.0,
		"min_solar_area_m2": 3.0,
		"min_science_score": 30.0,
		"min_thermal_flux_tolerance_w_m2": 1300.0,
		"required_instruments": [],
		"requires_high_gain_dish": false,
		"requires_rad_hard": false
	},
	MARS: {
		"mission_delta_v_ms": 4500.0,
		"min_probe_delta_v_ms": 520.0,
		"min_power_margin_w": 100.0,
		"min_battery_wh": 1100.0,
		"min_solar_area_m2": 9.0,
		"min_science_score": 45.0,
		"min_thermal_flux_tolerance_w_m2": 650.0,
		"required_instruments": [],
		"requires_high_gain_dish": true,
		"requires_rad_hard": true
	}
}

const METADATA: Dictionary = {
	L1: {
		"id": L1,
		"solar_distance_au": 0.99,
		"code": "HELIOS-4",
		"name": "SUN-EARTH L1",
		"subtitle": "Solar Observatory",
		"tagline": "Stand sentinel 1.5 million km sunward.",
		"body_color": Color(1.0, 0.72, 0.25),
		"accent": Color(1.0, 0.62, 0.18),
		"distance_label": "1,500,000 km",
		"flight_time_label": "~110 days",
		"delta_v_label": "3,200 m/s",
		"difficulty": "MEDIUM",
		"difficulty_stars": 2,
		"hazards": ["Solar CME radiation storm", "Extreme thermal flux", "Unstable saddle orbit"],
		"needs": [
			"High thermal & radiation shielding",
			"Solar wind instruments (Magnetometer + Faraday Cup)",
			"Medium delta-V budget (3,200 m/s)"
		],
		"science_goal": "Continuous plasma, magnetic field and energetic particle warning 15-60 min before CME impact."
	},
	MOON: {
		"id": MOON,
		"solar_distance_au": 1.0,
		"code": "ARTEMIS-SCOUT",
		"name": "LUNAR SOUTH POLE",
		"subtitle": "Volatile Mapping Orbiter",
		"tagline": "Map the ice hiding in permanent shadow.",
		"body_color": Color(0.78, 0.78, 0.82),
		"accent": Color(0.72, 0.80, 0.92),
		"distance_label": "384,400 km",
		"flight_time_label": "~4 days",
		"delta_v_label": "2,600 m/s",
		"difficulty": "EASY",
		"difficulty_stars": 1,
		"hazards": ["48-minute lunar eclipse shadow", "Cryogenic thermal cycling", "Polar crater lighting"],
		"needs": [
			"High battery margin for eclipse shadow survival",
			"Radar / neutron spectrometer payload",
			"Lower delta-V budget (2,600 m/s)"
		],
		"science_goal": "Map epithermal neutron flux depressions across 80S-90S to locate hydrogen-rich regolith in permanently shadowed regions."
	},
	MARS: {
		"id": MARS,
		"solar_distance_au": 1.524,
		"code": "ARES-VOYAGER",
		"name": "MARS ORBITER",
		"subtitle": "Deep Space Survey",
		"tagline": "Nine months out. No rescue mission.",
		"body_color": Color(0.85, 0.36, 0.22),
		"accent": Color(0.95, 0.42, 0.24),
		"distance_label": "225,000,000 km",
		"flight_time_label": "~259 days",
		"delta_v_label": "4,500+ m/s",
		"difficulty": "HARD",
		"difficulty_stars": 3,
		"hazards": ["Weak solar flux at Mars", "Deep space comms delay", "Long cruise reliability"],
		"needs": [
			"Maximum delta-V propulsion (4,500+ m/s)",
			"Large solar arrays for weak sunlight",
			"High-gain deep space dish"
		],
		"science_goal": "Characterise atmospheric loss, dust storm dynamics and subsurface volatiles from Mars orbit."
	}
}


static func get_metadata(dest_id: String) -> Dictionary:
	return METADATA.get(dest_id, METADATA[L1])


static func get_requirements(dest_id: String) -> Dictionary:
	return REQUIREMENTS.get(dest_id, REQUIREMENTS[L1])


static func get_all() -> Array:
	var out: Array = []
	for id in ORDER:
		out.append(METADATA[id])
	return out


static func get_next_destination(dest_id: String) -> String:
	var idx: int = ORDER.find(dest_id)
	if idx < 0 or idx >= ORDER.size() - 1:
		return ""
	return ORDER[idx + 1]


static func get_display_name(dest_id: String) -> String:
	return get_metadata(dest_id).get("name", "SUN-EARTH L1")


# ------------------------------------------------------------------------------
# Requirement evaluation against live hangar telemetry
# Returns an array of checklist rows:
#   { key, label, required, actual, passed, unit }
# ------------------------------------------------------------------------------

static func evaluate(telemetry: Dictionary, dest_id: String,
		probe_config: Dictionary = {}) -> Array:
	var req: Dictionary = get_requirements(dest_id)
	var rows: Array = []

	# Delta-V: gate on the probe's own budget (launch vehicle covers ascent)
	var probe_dv: float = float(telemetry.get("delta_v_probe", 0.0))
	rows.append(_row("delta_v", "Probe Delta-V Budget",
		req["min_probe_delta_v_ms"], probe_dv,
		probe_dv >= req["min_probe_delta_v_ms"], "m/s"))

	var power_margin: float = float(telemetry.get("power_margin_w", 0.0))
	rows.append(_row("power", "Power Margin",
		req["min_power_margin_w"], power_margin,
		power_margin >= req["min_power_margin_w"], "W"))

	var thermal_tolerance: float = float(telemetry.get("thermal_flux_tolerance_w_m2", 0.0))
	rows.append(_row("thermal", "Thermal Flux Envelope",
		req["min_thermal_flux_tolerance_w_m2"], thermal_tolerance,
		thermal_tolerance >= req["min_thermal_flux_tolerance_w_m2"], "W/m2"))

	var battery: float = float(probe_config.get("battery_capacity_wh", 0.0))
	rows.append(_row("battery", "Battery Capacity",
		req["min_battery_wh"], battery,
		battery >= req["min_battery_wh"], "Wh"))

	var solar: float = float(probe_config.get("solar_array_area_m2", 0.0))
	rows.append(_row("solar", "Solar Array Area",
		req["min_solar_area_m2"], solar,
		solar >= req["min_solar_area_m2"], "m2"))

	var science: float = float(telemetry.get("science_score", 0.0))
	rows.append(_row("science", "Science Payload Score",
		req["min_science_score"], science,
		science >= req["min_science_score"], "pts"))

	# Instrument-specific gates
	var instruments: Dictionary = probe_config.get("instruments", {})
	for inst_key in req["required_instruments"]:
		var has_inst: bool = instruments.has(inst_key)
		rows.append({
			"key": "inst_" + str(inst_key),
			"label": "Instrument: " + str(inst_key).replace("_", " ").capitalize(),
			"required": 1.0,
			"actual": 1.0 if has_inst else 0.0,
			"passed": has_inst,
			"unit": ""
		})

	if req["requires_high_gain_dish"]:
		var dish: float = float(probe_config.get("antenna_diameter_m", 0.0))
		rows.append({
			"key": "dish",
			"label": "High-Gain Deep Space Dish (>=1.5 m)",
			"required": 1.5,
			"actual": dish,
			"passed": dish >= 1.5,
			"unit": "m"
		})

	if req["requires_rad_hard"]:
		var rad_ok: bool = str(probe_config.get("computer_type", "")) == "comp_rad_hard_quad_core"
		rows.append({
			"key": "rad_hard",
			"label": "Rad-Hardened Avionics",
			"required": 1.0,
			"actual": 1.0 if rad_ok else 0.0,
			"passed": rad_ok,
			"unit": ""
		})

	return rows


static func _row(key: String, label: String, required: float, actual: float,
		passed: bool, unit: String) -> Dictionary:
	return {
		"key": key,
		"label": label,
		"required": required,
		"actual": actual,
		"passed": passed,
		"unit": unit
	}


static func count_passed(rows: Array) -> int:
	var n: int = 0
	for r in rows:
		if r.get("passed", false):
			n += 1
	return n


static func all_passed(rows: Array) -> bool:
	for r in rows:
		if not r.get("passed", false):
			return false
	return true
