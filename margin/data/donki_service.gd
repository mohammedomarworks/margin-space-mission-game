class_name DonkiService
extends RefCounted

# ==============================================================================
# NASA DONKI — SPACE-WEATHER REFERENCE CATALOGUE & DETERMINISTIC BENCHMARKS
# Official CCMC Domain: https://ccmc.gsfc.nasa.gov/DONKI/
# Reference: Space Weather Database Of Notifications, Knowledge, Information
#
# IMPORTANT SCIENTIFIC & ARCHITECTURAL DISTINCTION:
# This module provides a deterministic offline reference catalogue of real
# historical benchmarks (May 2024 Mother's Day storm, 2003 Halloween storm)
# and hypothetical 2038 campaign scenarios based on NASA CCMC parameters.
# It does NOT perform live network requests or claim live data integration.
# No private API keys are stored or transmitted.
# ==============================================================================

const BASE_URL: String = "https://ccmc.gsfc.nasa.gov/DONKI/WS/get/"
const DEFAULT_API_KEY: String = "DEMO_KEY"

# Offline Deterministic Space-Weather Benchmark Scenarios
static var OFFLINE_EVENT_CATALOG: Array = [
	{
		"event_id": "2038-CME-EXTREME-01",
		"type": "CME",
		"label": "2038 HELIOS-4 Campaign Scenario (Hypothetical Carrington-Scale Threat)",
		"timestamp": "2038-10-14T06:22:00Z",
		"source": "Active Region AR-4890 (Direct Solar Meridian)",
		"cme_speed_kms": 2450.0,
		"half_angle_deg": 85.0, # Fast Halo CME
		"transit_time_hours": 16.5,
		"associated_flare": "X14.8 Extreme Hard X-Ray Flare",
		"predicted_kp": 9.0, # Extreme G5 Geomagnetic Storm
		"solar_wind_plasma_density_p_cm3": 48.5,
		"interplanetary_magnetic_field_bz_nt": -34.0, # Strong Southward IMF
		"educational_risk_level": "CRITICAL (G5+)",
		"game_severity": 5,
		"impact_description": "Hypothetical direct Earth-directed ultrafast halo CME erupting from AR-4890 after HELIOS-4 commissioning at L1. Dayside magnetopause compressed inside GEO. Advance warning packet delivered to Earth before arrival.",
		"is_live_data": false
	},
	{
		"event_id": "2024-05-10-G5-HISTORICAL",
		"type": "GST",
		"label": "Historical Benchmark: Mother's Day G5 Extreme Storm (May 2024)",
		"timestamp": "2024-05-10T22:30:00Z",
		"source": "Active Region NOAA 13664",
		"cme_speed_kms": 1250.0,
		"half_angle_deg": 65.0,
		"transit_time_hours": 28.0,
		"associated_flare": "X5.8 Solar Flare",
		"predicted_kp": 9.0,
		"solar_wind_plasma_density_p_cm3": 28.2,
		"interplanetary_magnetic_field_bz_nt": -24.5,
		"educational_risk_level": "SEVERE (G5)",
		"game_severity": 4,
		"impact_description": "Strongest geomagnetic storm in over 20 years. Illustrates why early-warning at Sun-Earth L1 (15-60 min notice) is vital for orbital assets and power grids.",
		"is_live_data": false
	},
	{
		"event_id": "2003-10-28-HALLOWEEN",
		"type": "FLR",
		"label": "Historical Benchmark: 2003 Halloween Solar Storms",
		"timestamp": "2003-10-28T11:10:00Z",
		"source": "Active Region NOAA 10486",
		"cme_speed_kms": 2100.0,
		"half_angle_deg": 90.0,
		"transit_time_hours": 19.0,
		"associated_flare": "X17.2 Megaflare",
		"predicted_kp": 9.0,
		"solar_wind_plasma_density_p_cm3": 35.0,
		"interplanetary_magnetic_field_bz_nt": -28.0,
		"educational_risk_level": "EXTREME (S4 Solar Radiation Storm)",
		"game_severity": 5,
		"impact_description": "Intense solar energetic protons blinded satellite star trackers and damaged solar cells. Emphasizes spacecraft safe-mode engineering.",
		"is_live_data": false
	},
	{
		"event_id": "2026-SOLAR-NOMINAL",
		"type": "IPS",
		"label": "Moderate Solar Wind Stream & Fast Coronal Hole Stream",
		"timestamp": "2026-11-01T08:15:00Z",
		"source": "Equatorial Coronal Hole CH-26",
		"cme_speed_kms": 580.0,
		"half_angle_deg": 35.0,
		"transit_time_hours": 58.0,
		"associated_flare": "M2.1 Moderate Flare",
		"predicted_kp": 4.5,
		"solar_wind_plasma_density_p_cm3": 9.4,
		"interplanetary_magnetic_field_bz_nt": -4.2,
		"educational_risk_level": "MODERATE (G1)",
		"game_severity": 2,
		"impact_description": "Elevated solar wind speed with mild geomagnetic fluctuations. Standard monitoring conditions at Sun-Earth L1.",
		"is_live_data": false
	}
]

static func get_offline_scenario(index: int = 0) -> Dictionary:
	var idx = clamp(index, 0, OFFLINE_EVENT_CATALOG.size() - 1)
	return OFFLINE_EVENT_CATALOG[idx]

static func get_campaign_crisis_event() -> Dictionary:
	# Primary campaign event: 2038 Carrington-Scale Superstorm
	return OFFLINE_EVENT_CATALOG[0]

# --- EDUCATIONAL RISK MAPPING ---
# Maps raw scientific telemetry into clear educational game severity
static func evaluate_space_weather_threat(speed_kms: float, bz_nt: float, flare_class: String) -> Dictionary:
	var severity: int = 1
	var warning_title: String = "Quiet / Minor Solar Wind"
	var advisory: String = "Nominal interplanetary conditions. Background cosmic radiation levels."
	
	# Speed assessment
	if speed_kms > 1800.0:
		severity = max(severity, 5)
	elif speed_kms > 1200.0:
		severity = max(severity, 4)
	elif speed_kms > 750.0:
		severity = max(severity, 3)
	elif speed_kms > 500.0:
		severity = max(severity, 2)
		
	# Interplanetary Magnetic Field Bz assessment (Southward IMF couples with Earth's magnetosphere)
	if bz_nt < -20.0:
		severity = max(severity, 5)
	elif bz_nt < -10.0:
		severity = max(severity, 4)
	elif bz_nt < -5.0:
		severity = max(severity, 3)
		
	# Flare classification assessment
	if flare_class.begins_with("X"):
		severity = max(severity, 4)
		if flare_class.length() > 1 and float(flare_class.substr(1)) >= 10.0:
			severity = 5
	elif flare_class.begins_with("M"):
		severity = max(severity, 2)
		
	match severity:
		5:
			warning_title = "CRITICAL: Extreme G5+ Superstorm"
			advisory = "Catastrophic CME shockwave detected. Orient spacecraft bus, switch vulnerable scientific optics to Safe Mode, and downlink warning packet immediately."
		4:
			warning_title = "SEVERE: Severe G4 Geomagnetic Storm"
			advisory = "Fast CME with strong southward IMF. Severe satellite charging hazard. Power systems must manage solar array degradation."
		3:
			warning_title = "ELEVATED: Strong G3 Solar Event"
			advisory = "Elevated proton flux. Star trackers may experience radiation snow artifacts. Ground DSN lock must be maintained."
		2:
			warning_title = "MODERATE: Moderate Solar Disturbance"
			advisory = "Coronal hole stream passing Sun-Earth L1. Nominal sensor operations continue."
		_:
			warning_title = "NOMINAL: Quiet Solar Wind"
			advisory = "Ambient solar wind baseline at 1 AU."
			
	return {
		"severity_tier": severity,
		"warning_title": warning_title,
		"advisory": advisory,
		"lead_time_minutes": calculate_warning_lead_time_minutes(speed_kms)
	}

# Sun-Earth L1 is ~1.5 million km sunward from Earth.
# When a CME shockwave passes L1, the time it takes to travel the remaining 1.5 million km to Earth is:
# warning_minutes = distance_km / shock_velocity_km_per_s / 60
static func calculate_warning_lead_time_minutes(speed_kms: float, distance_km: float = 1500000.0) -> float:
	if speed_kms <= 0.0 or distance_km <= 0.0:
		return 0.0
	return distance_km / speed_kms / 60.0
