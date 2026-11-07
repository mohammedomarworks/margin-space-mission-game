class_name Helios4CampaignData
extends RefCounted

# ==============================================================================
# MARGIN — HELIOS-4: THE LAST LINE OF DEFENSE
# Flagship Cooperative 3D Spaceflight Campaign Data Architecture
# Story Year: 2038
# Objective: Design, construct, launch, navigate, and commission the HELIOS-4
# solar-weather early-warning spacecraft into a stable halo orbit at Sun-Earth L1
# (~1.5 million km sunward from Earth).
# ==============================================================================

enum Stage {
	PROLOGUE = 0,
	TEAM_ASSIGNMENT = 1,
	PHASE_1_HANGAR = 2,
	ENGINEERING_REVIEW = 3,
	PHASE_2_LAUNCH = 4,
	PHASE_3_TRANSFER = 5,
	PHASE_4_CRISIS = 6,
	PHASE_5_L1_INSERTION = 7,
	PHASE_6_COMMISSIONING = 8,
	MISSION_DEBRIEF = 9,
	CAMPAIGN_COMPLETED = 10
}

# --- ROLES ---
const ROLE_PROPULSION: String = "propulsion"
const ROLE_STRUCTURAL: String = "structural"
const ROLE_ASTROGATOR: String = "astrogator"
const ROLE_SYSTEMS: String = "systems"

const ROLE_METADATA: Dictionary = {
	ROLE_PROPULSION: {
		"id": ROLE_PROPULSION,
		"title": "Propulsion Engineer",
		"callsign": "PROPULSION",
		"color": Color(0.98, 0.55, 0.15), # Aerospace Orange
		"icon": "🚀",
		"hangar_focus": "Engine selection, thrust rating, fuel tank sizing, propellant mass, specific impulse (Isp), and multi-stage Delta-V.",
		"flight_focus": "Ignition sequencing, throttle management, propellant consumption, and staging separation timing."
	},
	ROLE_STRUCTURAL: {
		"id": ROLE_STRUCTURAL,
		"title": "Structural Architect",
		"callsign": "STRUCTURES",
		"color": Color(0.35, 0.85, 0.55), # Emerald Green
		"icon": "🏗",
		"hangar_focus": "Structural framework, dry mass, fairing envelope, Center of Mass (CoM) vs Center of Pressure (CoP), and static margins.",
		"flight_focus": "Dynamic pressure monitoring, Max-Q structural corridor, G-force tolerance, and interstage clearance."
	},
	ROLE_ASTROGATOR: {
		"id": ROLE_ASTROGATOR,
		"title": "Astrogator",
		"callsign": "TRAJECTORY",
		"color": Color(0.25, 0.75, 1.0), # Deep Cyan
		"icon": "🧭",
		"hangar_focus": "Launch azimuth, Earth-to-L1 transfer trajectory, injection Delta-V budgets, and Sun-Earth L1 halo-orbit insertion planning.",
		"flight_focus": "Gravity turn pitch profile, flight corridor tracking, mid-course correction maneuvers, and halo-orbit insertion."
	},
	ROLE_SYSTEMS: {
		"id": ROLE_SYSTEMS,
		"title": "Systems Officer",
		"callsign": "SYSTEMS",
		"color": Color(0.85, 0.45, 0.95), # Royal Magenta
		"icon": "⚡",
		"hangar_focus": "Solar power generation vs electrical load, battery reserves, rad-hardened avionics, magnetometer, Faraday cup, and deep-space comms.",
		"flight_focus": "Electrical balance, sensor deployment, DSN communication tracking, safe-mode mitigation, and early-warning telemetry transmission."
	}
}

# --- STAGE DESCRIPTIONS ---
const STAGE_METADATA: Dictionary = {
	Stage.PROLOGUE: {
		"title": "PROLOGUE: THE 2038 CRISIS",
		"subtitle": "Solar Superstorm Alert & Emergency Authorization",
		"desc": "During an elevated solar-activity peak in 2038, existing space-weather early-warning sentinels at Sun-Earth L1 have degraded. Active Region AR-4890 threatens an extreme CME superstorm. An emergency mission — HELIOS-4 — is authorized to deploy a replacement sentinel to L1 before the CME erupts."
	},
	Stage.TEAM_ASSIGNMENT: {
		"title": "TEAM ASSIGNMENT",
		"subtitle": "Pass-and-Play Cooperative Crew Allocation",
		"desc": "Allocate 1 to 4 local specialists to command roles: Propulsion Engineer, Structural Architect, Astrogator, and Systems Officer."
	},
	Stage.PHASE_1_HANGAR: {
		"title": "PHASE 1: THE HANGAR",
		"subtitle": "3D Modular Launch Vehicle & Probe Engineering",
		"desc": "Assemble the multi-stage launch vehicle and HELIOS-4 solar weather probe. Balance thrust, mass, Delta-V, aerodynamics, and power."
	},
	Stage.ENGINEERING_REVIEW: {
		"title": "FLIGHT READINESS REVIEW",
		"subtitle": "Multi-Specialist Go / No-Go Launch Gate",
		"desc": "Validate critical engineering thresholds: liftoff TWR, multi-stage Delta-V, structural static margin, and electrical balance."
	},
	Stage.PHASE_2_LAUNCH: {
		"title": "PHASE 2: EARTH LAUNCH & MAX-Q",
		"subtitle": "Playable 3D Ascent, Dynamic Pressure & Staging",
		"desc": "Pilot the rocket through the dense atmosphere. Throttle back through Max-Q, execute the gravity turn, separate Stage 1, and inject into transfer orbit."
	},
	Stage.PHASE_3_TRANSFER: {
		"title": "PHASE 3: DEEP SPACE TRANSFER",
		"subtitle": "1.5 Million Kilometers Sunward to Sun-Earth L1",
		"desc": "Navigate the probe toward Sun-Earth L1 while Active Region AR-4890 continues developing. Orient solar arrays sunward, track DSN ground stations, and perform precision mid-course corrections."
	},
	Stage.PHASE_4_CRISIS: {
		"title": "PHASE 4: SPACE WEATHER EMERGENCY",
		"subtitle": "Interactive Tactical Decision Scenarios",
		"desc": "Survive deep-space precursor hazards: relativistic solar proton flux, micrometeoroid propellant line leakage, and star tracker blackout."
	},
	Stage.PHASE_5_L1_INSERTION: {
		"title": "PHASE 5: L1 HALO-ORBIT INSERTION",
		"subtitle": "Sun-Earth L1 Capture & Stationkeeping Lock",
		"desc": "Execute the halo-orbit insertion burn around the unstable L1 saddle point, verify periodic 3D orbit parameters, and secure stationkeeping propellant reserves (modeled as an educational game assumption)."
	},
	Stage.PHASE_6_COMMISSIONING: {
		"title": "PHASE 6: PROBE COMMISSIONING & WARNING TRANSMISSION",
		"subtitle": "Science Instrument Activation & Earth Link",
		"desc": "Deploy the magnetometer boom, activate the Faraday Cup plasma analyzer, establish the DSN carrier, and detect the arriving CME shockwave to beam the early-warning packet to Earth."
	},
	Stage.MISSION_DEBRIEF: {
		"title": "MISSION DEBRIEF",
		"subtitle": "Performance Scorecard & Scientific Early-Warning Audit",
		"desc": "Review composite mission grading, role contributions, remaining margins, and space weather warning lead time."
	},
	Stage.CAMPAIGN_COMPLETED: {
		"title": "CAMPAIGN COMPLETED",
		"subtitle": "HELIOS-4 Operational at Sun-Earth L1",
		"desc": "Earth has a working solar-weather sentinel standing guard 1.5 million kilometers sunward."
	}
}

# --- PERSISTENT CAMPAIGN STATE ---
static var current_stage: Stage = Stage.PROLOGUE
static var highest_unlocked_stage: Stage = Stage.PROLOGUE
static var player_count: int = 1
static var team_player_names: Dictionary = {
	ROLE_PROPULSION: "Specialist 1",
	ROLE_STRUCTURAL: "Specialist 2",
	ROLE_ASTROGATOR: "Specialist 3",
	ROLE_SYSTEMS: "Specialist 4"
}
static var active_role: String = ROLE_PROPULSION

# Game Mode: Challenge (10 min timer) vs Practice (Untimed)
static var is_timed_challenge: bool = true
static var hangar_time_remaining: float = 600.0 # 10 minutes

# Active Vehicle & Spacecraft Configuration
static var vehicle_config: Dictionary = {}
static var probe_config: Dictionary = {}

# Cooperative Team Decision & Attribution History
static var team_decision_log: Array = []

static func record_team_decision(role_id: String, category: String, description: String) -> void:
	team_decision_log.append({
		"role": role_id,
		"category": category,
		"description": description
	})

# Flight Simulation Variables
static var launch_telemetry: Dictionary = {}
static var transfer_telemetry: Dictionary = {}
static var crisis_results: Dictionary = {}
static var l1_telemetry: Dictionary = {}
static var final_debrief_data: Dictionary = {}

# Save File Path
const SAVE_PATH: String = "user://helios4_campaign.json"
const L1_DISTANCE_KM: float = 1500000.0

# Authoritative early-warning calculation: warning_minutes = distance_km / shock_velocity_km_per_s / 60
static func calculate_warning_lead_time_minutes(shock_velocity_km_s: float, distance_km: float = L1_DISTANCE_KM) -> float:
	if shock_velocity_km_s <= 0.0 or distance_km <= 0.0:
		return 0.0
	return distance_km / shock_velocity_km_s / 60.0

# --- DEFAULT CONFIGURATIONS ---

static func get_default_vehicle_config() -> Dictionary:
	return {
		# Stage 1: Booster
		"stage1_engine": "booster_hydrolox_quad",
		"stage1_thrust_kn": 480.0, # 480 kN liftoff thrust for 34,700 kg vehicle -> 1.41 TWR
		"stage1_isp_s": 320.0,
		"stage1_fuel_mass_kg": 24000.0,
		"stage1_dry_mass_kg": 2800.0,
		"stage1_fins": "aero_grid_fins", # Increases aerodynamic stability (pulls CoP toward base)
		"stage1_fin_mass_kg": 220.0,
		
		# Stage 2: Upper Stage
		"stage2_engine": "vac_hydrolox_single",
		"stage2_thrust_kn": 65.0,
		"stage2_isp_s": 450.0,
		"stage2_fuel_mass_kg": 5400.0,
		"stage2_dry_mass_kg": 750.0,
		"interstage_mass_kg": 320.0,
		
		# Fairing
		"fairing_type": "composite_aero_fairing",
		"fairing_mass_kg": 420.0,
		"fairing_diameter_m": 2.4,
		"fairing_height_m": 4.8,
		
		# Astrogator Trajectory & Launch Window Selection
		"trajectory_mode": "direct_injection", # "direct_injection" (110d) vs "phased_wsb" (135d)
		
		# Total vehicle cost
		"vehicle_cost_m": 48.0
	}

static func get_default_probe_config() -> Dictionary:
	return {
		"bus_structure": "struct_carbon_composite",
		"structure_mass_kg": 180.0,
		"structure_cost_m": 14.0,
		
		# Propulsion (Monoprop Hydrazine for MCC, HOI, and Stationkeeping)
		"propulsion_type": "prop_dual_mode_biprop",
		"propellant_mass_kg": 320.0,
		"propellant_dry_mass_kg": 55.0,
		"probe_isp_s": 315.0,
		"propulsion_cost_m": 12.0,
		
		# Power Generation (GaAs Triple-Junction Solar Wings)
		"solar_array_type": "power_tri_junction_wings",
		"solar_array_area_m2": 6.5,
		"solar_efficiency": 0.31,
		"solar_mass_kg": 45.0,
		"solar_cost_m": 10.0,
		
		# Battery
		"battery_type": "batt_li_ion_rad_hard",
		"battery_capacity_wh": 1200.0,
		"battery_mass_kg": 28.0,
		"battery_cost_m": 6.0,
		
		# Avionics & Computer
		"computer_type": "comp_rad_hard_quad_core",
		"avionics_power_w": 65.0,
		"computer_mass_kg": 24.0,
		"computer_cost_m": 12.0,
		
		# ADCS & Star Trackers
		"adcs_type": "adcs_reaction_wheels_star_tracker",
		"adcs_power_w": 35.0,
		"adcs_mass_kg": 26.0,
		"adcs_cost_m": 7.5,
		
		# Thermal Control
		"thermal_type": "thermal_active_louvers_mli",
		"thermal_power_w": 25.0,
		"thermal_mass_kg": 18.0,
		"thermal_cost_m": 4.5,
		
		# Scientific Payloads (DSCOVR-inspired)
		"instruments": {
			"faraday_cup": {
				"id": "inst_faraday_cup",
				"name": "Faraday Cup Solar Wind Plasma Analyzer",
				"heritage": "NASA DSCOVR PlasMag & SOHO CELIAS",
				"mass_kg": 14.0,
				"power_w": 18.0,
				"cost_m": 9.0,
				"data_rate_kbps": 8.0
			},
			"magnetometer": {
				"id": "inst_fluxgate_mag",
				"name": "Triaxial Fluxgate Magnetometer & 4m Deployable Boom",
				"heritage": "NASA DSCOVR Magnetometer",
				"mass_kg": 12.0,
				"power_w": 12.0,
				"cost_m": 8.0,
				"data_rate_kbps": 6.0
			},
			"radiation_monitor": {
				"id": "inst_solar_particle_rad",
				"name": "Solar Energetic Particle (SEP) Spectrometer",
				"heritage": "NOAA GOES EPS & DSCOVR Space Weather Suite",
				"mass_kg": 9.0,
				"power_w": 15.0,
				"cost_m": 6.0,
				"data_rate_kbps": 4.0
			}
		},
		
		# Communications
		"comms_type": "comm_gimbaled_x_ka_dish",
		"antenna_diameter_m": 1.2,
		"comms_power_w": 45.0,
		"comms_mass_kg": 22.0,
		"comms_cost_m": 9.0,
		"link_margin_db": 4.2
	}

# --- MATHEMATICAL ENGINE: MULTI-STAGE ROCKET & PROBE PHYSICS ---

static func calculate_hangar_telemetry() -> Dictionary:
	var v_cfg = vehicle_config if not vehicle_config.is_empty() else get_default_vehicle_config()
	var p_cfg = probe_config if not probe_config.is_empty() else get_default_probe_config()
	
	# Probe Mass & Hardware Breakdown
	var probe_dry_mass: float = (
		p_cfg.get("structure_mass_kg", 180.0) +
		p_cfg.get("propellant_dry_mass_kg", 55.0) +
		p_cfg.get("solar_mass_kg", 45.0) +
		p_cfg.get("battery_mass_kg", 28.0) +
		p_cfg.get("computer_mass_kg", 24.0) +
		p_cfg.get("adcs_mass_kg", 26.0) +
		p_cfg.get("thermal_mass_kg", 18.0) +
		p_cfg.get("comms_mass_kg", 22.0)
	)
	var inst_mass: float = 0.0
	var inst_power_load: float = 0.0
	var inst_cost: float = 0.0
	for inst_key in p_cfg.get("instruments", {}):
		var inst = p_cfg["instruments"][inst_key]
		inst_mass += inst.get("mass_kg", 0.0)
		inst_power_load += inst.get("power_w", 0.0)
		inst_cost += inst.get("cost_m", 0.0)
	
	probe_dry_mass += inst_mass
	# Electrical harness and plumbing (approx 4% of dry mass)
	var probe_harness: float = probe_dry_mass * 0.04
	probe_dry_mass += probe_harness
	
	var probe_propellant_mass: float = p_cfg.get("propellant_mass_kg", 320.0)
	var probe_wet_mass: float = probe_dry_mass + probe_propellant_mass
	
	# Stage 2 Mass Breakdown
	var stage2_dry_mass: float = v_cfg.get("stage2_dry_mass_kg", 750.0) + v_cfg.get("interstage_mass_kg", 320.0)
	var stage2_fuel_mass: float = v_cfg.get("stage2_fuel_mass_kg", 5400.0)
	var stage2_wet_mass: float = stage2_dry_mass + stage2_fuel_mass
	
	# Stage 1 Mass Breakdown
	var stage1_dry_mass: float = v_cfg.get("stage1_dry_mass_kg", 2800.0) + v_cfg.get("stage1_fin_mass_kg", 220.0)
	var stage1_fuel_mass: float = v_cfg.get("stage1_fuel_mass_kg", 24000.0)
	var stage1_wet_mass: float = stage1_dry_mass + stage1_fuel_mass
	
	var fairing_mass: float = v_cfg.get("fairing_mass_kg", 420.0)
	
	# Total Vehicle Wet Mass at Liftoff
	var liftoff_wet_mass: float = stage1_wet_mass + stage2_wet_mass + probe_wet_mass + fairing_mass
	
	# --- MULTISTAGE TSIOLKOVSKY ROCKET EQUATION ---
	# Δv = Isp * g0 * ln(m0 / mf)
	const G0: float = 9.80665
	
	# Stage 1 Delta-V (Burns Stage 1 fuel carrying fairing, Stage 2, and Probe)
	var s1_m0: float = liftoff_wet_mass
	var s1_mf: float = liftoff_wet_mass - stage1_fuel_mass
	var s1_isp: float = v_cfg.get("stage1_isp_s", 320.0)
	var delta_v_stage1: float = s1_isp * G0 * log(s1_m0 / s1_mf)
	
	# Stage 2 Delta-V (Burns Stage 2 fuel carrying probe; fairing is jettisoned in upper atmosphere)
	var s2_m0: float = stage2_wet_mass + probe_wet_mass # Fairing jettisoned
	var s2_mf: float = stage2_dry_mass + probe_wet_mass
	var s2_isp: float = v_cfg.get("stage2_isp_s", 450.0)
	var delta_v_stage2: float = s2_isp * G0 * log(s2_m0 / s2_mf)
	
	# Spacecraft Bus Delta-V (Probe burns its own propellant for MCC, L1 halo insertion, stationkeeping)
	var probe_isp: float = p_cfg.get("probe_isp_s", 315.0)
	var delta_v_probe: float = probe_isp * G0 * log(probe_wet_mass / probe_dry_mass)
	
	var total_launch_delta_v: float = delta_v_stage1 + delta_v_stage2
	var total_mission_delta_v: float = total_launch_delta_v + delta_v_probe
	
	# --- LIFTOFF THRUST-TO-WEIGHT RATIO (TWR) ---
	var s1_thrust_kn: float = v_cfg.get("stage1_thrust_kn", 480.0)
	var liftoff_twr: float = (s1_thrust_kn * 1000.0) / (liftoff_wet_mass * G0)
	
	# --- AERODYNAMIC STABILITY: CENTER OF MASS VS CENTER OF PRESSURE ---
	# Measured from rocket base (x = 0 at engine gimbal plane, x = 16.5m at nose apex)
	# Center of Mass: Heavy propellant sits in stage 1 tank
	var x_com_m: float = (
		(stage1_fuel_mass * 6.5) +
		(stage1_dry_mass * 3.5) +
		(stage2_fuel_mass * 10.5) +
		(stage2_dry_mass * 9.0) +
		(probe_wet_mass * 14.0) +
		(fairing_mass * 15.0)
	) / liftoff_wet_mass
	
	# Center of Pressure: Nose cone produces destabilizing forward lift;
	# Aft grid fins at tail (x ~ 0.8m) provide restorative aerodynamic stabilizing moment.
	var has_fins: bool = (v_cfg.get("stage1_fins", "") != "none")
	var nose_cop_area: float = 1.4
	var body_cop_area: float = 0.8
	var fin_cop_area: float = 7.0 if has_fins else 0.2
	
	var total_cop_area: float = nose_cop_area + body_cop_area + fin_cop_area
	var x_cop_m: float = ( (nose_cop_area * 14.8) + (body_cop_area * 8.0) + (fin_cop_area * 0.8) ) / total_cop_area
	
	# Static margin (calibers): (x_com - x_cop) / diameter
	# Positive static margin (> 1.2 calibers) means CoM is ahead of CoP, ensuring passive restoring torque.
	var static_margin_calibers: float = (x_com_m - x_cop_m) / v_cfg.get("fairing_diameter_m", 2.4)
	
	# --- ELECTRICAL POWER BALANCE AT SUN-EARTH L1 ---
	# Solar Constant at 1 AU ~ 1361 W/m²
	# Sun-Earth L1 is ~1.496e8 - 1.5e6 km = ~0.99 AU (approx 1.02x solar flux ~ 1388 W/m²)
	var solar_flux: float = 1388.0
	var solar_area: float = p_cfg.get("solar_array_area_m2", 6.5)
	var solar_eff: float = p_cfg.get("solar_efficiency", 0.31)
	# Nominal sun-tracking cosine efficiency ~ 0.96
	var power_generation_w: float = solar_area * solar_eff * solar_flux * 0.96
	
	var total_power_load_w: float = (
		p_cfg.get("avionics_power_w", 65.0) +
		p_cfg.get("adcs_power_w", 35.0) +
		p_cfg.get("thermal_power_w", 25.0) +
		p_cfg.get("comms_power_w", 45.0) +
		inst_power_load
	)
	var power_margin_w: float = power_generation_w - total_power_load_w
	
	# --- FINANCIAL BUDGET CHECK ---
	var total_probe_cost: float = (
		p_cfg.get("structure_cost_m", 14.0) +
		p_cfg.get("propulsion_cost_m", 12.0) +
		p_cfg.get("solar_cost_m", 10.0) +
		p_cfg.get("battery_cost_m", 6.0) +
		p_cfg.get("computer_cost_m", 12.0) +
		p_cfg.get("adcs_cost_m", 7.5) +
		p_cfg.get("thermal_cost_m", 4.5) +
		p_cfg.get("comms_cost_m", 9.0) +
		inst_cost
	)
	var total_project_cost_m: float = v_cfg.get("vehicle_cost_m", 48.0) + total_probe_cost + 16.0 # $16M Ops/Ground Network
	const BUDGET_CAP_M: float = 185.0
	
	# Astrogator Trajectory & Launch Window Selection
	var traj_mode: String = v_cfg.get("trajectory_mode", "direct_injection")
	var req_launch_dv: float = 8950.0 if traj_mode == "phased_wsb" else 9100.0
	var req_probe_dv: float = 460.0 if traj_mode == "phased_wsb" else 420.0
	var transfer_days: int = 135 if traj_mode == "phased_wsb" else 110
	var traj_mode_name: String = "Phased WSB" if traj_mode == "phased_wsb" else "Direct Injection"

	# --- ENGINEERING GATE CHECKS ---
	var gate_checks: Array = []
	
	# Check 1: Liftoff TWR
	var twr_valid: bool = (liftoff_twr >= 1.20 and liftoff_twr <= 1.85)
	gate_checks.append({
		"id": "twr_check",
		"name": "Liftoff Thrust-to-Weight Ratio",
		"value_str": "%.2f" % liftoff_twr,
		"target_str": "1.20 – 1.85",
		"status": "PASS" if twr_valid else ("WARN" if liftoff_twr > 1.10 else "FAIL"),
		"role": ROLE_PROPULSION,
		"advice": "Nominal liftoff thrust." if twr_valid else ("TWR too low (<1.20) for positive launch pad clearance." if liftoff_twr < 1.20 else "Excessive acceleration (>1.85 TWR) risks structural G-force overstress.")
	})
	
	# Check 2: Launch Vehicle Delta-V to L1 Transfer Orbit
	var launch_dv_valid: bool = (total_launch_delta_v >= req_launch_dv)
	gate_checks.append({
		"id": "launch_dv_check",
		"name": "Launch Vehicle Trans-L1 Delta-V (%s)" % traj_mode_name,
		"value_str": "%.0f m/s" % total_launch_delta_v,
		"target_str": ">= %.0f m/s" % req_launch_dv,
		"status": "PASS" if launch_dv_valid else "FAIL",
		"role": ROLE_PROPULSION,
		"advice": ("Upper stage insertion into %s transfer confirmed." % ("weak-stability boundary (WSB) trajectory" if traj_mode == "phased_wsb" else "direct Sunward trajectory")) if launch_dv_valid else "Insufficient booster/upper-stage Delta-V to reach Earth-L1 transfer orbit."
	})
	
	# Check 3: Probe Deep-Space Maneuver Delta-V (MCC + Halo Insertion + Stationkeeping)
	var probe_dv_valid: bool = (delta_v_probe >= req_probe_dv)
	gate_checks.append({
		"id": "probe_dv_check",
		"name": "Spacecraft Halo Insertion & Stationkeeping ΔV (%s)" % traj_mode_name,
		"value_str": "%.0f m/s" % delta_v_probe,
		"target_str": ">= %.0f m/s" % req_probe_dv,
		"status": "PASS" if probe_dv_valid else "FAIL",
		"role": ROLE_ASTROGATOR,
		"advice": "Propellant reserve meets insertion and illustrative stationkeeping threshold (educational game model)." if probe_dv_valid else "Probe lacks propellant for halo insertion and illustrative stationkeeping threshold at L1 under selected trajectory mode."
	})
	
	# Check 4: Aerodynamic Static Margin (CoM vs CoP)
	var stability_valid: bool = (static_margin_calibers >= 1.2)
	gate_checks.append({
		"id": "stability_check",
		"name": "Aerodynamic Static Margin (CoM / CoP)",
		"value_str": "%.2f calibers" % static_margin_calibers,
		"target_str": ">= +1.20 calibers",
		"status": "PASS" if stability_valid else "FAIL",
		"role": ROLE_STRUCTURAL,
		"advice": "Center of Mass ahead of Center of Pressure. Rocket has passive aerodynamic restoring torque." if stability_valid else "Aerodynamic instability: CoP is too close to CoM. Add stabilizing grid fins or trim nose fairing mass."
	})
	
	# Check 5: Electrical Power Balance
	var power_valid: bool = (power_margin_w >= 100.0)
	gate_checks.append({
		"id": "power_check",
		"name": "Sun-Earth L1 Power Surplus Margin",
		"value_str": "+%.0f W" % power_margin_w,
		"target_str": ">= +100 W surplus",
		"status": "PASS" if power_valid else "FAIL",
		"role": ROLE_SYSTEMS,
		"advice": "Positive electrical balance across avionics, instruments, and transmitters." if power_valid else "Power deficit or narrow margin (<100W). Enlarge solar wing area or optimize instrument duty cycles."
	})
	
	# Check 6: Budget Cap
	var budget_valid: bool = (total_project_cost_m <= BUDGET_CAP_M)
	gate_checks.append({
		"id": "budget_check",
		"name": "Campaign Budget Allocation",
		"value_str": "$%.1fM" % total_project_cost_m,
		"target_str": "<= $%.1fM" % BUDGET_CAP_M,
		"status": "PASS" if budget_valid else "FAIL",
		"role": ROLE_PROPULSION,
		"advice": "Project costs within authorized emergency congressional ceiling." if budget_valid else "Cost overrun ($%.1fM > $185.0M). Downgrade non-critical bus components to stay in budget." % total_project_cost_m
	})
	
	var all_passed: bool = (twr_valid and launch_dv_valid and probe_dv_valid and stability_valid and power_valid and budget_valid)
	
	return {
		"liftoff_wet_mass_kg": liftoff_wet_mass,
		"probe_dry_mass_kg": probe_dry_mass,
		"probe_propellant_mass_kg": probe_propellant_mass,
		"probe_wet_mass_kg": probe_wet_mass,
		"stage1_fuel_mass_kg": stage1_fuel_mass,
		"stage2_fuel_mass_kg": stage2_fuel_mass,
		"delta_v_stage1": delta_v_stage1,
		"delta_v_stage2": delta_v_stage2,
		"delta_v_probe": delta_v_probe,
		"total_launch_delta_v": total_launch_delta_v,
		"total_mission_delta_v": total_mission_delta_v,
		"liftoff_twr": liftoff_twr,
		"x_com_m": x_com_m,
		"x_cop_m": x_cop_m,
		"static_margin_calibers": static_margin_calibers,
		"power_generation_w": power_generation_w,
		"total_power_load_w": total_power_load_w,
		"power_margin_w": power_margin_w,
		"total_cost_m": total_project_cost_m,
		"budget_cap_m": BUDGET_CAP_M,
		"trajectory_mode": traj_mode,
		"transfer_days": transfer_days,
		"req_launch_dv": req_launch_dv,
		"req_probe_dv": req_probe_dv,
		"gate_checks": gate_checks,
		"all_gate_checks_passed": all_passed
	}

# --- AUTHORITATIVE DEBRIEF SCORING FUNCTION ---

static func calculate_debrief_score(l_tel: Dictionary, c_res: Dictionary, l1_tel: Dictionary) -> Dictionary:
	# 1. Launch & Staging Pillar (Max 25.0 pts)
	var stress: float = l_tel.get("structural_stress_pct", 0.0)
	var traj_err: float = l_tel.get("trajectory_error_pct", 0.0)
	var p1_score: float = snappedf(clamp(25.0 - (stress * 0.25) - (traj_err * 0.3), 5.0, 25.0), 0.1)
	
	# 2. Crisis Survival Pillar (Max 25.0 pts)
	var deg: float = c_res.get("equipment_degradation_pct", 5.0)
	var sci_bonus: float = c_res.get("science_bonus_pts", 10.0)
	var p2_score: float = snappedf(clamp(25.0 - (deg * 0.4) + (sci_bonus * 0.3), 5.0, 25.0), 0.1)
	
	# 3. L1 Halo-Orbit & Stationkeeping Pillar (Max 25.0 pts)
	var p3_score: float = 25.0
	var final_fuel: float = l1_tel.get("final_propellant_kg", 200.0)
	if final_fuel < 35.0:
		p3_score = 10.0
	elif final_fuel < 80.0:
		p3_score = 18.0
	else:
		p3_score = 25.0
	p3_score = snappedf(p3_score, 0.1)
	
	# 4. Early-Warning & Data Quality Pillar (Max 25.0 pts)
	var warning_sent: bool = l1_tel.get("warning_packet_sent", true)
	var p4_score: float = 25.0 if warning_sent else 0.0
	p4_score = snappedf(p4_score, 0.1)
	
	var is_succ: bool = (p4_score > 0.0)
	var total: float = snappedf(p1_score + p2_score + p3_score + p4_score, 0.1)
	
	var grade: String = "A+"
	if total >= 90.0:
		grade = "A+"
	elif total >= 80.0:
		grade = "A"
	elif total >= 70.0:
		grade = "B"
	elif total >= 60.0:
		grade = "C"
	else:
		grade = "F"
		is_succ = false
		
	return {
		"total_score": total,
		"letter_grade": grade,
		"is_success": is_succ,
		"launch_pillar": p1_score,
		"crisis_pillar": p2_score,
		"l1_pillar": p3_score,
		"warning_pillar": p4_score
	}

# --- PERSISTENCE: USER:// STORAGE ---

static func save_campaign_state() -> bool:
	var save_dict: Dictionary = {
		"version": "1.0.0",
		"campaign": "helios4_the_last_line_of_defense",
		"timestamp": Time.get_datetime_string_from_system(),
		"current_stage": int(current_stage),
		"highest_unlocked_stage": int(highest_unlocked_stage),
		"player_count": player_count,
		"team_player_names": team_player_names,
		"team_decision_log": team_decision_log,
		"vehicle_config": vehicle_config,
		"probe_config": probe_config,
		"launch_telemetry": launch_telemetry,
		"transfer_telemetry": transfer_telemetry,
		"crisis_results": crisis_results,
		"l1_telemetry": l1_telemetry,
		"final_debrief_data": final_debrief_data
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[Helios4CampaignData] Failed to open save file for writing: ", SAVE_PATH)
		return false
	file.store_string(JSON.stringify(save_dict, "\t"))
	file.close()
	print("[Helios4CampaignData] Successfully saved campaign to: ", SAVE_PATH)
	return true

static func load_campaign_state() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[Helios4CampaignData] No saved campaign file found at: ", SAVE_PATH)
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(text) != OK:
		printerr("[Helios4CampaignData] Failed to parse save JSON")
		return false
		
	var data = json.get_data()
	if not data is Dictionary:
		return false
		
	current_stage = data.get("current_stage", Stage.PROLOGUE) as Stage
	highest_unlocked_stage = data.get("highest_unlocked_stage", Stage.PROLOGUE) as Stage
	player_count = data.get("player_count", 1)
	if data.has("team_player_names"):
		team_player_names = data["team_player_names"]
	if data.has("team_decision_log"):
		team_decision_log = data["team_decision_log"]
	if data.has("vehicle_config"):
		vehicle_config = data["vehicle_config"]
	if data.has("probe_config"):
		probe_config = data["probe_config"]
	if data.has("launch_telemetry"):
		launch_telemetry = data["launch_telemetry"]
	if data.has("transfer_telemetry"):
		transfer_telemetry = data["transfer_telemetry"]
	if data.has("crisis_results"):
		crisis_results = data["crisis_results"]
	if data.has("l1_telemetry"):
		l1_telemetry = data["l1_telemetry"]
	if data.has("final_debrief_data"):
		final_debrief_data = data["final_debrief_data"]
		
	print("[Helios4CampaignData] Loaded campaign at stage: ", STAGE_METADATA[current_stage]["title"])
	return true

static func has_saved_campaign() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func reset_campaign() -> void:
	current_stage = Stage.PROLOGUE
	highest_unlocked_stage = Stage.PROLOGUE
	player_count = 1
	team_player_names = {
		ROLE_PROPULSION: "Specialist 1",
		ROLE_STRUCTURAL: "Specialist 2",
		ROLE_ASTROGATOR: "Specialist 3",
		ROLE_SYSTEMS: "Specialist 4"
	}
	team_decision_log = []
	active_role = ROLE_PROPULSION
	vehicle_config = get_default_vehicle_config()
	probe_config = get_default_probe_config()
	launch_telemetry = {}
	transfer_telemetry = {}
	crisis_results = {}
	l1_telemetry = {}
	final_debrief_data = {}
	save_campaign_state()

static func advance_to_stage(next_stage: Stage) -> void:
	current_stage = next_stage
	if int(next_stage) > int(highest_unlocked_stage):
		highest_unlocked_stage = next_stage
	save_campaign_state()

static func get_scene_path_for_stage(stage: Stage) -> String:
	match stage:
		Stage.PROLOGUE:
			return "res://margin/scenes/helios4_prologue.tscn"
		Stage.TEAM_ASSIGNMENT:
			return "res://margin/scenes/helios4_team_assignment.tscn"
		Stage.PHASE_1_HANGAR:
			return "res://margin/scenes/helios4_hangar.tscn"
		Stage.ENGINEERING_REVIEW:
			return "res://margin/scenes/helios4_engineering_review.tscn"
		Stage.PHASE_2_LAUNCH:
			return "res://margin/scenes/helios4_launch.tscn"
		Stage.PHASE_3_TRANSFER:
			return "res://margin/scenes/helios4_deep_space.tscn"
		Stage.PHASE_4_CRISIS:
			return "res://margin/scenes/helios4_crisis.tscn"
		Stage.PHASE_5_L1_INSERTION, Stage.PHASE_6_COMMISSIONING:
			return "res://margin/scenes/helios4_l1_arrival.tscn"
		Stage.MISSION_DEBRIEF, Stage.CAMPAIGN_COMPLETED:
			return "res://margin/scenes/helios4_debrief.tscn"
	return "res://margin/scenes/helios4_prologue.tscn"

static func load_stage(stage: Stage, tree: SceneTree) -> void:
	advance_to_stage(stage)
	var scene_path = get_scene_path_for_stage(stage)
	print("[Helios4CampaignData] Transitioning to stage: ", STAGE_METADATA[stage]["title"], " -> ", scene_path)
	tree.change_scene_to_file(scene_path)
