class_name MissionOperationsData
extends RefCounted

const MissionScenario = preload("res://margin/data/mission_scenario.gd")

# ==============================================================================
# MARGIN: MISSION OPERATIONS DATABASE & OPERATIONAL MODELS
# ==============================================================================

# Static configuration passed from Launch Planning
static var active_orbit_id: String = "orbit_low_circular"
static var active_transfer_id: String = "transfer_low_energy"
static var active_vehicle_id: String = "lv_commercial_medium"
static var active_campaign_results: Dictionary = {}

# --- LUNAR SOUTH POLAR CRATER TARGETS (80°S – 90°S) ---
static func get_all_craters() -> Dictionary:
	return {
		"crater_shackleton": {
			"id": "crater_shackleton",
			"name": "Shackleton Crater",
			"lat_deg": -89.9,
			"lon_deg": 0.0,
			"diameter_km": 21.0,
			"depth_km": 4.2,
			"psr_area_km2": 280.0,
			"baseline_depression_pct": 24.5,
			"confidence": "High (Quasi-Permanent Rim Illumination)",
			"science_weight": 1.25,
			"description": "Centered almost precisely on the lunar South Pole. Rim peaks receive up to 86-90% annual illumination, while the 4.2 km deep interior remains in permanent shadow at <90 K.",
			"scientific_proxy_note": "Epithermal neutron moderation indicates hydrogen enrichment within the permanently shadowed floor. This serves as a proxy indicator for hydrogen-bearing regolith; it does not confirm pure water ice."
		},
		"crater_shoemaker": {
			"id": "crater_shoemaker",
			"name": "Shoemaker Crater",
			"lat_deg": -88.1,
			"lon_deg": 45.9,
			"diameter_km": 51.0,
			"depth_km": 2.5,
			"psr_area_km2": 960.0,
			"baseline_depression_pct": 34.0,
			"confidence": "Very High (Prominent Flux Depression)",
			"science_weight": 1.4,
			"description": "Deep impact basin exhibiting one of the largest continuous epithermal neutron flux depressions observed by Lunar Prospector. Floor temperatures hover near 40 K.",
			"scientific_proxy_note": "A strong neutron flux reduction (-34%) indicates elevated hydrogen abundance proxy in the top meter of regolith; it does not confirm pure surface water ice."
		},
		"crater_faustini": {
			"id": "crater_faustini",
			"name": "Faustini Crater",
			"lat_deg": -87.3,
			"lon_deg": 77.0,
			"diameter_km": 39.0,
			"depth_km": 2.1,
			"psr_area_km2": 620.0,
			"baseline_depression_pct": 21.0,
			"confidence": "High (Ultra-Cold Thermal Trap)",
			"science_weight": 1.15,
			"description": "Located adjacent to Shoemaker. Heavily degraded rim with an ultra-cold permanent shadow trap capable of sequestering volatile species over geological timescales.",
			"scientific_proxy_note": "Moderate epithermal neutron depression proxy detected; does not confirm pure surface water ice."
		},
		"crater_cabeus": {
			"id": "crater_cabeus",
			"name": "Cabeus Crater",
			"lat_deg": -84.9,
			"lon_deg": -35.5,
			"diameter_km": 100.0,
			"depth_km": 4.0,
			"psr_area_km2": 1050.0,
			"baseline_depression_pct": 38.5,
			"confidence": "Ground Truth (NASA LCROSS Impact Site)",
			"science_weight": 1.5,
			"description": "Site of the 2009 NASA LCROSS kinetic impact, which lofted an ejecta plume confirming hydroxyl, water vapor, and simple organics in the permanently shadowed floor.",
			"scientific_proxy_note": "Strongest regional epithermal neutron absorption feature proxy cross-calibrated against LCROSS ground truth; does not confirm pure surface water ice in un-impacted areas."
		},
		"crater_amundsen": {
			"id": "crater_amundsen",
			"name": "Amundsen Crater",
			"lat_deg": -84.5,
			"lon_deg": 82.8,
			"diameter_km": 105.0,
			"depth_km": 3.0,
			"psr_area_km2": 780.0,
			"baseline_depression_pct": 18.0,
			"confidence": "Moderate-High (Complex Terraced Walls)",
			"science_weight": 1.1,
			"description": "Large complex polar impact structure featuring distinct terraced rim walls and central peak. Contains isolated cold traps sheltered beneath southern interior scarps.",
			"scientific_proxy_note": "Localized neutron flux depression proxy confined to southern wall shadows; does not confirm pure surface water ice."
		},
		"crater_haworth": {
			"id": "crater_haworth",
			"name": "Haworth Crater",
			"lat_deg": -87.4,
			"lon_deg": -5.1,
			"diameter_km": 35.0,
			"depth_km": 2.3,
			"psr_area_km2": 450.0,
			"baseline_depression_pct": 26.0,
			"confidence": "High (Deep Cold Pocket)",
			"science_weight": 1.2,
			"description": "Asymmetric crater nestled between Shoemaker and Faustini. High rim-to-floor depth ratio keeps >70% of crater floor below 50 K year-round.",
			"scientific_proxy_note": "Consistent epithermal neutron deficit detected as a volatile proxy; does not confirm pure surface water ice."
		}
	}

static func get_crater(id: String) -> Dictionary:
	return get_target(id)

# --- EARTH CLIMATE SENTINEL TARGETS (6 GLOBAL CLIMATE SENTINELS) ---
static func get_all_climate_sentinels() -> Dictionary:
	return {
		"sentinel_greenland": {
			"id": "sentinel_greenland",
			"name": "Greenland Ice Sheet (Summit)",
			"lat_deg": 72.6,
			"lon_deg": -38.5,
			"diameter_km": 1100.0,
			"baseline_metric": "3,200m Ice Elevation / Melt Albedo",
			"confidence": "High (Summit Station Ground-Truth)",
			"science_weight": 1.40,
			"description": "Interior ice sheet reservoir. Satellite radar altimetry and multispectral radiometry track surface melt extent and ice sheet thinning rates.",
			"scientific_proxy_note": "Radar elevation loss serves as a proxy for ice sheet volume balance; firn compaction requires modeling corrections."
		},
		"sentinel_antarctic_peninsula": {
			"id": "sentinel_antarctic_peninsula",
			"name": "Antarctic Peninsula (Larsen C)",
			"lat_deg": -67.5,
			"lon_deg": -62.5,
			"diameter_km": 850.0,
			"baseline_metric": "Ice Shelf Freeboard / Calving Flux",
			"confidence": "High (CryoSat-2 Altimetry Heritage)",
			"science_weight": 1.45,
			"description": "Vulnerable polar ice shelf barrier monitoring grounding-line stability and major tabular iceberg calving detachment.",
			"scientific_proxy_note": "Radar freeboard height proxy measures floating ice shelf thickness; tidal flexure and firn air content introduce modeling uncertainty."
		},
		"sentinel_amazon_basin": {
			"id": "sentinel_amazon_basin",
			"name": "Amazon Basin Carbon Sink",
			"lat_deg": -3.4,
			"lon_deg": -62.2,
			"diameter_km": 2400.0,
			"baseline_metric": "Vegetation Index (NDVI) / CO2 Column",
			"confidence": "High (OCO-2 / MODIS Heritage)",
			"science_weight": 1.30,
			"description": "Tropical rainforest biosphere acting as a global continental carbon sink. Tracks seasonal photosynthesis and drought-induced canopy stress.",
			"scientific_proxy_note": "Atmospheric column CO2 (XCO2) serves as a proxy for continental carbon uptake; cloud masking requires rigorous optical filtering."
		},
		"sentinel_sahel_boundary": {
			"id": "sentinel_sahel_boundary",
			"name": "Sahel Desertification Boundary",
			"lat_deg": 14.5,
			"lon_deg": 2.1,
			"diameter_km": 1800.0,
			"baseline_metric": "Soil Moisture & Aridity Gradient",
			"confidence": "Moderate-High (Copernicus Land Heritage)",
			"science_weight": 1.15,
			"description": "Semi-arid ecological buffer zone between Sahara Desert and Savanna. Tracks seasonal green-up pulses and progressive desertification.",
			"scientific_proxy_note": "Normalized Difference Vegetation Index (NDVI) acts as a proxy for vegetative biomass; atmospheric dust requires correction."
		},
		"sentinel_north_atlantic": {
			"id": "sentinel_north_atlantic",
			"name": "North Atlantic Surface Indicators for AMOC Research",
			"lat_deg": 57.0,
			"lon_deg": -35.0,
			"diameter_km": 1500.0,
			"baseline_metric": "Surface Sea Temperature & Altimetry Indicators",
			"confidence": "High (Surface Proxy / Sentinel-3 Heritage)",
			"science_weight": 1.25,
			"description": "Monitors sea surface temperature anomalies and steric height gradients in the subpolar gyre. Note: A single satellite with optical/SAR payloads does not measure full-depth AMOC volume transport; orbital surface observations provide valuable indicators but cannot replace dedicated in-situ mooring arrays (e.g. RAPID/OSNAP) required for sustained AMOC monitoring.",
			"scientific_proxy_note": "Surface skin temperature and radar topography serve as surface proxy indicators for subpolar gyre dynamics; full-depth ocean transport requires in-situ oceanographic sensor networks."
		},
		"sentinel_siberian_permafrost": {
			"id": "sentinel_siberian_permafrost",
			"name": "Siberian Tundra Permafrost",
			"lat_deg": 68.5,
			"lon_deg": 112.0,
			"diameter_km": 1600.0,
			"baseline_metric": "Atmospheric Methane (XCH4) Column",
			"confidence": "Very High (TROPOMI Heritage)",
			"science_weight": 1.35,
			"description": "Continuous sub-Arctic permafrost storing immense ancient organic carbon. Sounding spectrometer monitors summer thaw methane degassing anomalies.",
			"scientific_proxy_note": "Column-averaged methane proxy indicates wetland and thermokarst thaw emissions; high solar zenith angles limit winter readings."
		}
	}

static func get_targets_for_scenario(scenario_id: String = "") -> Dictionary:
	if scenario_id == "":
		scenario_id = MissionScenario.get_active_scenario_id()
	if scenario_id == "earth_climate_sentinel" or scenario_id == "ecs_01":
		return get_all_climate_sentinels()
	return get_all_craters()

static func get_target(id: String, scenario_id: String = "") -> Dictionary:
	if scenario_id == "":
		scenario_id = MissionScenario.get_active_scenario_id()
	var targets = get_targets_for_scenario(scenario_id)
	if targets.has(id):
		return targets[id]
	var all_cr = get_all_craters()
	if all_cr.has(id):
		return all_cr[id]
	var all_cl = get_all_climate_sentinels()
	if all_cl.has(id):
		return all_cl[id]
	return all_cr["crater_shackleton"]

# --- OPERATIONAL MODES ---
static func get_all_modes() -> Dictionary:
	return {
		"mode_nominal": {
			"id": "mode_nominal",
			"name": "Nominal Science Survey",
			"tag": "Balanced Routine Operations",
			"power_multiplier": 1.0,
			"data_multiplier": 1.0,
			"science_multiplier": 1.0,
			"downlink_multiplier": 1.0,
			"description": "Standard continuous mapping routine. Balances instrument integration time, thermal heater cycling, and routine DSN contact schedules.",
			"tradeoff": "Even resource consumption across mass, power, and data downlink."
		},
		"mode_high_res": {
			"id": "mode_high_res",
			"name": "High-Resolution Mapping",
			"tag": "Max Science (+50%) / High Power (+35%)",
			"power_multiplier": 1.35,
			"data_multiplier": 1.60,
			"science_multiplier": 1.50,
			"downlink_multiplier": 1.0,
			"description": "Overclocks payload detector integration rates and activates precision reaction wheel pointing over target crater PSRs. Maximizes scientific yield (+50%).",
			"tradeoff": "Draws 35% more power (higher battery Depth of Discharge in eclipse) and produces 60% more data, risking buffer overflow if downlink passes are limited."
		},
		"mode_conserve": {
			"id": "mode_conserve",
			"name": "Power Conservation Mode",
			"tag": "Low Power (-35%) / Low Science (-50%)",
			"power_multiplier": 0.65,
			"data_multiplier": 0.50,
			"science_multiplier": 0.50,
			"downlink_multiplier": 0.85,
			"description": "Throttles non-critical avionics, duty-cycles secondary sensors, and minimizes reaction wheel slew maneuvers to conserve battery energy and protect cell lifespan.",
			"tradeoff": "Reduces science collection by 50%, but keeps battery DoD low during extended eclipses or degraded power generation."
		},
		"mode_comm_priority": {
			"id": "mode_comm_priority",
			"name": "Communication & Downlink Priority",
			"tag": "Max Downlink (+60%) / Instrument Throttled",
			"power_multiplier": 1.20,
			"data_multiplier": 0.70,
			"science_multiplier": 0.75,
			"downlink_multiplier": 1.60,
			"description": "Powers traveling-wave tube amplifier (TWTA) at full output and requests extended DSN ground station pass windows to flush onboard solid-state data recorder.",
			"tradeoff": "Flushes recorder buffer to prevent data overflow loss, but draws 20% extra power and reduces instrument observing time."
		}
	}

static func get_mode(id: String) -> Dictionary:
	var modes = get_all_modes()
	return modes.get(id, modes["mode_nominal"])

# --- 12 MONTHLY OPERATIONAL WINDOWS & DETERMINISTIC EVENTS ---
static func get_window_event(window_idx: int) -> Dictionary:
	var events = {
		1: {
			"window": 1,
			"name": "Orbit Commissioning & Instrument Baseline",
			"condition": "Post-insertion checkout. Spacecraft outgassing complete. Primary solar arrays locked on Sun.",
			"flavor": "Initial polar sweeps over Shackleton Crater confirm neutron detector high-voltage stability. Cosmic ray background baseline established.",
			"effect_type": "nominal",
			"power_delta_pct": 0.0,
			"downlink_delta_pct": 0.0,
			"science_bonus": 5.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Nominal Science Survey is ideal for baseline commissioning."
		},
		2: {
			"window": 2,
			"name": "Maximum Orbital Eclipse Season",
			"condition": "Sun-Earth-Moon orbital plane alignment forces maximum 48-minute orbital shadows behind the Moon.",
			"flavor": "Solar arrays produce zero power for ~41% of each 118-minute orbit. Batteries must sustain bus voltage through deep thermal chilling.",
			"effect_type": "eclipse_stress",
			"power_delta_pct": -15.0, # Net solar generation reduced due to edge-on aspect
			"downlink_delta_pct": 0.0,
			"science_bonus": 0.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Power Conservation or Nominal mode prevents excessive battery Depth-of-Discharge (DoD)."
		},
		3: {
			"window": 3,
			"name": "Solar Energetic Particle (SEP) Event",
			"condition": "M-class solar coronal mass ejection bombards cislunar space with high-energy proton flux.",
			"flavor": "Single-event upsets (SEUs) detected in star tracker sensors. Radiation-hardened EDAC memory corrects solid-state buffer bitflips.",
			"effect_type": "radiation",
			"power_delta_pct": -5.0, # Minor solar cell lattice displacement
			"downlink_delta_pct": -15.0, # Atmospheric ionospheric noise at ground stations
			"science_bonus": 0.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Comm Priority mode helps push critical science packets through noisy channels.",
			"emergency_event": {
				"id": "event_solar_storm",
				"title": "EMERGENCY: Severe Solar Particle Storm Approaching",
				"scenario": "A fast coronal mass ejection is bombarding cislunar space with high-energy proton flux. Note: Radiation-risk calculations and equipment degradation rates are in-game educational simulation models.",
				"default_choice_id": "choice_safe_mode",
				"choices": [
					{
						"id": "choice_safe_mode",
						"name": "FULL SAFE MODE",
						"tag": "Protective Stance",
						"description": "Suspend non-essential science instruments while maintaining essential power, thermal control, and communications. Reduces science output during the event.",
						"impact_summary": "Power: -40% load | Health: Protected (0% modeled wear) | Science: -40% yield this window",
						"effects": {
							"power_load_multiplier": 0.60,
							"equipment_health_delta": 0.0,
							"science_multiplier": 0.60,
							"persistent_sensor_noise": false
						}
					},
					{
						"id": "choice_partial_protection",
						"name": "PARTIAL PROTECTION (ATTITUDE STANCE)",
						"tag": "Balanced Stance",
						"description": "Perform an attitude-control maneuver to maintain sun/comm alignment. Disable vulnerable payloads while keeping selected protected secondary systems active. (Attitude-control maneuver only; does not deflect solar protons).",
						"impact_summary": "Power: -15% load | Health: Minimal modeled wear (-2.5%) | Science: Preserves 75% yield | Lasting: No persistent noise",
						"effects": {
							"power_load_multiplier": 0.85,
							"equipment_health_delta": -2.5,
							"science_multiplier": 0.75,
							"persistent_sensor_noise": false
						}
					},
					{
						"id": "choice_continue_science",
						"name": "CONTINUE OPERATIONS",
						"tag": "High-Risk Stance",
						"description": "Continue active observations throughout the storm. Accept increased modeled radiation-related equipment degradation in exchange for observation continuity.",
						"impact_summary": "Power: +25% load | Health: -7.5% modeled equipment wear | Science: Full points preserved | Lasting: Modeled sensor SEU noise in future windows",
						"effects": {
							"power_load_multiplier": 1.25,
							"equipment_health_delta": -7.5,
							"science_multiplier": 1.15,
							"persistent_sensor_noise": true
						}
					}
				]
			}
		},
		4: {
			"window": 4,
			"name": "DSN Madrid Antenna Maintenance Outage",
			"condition": "Scheduled azimuth bearing overhaul at DSN Madrid Complex (DSS-63) restricts available downlink windows.",
			"flavor": "Downlink scheduling conflicts shift tracking passes to Goldstone and Canberra. Data buffer risk elevates.",
			"effect_type": "downlink_bottleneck",
			"power_delta_pct": 0.0,
			"downlink_delta_pct": -40.0, # 40% loss of downlink contact time
			"science_bonus": 0.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Comm Priority mode or Power Conservation avoids solid-state recorder overflow and permanent data loss.",
			"emergency_event": {
				"id": "event_dsn_outage",
				"title": "COMMUNICATION EMERGENCY: DSN Madrid Tracking Outage",
				"scenario": "A critical mechanical bearing overhaul and gearbox fault at DSS-63 has taken Madrid 70m off-air. Primary X-band contact is unavailable for this pass.",
				"default_choice_id": "choice_store_data",
				"choices": [
					{
						"id": "choice_store_data",
						"name": "STORE DATA IN SOLID-STATE BUFFER",
						"tag": "Buffer Science Data",
						"description": "Halt deep-space transmissions and hold all generated spectra in onboard solid-state recorder until Madrid service resumes.",
						"impact_summary": "Downlink: 0 Gbit | Buffer: Surges with +100% data | Cost: $0M | Risk: Overflow if next pass is missed",
						"effects": {
							"downlink_multiplier": 0.0,
							"ops_cost_delta_m": 0.0,
							"extra_power_w": 0.0,
							"buffer_risk": true
						}
					},
					{
						"id": "choice_backup_comm",
						"name": "USE BACKUP COMMUNICATION (COMMERCIAL S-BAND)",
						"tag": "Active Relay Strategy",
						"description": "Reconfigure transmitter to utilize commercial ground station networks and emergency S-band relays at reduced data rate.",
						"impact_summary": "Downlink: Transmit 55% at reduced rate | Cost: +$0.5M commercial fee | Power: +20W RF boost | Buffer: Safely drained",
						"effects": {
							"downlink_multiplier": 0.55,
							"ops_cost_delta_m": 0.5,
							"extra_power_w": 20.0,
							"buffer_risk": false
						}
					}
				]
			}
		},
		5: {
			"window": 5,
			"name": "Shoemaker Crater Epithermal Anomaly",
			"condition": "Repeated low-altitude ground tracks directly traverse Shoemaker's permanently shadowed floor.",
			"flavor": "Epithermal neutron moderation detects an extraordinary -34% flux depression over Shoemaker PSR! High-priority science opportunity.",
			"effect_type": "science_opportunity",
			"power_delta_pct": 0.0,
			"downlink_delta_pct": 0.0,
			"science_bonus": 15.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Target Shoemaker Crater with High-Resolution Mapping to harvest maximum science points!"
		},
		6: {
			"window": 6,
			"name": "Mid-Mission Mascon Gravitational Perturbation",
			"condition": "Cumulative gravitational perturbations from South Pole-Aitken basin mascons depress perilune altitude.",
			"flavor": "Autonomous orbit determination triggers required stationkeeping trim burn to maintain nominal 100 km circular altitude.",
			"effect_type": "propulsion_burn",
			"power_delta_pct": 0.0,
			"downlink_delta_pct": 0.0,
			"science_bonus": 0.0,
			"sk_burn_required_ms": 15.0, # Slightly higher SK trim
			"recommendation": "Ensure propellant reserve remains positive for ongoing orbit maintenance."
		},
		7: {
			"window": 7,
			"name": "Deep Eclipse Thermal Shock & Battery Warning",
			"condition": "Sun-Earth-Moon orbital plane precession forces extended 48-minute orbital shadows behind the Moon under severe radiator thermal chill.",
			"flavor": "Spacecraft battery voltage approaches the critical low-bus threshold during eclipse transit. Battery health is at risk of permanent degradation.",
			"effect_type": "eclipse_stress",
			"power_delta_pct": -10.0,
			"downlink_delta_pct": 0.0,
			"science_bonus": 0.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Shedding non-critical loads protects battery longevity; continuing full ops risks brownout and accelerated degradation.",
			"emergency_event": {
				"id": "event_battery_emergency",
				"title": "ELECTRICAL EMERGENCY: Low Battery Reserve in Shadow",
				"scenario": "The battery reserve is falling below the safe operating threshold during an extended orbital eclipse shadow pass.",
				"default_choice_id": "choice_shed_load",
				"choices": [
					{
						"id": "choice_shed_load",
						"name": "SHED NON-CRITICAL LOAD",
						"tag": "Power Conservation",
						"description": "Temporarily disable non-essential instrument heaters and secondary sensors to lower eclipse power demand.",
						"impact_summary": "Power: -35% load | Battery: Protected (<42% DoD) | Science: -35% yield this window",
						"effects": {
							"power_load_multiplier": 0.65,
							"battery_health_bonus": 1.5,
							"science_multiplier": 0.65
						}
					},
					{
						"id": "choice_continue_full_ops",
						"name": "CONTINUE FULL OPERATIONS",
						"tag": "Maximum Science Risk",
						"description": "Keep all payload sensors and heaters operating at full power throughout the eclipse shadow.",
						"impact_summary": "Power: Full load | Battery: Deep discharge (>85% DoD, -5.0% battery SOH loss) | Risk: Elevated brownout risk",
						"effects": {
							"power_load_multiplier": 1.0,
							"battery_health_penalty": 5.0,
							"equipment_health_penalty": 2.5,
							"science_multiplier": 1.0
						}
					}
				]
			}
		},
		8: {
			"window": 8,
			"name": "Cabeus Crater LCROSS Cross-Calibration Pass",
			"condition": "Orbital precession positions ground track directly over the LCROSS kinetic impact coordinates in Cabeus.",
			"flavor": "Spacecraft correlates orbital neutron moderation curves with historic in-situ water vapor ejecta data.",
			"effect_type": "science_opportunity",
			"power_delta_pct": 0.0,
			"downlink_delta_pct": 0.0,
			"science_bonus": 18.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Select Cabeus Crater as primary target to lock in definitive cross-calibrated science."
		},
		9: {
			"window": 9,
			"name": "High Lunar Albedo Thermal Beta Transition",
			"condition": "Beta angle shift exposes nadir radiators to high thermal infrared back-radiation from sunlit lunar terrain.",
			"flavor": "Thermal control subsystem loops heat pipes and adjusts louvers to keep solid-state recorder below +35°C.",
			"effect_type": "thermal_stress",
			"power_delta_pct": -8.0, # Radiator efficiency drop
			"downlink_delta_pct": 0.0,
			"science_bonus": 0.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Avoid continuous high-power overclocking if thermal margins are tight."
		},
		10: {
			"window": 10,
			"name": "DSN 70m Goldstone Dedicated Science Intercept",
			"condition": "Deep Space Network allocates uninterrupted 8-hour passes via Goldstone DSS-14 70-meter dish.",
			"flavor": "Unprecedented downlink bandwidth available! High-gain antenna locks on X/Ka-band downlink.",
			"effect_type": "downlink_surge",
			"power_delta_pct": 0.0,
			"downlink_delta_pct": 60.0, # 60% extra downlink capacity
			"science_bonus": 8.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Great window to run High-Resolution Mapping; the DSN surge easily empties the data buffer!"
		},
		11: {
			"window": 11,
			"name": "Secondary Lunar Mascon Orbit Trim",
			"condition": "Late-mission orbit maintenance burn to counteract eccentricity growth over Crisium/Serenitatis mascon tracks.",
			"flavor": "Spacecraft main engine fires a precise stationkeeping delta-V pulse. Trajectory remains rock-solid.",
			"effect_type": "propulsion_burn",
			"power_delta_pct": 0.0,
			"downlink_delta_pct": 0.0,
			"science_bonus": 0.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Monitor remaining propellant mass and reserve delta-V margin."
		},
		12: {
			"window": 12,
			"name": "Final Campaign Mapping Sweep & End-of-Primary Mission",
			"condition": "Final operational window of the 365-day science mission. Comprehensive polar coverage compiled.",
			"flavor": "Spacecraft executes final polar volatile sweep across all 6 crater sectors. Mission science archive compiled for transfer to planetary data system.",
			"effect_type": "campaign_finale",
			"power_delta_pct": 0.0,
			"downlink_delta_pct": 20.0,
			"science_bonus": 12.0,
			"sk_burn_required_ms": 12.5,
			"recommendation": "Focus on any under-surveyed crater to maximize total mission completion score!"
		}
	}
	return events.get(window_idx, events[1])

static func get_emergency_event(window_idx: int) -> Dictionary:
	var ev = get_window_event(window_idx)
	return ev.get("emergency_event", {})
