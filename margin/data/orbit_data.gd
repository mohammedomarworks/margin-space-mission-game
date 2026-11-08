class_name OrbitDatabase
extends RefCounted

# ==============================================================================
# EDUCATIONAL LUNAR ORBIT MODELS
# Note: These orbit profiles use simplified educational flight models for interactive
# gameplay. Orbital maneuvers are broken down into:
# 1. Deterministic Mid-Course Corrections (MCC) during translunar coast (~20 m/s game assumption)
# 2. Lunar Orbit Insertion (LOI) retro-burn to capture into lunar orbit:
#    - Direct Conventional Transfer: 839.878 m/s cited from NASA/JPL trajectory monograph
#      for a specific 4.036-day direct transfer into a 100 km circular lunar orbit.
#    - Low-Energy Ballistic Transfer: 669.543 m/s cited from NASA/JPL trajectory monograph
#      for a specific 83.706-day low-energy transfer to a low polar lunar orbit via Weak Stability Boundary.
#    Neither value is presented as a universal constant; both are cited reference cases.
# 3. Mission Orbit Stationkeeping against lunar gravitational mascons for 365 days
#    (150 m/s for 100 km circular is a separate educational game assumption).
# ==============================================================================

static func get_all_orbits() -> Dictionary:
	return {
		"orbit_low_circular": {
			"id": "orbit_low_circular",
			"name": "Low Circular Polar Orbit",
			"tag": "Maximum Science Fidelity",
			"orbit_type": "Circular Polar (e = 0.00, i = 90.0°)",
			"perilune_km": 100.0,
			"apolune_km": 100.0,
			"avg_altitude_km": 100.0,
			"period_min": 118.0,
			"max_eclipse_min": 48.0,
			
			# Deterministic Maneuver Breakdown (m/s)
			"mcc_delta_v_ms": 20.0, # Translunar mid-course trajectory corrections (game assumption)
			"stationkeeping_delta_v_ms": 150.0, # Educational assumption for 1-yr low-altitude mascon maintenance
			
			# Transfer-specific LOI retro-burns (m/s)
			"loi_low_energy_ms": 669.543, # NASA/JPL monograph cited reference example (83.7d polar BLT)
			"loi_direct_ms": 839.878, # NASA/JPL monograph cited reference example (4.0d direct 100 km insertion)
			
			# Total Required ΔV (mcc + loi + stationkeeping)
			"required_low_energy_ms": 839.543, # 20.0 + 669.543 + 150.0 m/s
			"required_direct_ms": 1009.878, # 20.0 + 839.878 + 150.0 m/s
			"required_delta_v_ms": 839.543, # Default to Low-Energy baseline
			"loi_delta_v_ms": 669.543, # Default baseline LOI
			
			"science_multiplier": 1.0,
			"spatial_resolution_rating": "High (~50 km uncollimated / 10 km collimated)",
			"description": "Flies at a constant 100 km altitude directly over both lunar poles. Delivers uniform, high-resolution mapping coverage across all polar craters.",
			"coverage_summary": "Uniform global and polar ground tracks with consistent footprint width across all latitudes.",
			"eclipse_summary": "Spacecraft enters the lunar shadow cone for up to 48 minutes per orbit during edge-on solar geometries.",
			"propulsion_summary": "Requires 839.5 m/s total ΔV with Low-Energy transfer (20 MCC + 669.5 LOI + 150 SK) or 1009.9 m/s with Direct transfer (20 MCC + 839.9 LOI + 150 SK).",
			"educational_tradeoff": "Delivers optimal and uniform scientific mapping resolution, but demands 839.5 to 1009.9 m/s total ΔV depending on transfer strategy. Also imposes maximum battery eclipse drain (~48 min).",
			"geometry_type": "circular_low",
			"loi_low_energy_citation": "NASA/JPL trajectory monograph (Series 12) reports 669.543 m/s for a specific 83.706-day low-energy transfer to a low polar lunar orbit via Weak Stability Boundary (cited specifically for this trajectory example, not a universal constant).",
			"loi_direct_citation": "NASA/JPL trajectory monograph (Series 12) cites 839.878 m/s for a specific direct transfer into a 100 km circular lunar orbit (cited as an illustrative reference case, not a universal lunar requirement).",
			"stationkeeping_note": "150 m/s is an educational game assumption for 1-year low-altitude stationkeeping against lunar gravitational mascons."
		},
		"orbit_elliptical_frozen": {
			"id": "orbit_elliptical_frozen",
			"name": "Quasi-Frozen Elliptical Polar Orbit",
			"tag": "South-Pole Targeted / Fuel Efficient",
			"orbit_type": "Eccentric Polar (e = 0.032, i = 90.0°)",
			"perilune_km": 50.0, # Directly over South Pole
			"apolune_km": 165.0, # Over North Pole
			"avg_altitude_km": 107.5,
			"period_min": 124.0,
			"max_eclipse_min": 38.0,
			
			# Deterministic Maneuver Breakdown (m/s)
			"mcc_delta_v_ms": 20.0,
			"stationkeeping_delta_v_ms": 75.0, # Frozen orbit cuts stationkeeping fuel by 50%
			
			"loi_low_energy_ms": 540.0, # Eccentric capture requires less braking ΔV
			"loi_direct_ms": 680.0,
			
			"required_low_energy_ms": 635.0, # 20.0 + 540.0 + 75.0 m/s
			"required_direct_ms": 775.0, # 20.0 + 680.0 + 75.0 m/s
			"required_delta_v_ms": 635.0,
			"loi_delta_v_ms": 540.0,
			
			"science_multiplier": 1.15, # South pole bonus
			"spatial_resolution_rating": "Ultra-High at South Pole (~25 km footprint) / Moderate at North",
			"description": "An eccentric polar orbit with a low 50 km perilune positioned directly over the lunar south pole and a 165 km apolune over the north.",
			"coverage_summary": "Intense high-resolution scrutiny of South Polar volatile deposits at 50 km, with broader coverage in the north.",
			"eclipse_summary": "Maximum spacecraft shadow duration is reduced to ~38 minutes due to eccentric geometry.",
			"propulsion_summary": "Requires 635 m/s total ΔV with Low-Energy transfer (20 MCC + 540 LOI + 75 SK) or 775 m/s with Direct transfer (20 MCC + 680 LOI + 75 SK).",
			"educational_tradeoff": "Reduces total mission ΔV and zooms in closer (50 km) over southern ice candidates. Northern coverage has coarser resolution.",
			"geometry_type": "elliptical",
			"loi_low_energy_citation": "Eccentric capture allows capture into a higher-energy elliptical orbit with ~540 m/s retro-burn.",
			"loi_direct_citation": "Direct eccentric capture requires ~680 m/s braking retro-burn.",
			"stationkeeping_note": "75 m/s is an educational game assumption for a frozen perigee orbit utilizing lunar gravity harmonics (J2/J3)."
		},
		"orbit_high_circular": {
			"id": "orbit_high_circular",
			"name": "High Circular Polar Orbit",
			"tag": "Safe & Low Maintenance",
			"orbit_type": "Circular Polar (e = 0.00, i = 90.0°)",
			"perilune_km": 200.0,
			"apolune_km": 200.0,
			"avg_altitude_km": 200.0,
			"period_min": 141.0,
			"max_eclipse_min": 44.0,
			
			# Deterministic Maneuver Breakdown (m/s)
			"mcc_delta_v_ms": 20.0,
			"stationkeeping_delta_v_ms": 45.0,
			
			"loi_low_energy_ms": 630.0,
			"loi_direct_ms": 795.0,
			
			"required_low_energy_ms": 695.0, # 20.0 + 630.0 + 45.0 m/s
			"required_direct_ms": 860.0, # 20.0 + 795.0 + 45.0 m/s
			"required_delta_v_ms": 695.0,
			"loi_delta_v_ms": 630.0,
			
			"science_multiplier": 0.80, # Lower resolution penalty
			"spatial_resolution_rating": "Coarse (~100 km footprint due to 1/r² flux decay)",
			"description": "A higher circular orbit at 200 km altitude, placing the vehicle above severe gravitational perturbation gradients.",
			"coverage_summary": "Wide field of view with rapid longitudinal swath coverage.",
			"eclipse_summary": "Spacecraft spends up to 44 minutes in lunar shadow cone per revolution.",
			"propulsion_summary": "Requires 695 m/s total ΔV with Low-Energy transfer (20 MCC + 630 LOI + 45 SK) or 860 m/s with Direct transfer (20 MCC + 795 LOI + 45 SK).",
			"educational_tradeoff": "Reduces annual stationkeeping fuel, but secondary neutron flux drops sharply with altitude (1/r² law), degrading volatile mapping sensitivity.",
			"geometry_type": "circular_high",
			"loi_low_energy_citation": "Low-energy capture into 200 km circular requires ~630 m/s braking retro-burn.",
			"loi_direct_citation": "Direct 200 km circular insertion requires ~795 m/s braking retro-burn.",
			"stationkeeping_note": "45 m/s is an educational game assumption for 200 km altitude where mascon perturbation gradients are reduced."
		},
		"orbit_earth_sso": {
			"id": "orbit_earth_sso",
			"name": "Sun-Synchronous LEO Orbit (SSO 705 km)",
			"tag": "Repeatable Solar Lighting / 10:30 LTDN",
			"target_body": "Earth",
			"orbit_type": "Sun-Synchronous Low Earth Orbit (e = 0.001, i = 98.2°)",
			"perilune_km": 705.0,
			"apolune_km": 705.0,
			"avg_altitude_km": 705.0,
			"period_min": 98.8,
			"max_eclipse_min": 35.0,
			
			"mcc_delta_v_ms": 5.0,
			"loi_delta_v_ms": 45.0,
			"stationkeeping_delta_v_ms": 25.0,
			"required_delta_v_ms": 75.0,
			"loi_low_energy_ms": 45.0,
			"loi_direct_ms": 45.0,
			"required_low_energy_ms": 75.0,
			"required_direct_ms": 75.0,
			
			"science_multiplier": 1.10,
			"spatial_resolution_rating": "Optimal Climate Imaging (10:30 AM local solar illumination)",
			"description": "Selected educational reference orbit at 705 km altitude with 98.2° retrograde inclination (modeled on the Landsat/Earth Observing System morning constellation architecture; this is a selected educational reference orbit, not a universal requirement for all Earth observation). Earth's oblate equatorial bulge (J2) precesses the orbital plane at ~0.9856°/day, matching Earth's mean orbital rate around the Sun.",
			"coverage_summary": "Global coverage with identical local solar time crossing (10:30 LTDN) on every pass, eliminating sun-angle calibration errors.",
			"eclipse_summary": "Orbital eclipse is limited to 35 minutes per 98.8-minute orbit; solar panels enjoy ~65% sunlight duty cycle.",
			"propulsion_summary": "Requires 75 m/s total ΔV (5 MCC + 45 circularization + 25 annual drag makeup).",
			"educational_tradeoff": "Sun-synchronous nodal precession creates identical shadow angles, which is critical for measuring seasonal ice-sheet albedo and vegetation indices without solar illumination bias.",
			"educational_reference_note": "705 km altitude with 98.2° inclination is a selected educational reference orbit modeled on the EOS/Landsat orbital architecture, not a universal requirement for Earth observation.",
			"geometry_type": "circular_earth_sso"
		},
		"orbit_earth_polar_leo": {
			"id": "orbit_earth_polar_leo",
			"name": "Low Polar Earth Orbit (450 km)",
			"tag": "Ultra-High Spatial Resolution / High Drag",
			"target_body": "Earth",
			"orbit_type": "Low Polar Earth Orbit (e = 0.000, i = 90.0°)",
			"perilune_km": 450.0,
			"apolune_km": 450.0,
			"avg_altitude_km": 450.0,
			"period_min": 93.5,
			"max_eclipse_min": 36.0,
			
			"mcc_delta_v_ms": 5.0,
			"loi_delta_v_ms": 20.0,
			"stationkeeping_delta_v_ms": 85.0,
			"required_delta_v_ms": 110.0,
			"loi_low_energy_ms": 20.0,
			"loi_direct_ms": 20.0,
			"required_low_energy_ms": 110.0,
			"required_direct_ms": 110.0,
			
			"science_multiplier": 1.25,
			"spatial_resolution_rating": "Ultra-High Resolution (450 km nadir proximity)",
			"description": "Lower 450 km polar orbit delivering sharper SAR ice sounding and optical resolution over coastal ice margins, but flying through denser thermosphere.",
			"coverage_summary": "High-latitude polar coverage every 93.5 minutes with rapid repeating ground tracks.",
			"eclipse_summary": "Eclipse duration is ~36 minutes per revolution.",
			"propulsion_summary": "Requires 110 m/s total ΔV due to 85 m/s annual atmospheric drag makeup burns.",
			"educational_tradeoff": "Closer proximity (+25% science) comes at the cost of 3.4x higher propulsion expenditure against thermospheric drag.",
			"geometry_type": "circular_earth_leo"
		}
	}

static func get_orbits_for_scenario(scenario_id: String) -> Dictionary:
	var all_orbs = get_all_orbits()
	var filtered: Dictionary = {}
	if scenario_id == "earth_climate_sentinel" or scenario_id == "ecs_01":
		filtered["orbit_earth_sso"] = all_orbs["orbit_earth_sso"]
		filtered["orbit_earth_polar_leo"] = all_orbs["orbit_earth_polar_leo"]
	else:
		filtered["orbit_low_circular"] = all_orbs["orbit_low_circular"]
		filtered["orbit_elliptical_frozen"] = all_orbs["orbit_elliptical_frozen"]
		filtered["orbit_high_circular"] = all_orbs["orbit_high_circular"]
	return filtered

static func get_orbit(id: String) -> Dictionary:
	var orbits = get_all_orbits()
	return orbits.get(id, orbits["orbit_low_circular"])

static func get_default_orbit_id() -> String:
	return "orbit_low_circular"

static func get_loi_delta_v(orbit_id: String, transfer_id: String) -> float:
	var orb = get_orbit(orbit_id)
	if transfer_id == "transfer_direct":
		return orb.get("loi_direct_ms", 839.878)
	else:
		return orb.get("loi_low_energy_ms", 669.543)

static func get_required_delta_v(orbit_id: String, transfer_id: String) -> float:
	var orb = get_orbit(orbit_id)
	if transfer_id == "transfer_direct":
		return orb.get("required_direct_ms", 1009.878)
	else:
		return orb.get("required_low_energy_ms", 839.543)
