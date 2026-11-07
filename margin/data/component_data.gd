class_name ComponentDatabase
extends RefCounted

# ==============================================================================
# EDUCATIONAL GAME MODEL NOTICE:
# Component parameters and specifications in this database are deterministic educational
# game models designed for interactive aerospace engineering gameplay.
# While inspired by actual mission principles and NASA references (e.g. Lunar Prospector,
# LRO LEND, and Mini-RF), they are educational gameplay representations rather than
# certified flight hardware specifications.
# ==============================================================================

enum Category {
	STRUCTURE,
	POWER_GENERATION,
	BATTERY,
	PROPULSION,
	COMMUNICATIONS,
	COMPUTER,
	ADCS,
	THERMAL,
	INSTRUMENTS
}

static func get_category_name(cat: Category) -> String:
	match cat:
		Category.STRUCTURE: return "Structure"
		Category.POWER_GENERATION: return "Power Generation"
		Category.BATTERY: return "Battery"
		Category.PROPULSION: return "Propulsion"
		Category.COMMUNICATIONS: return "Communications"
		Category.COMPUTER: return "Onboard Computer"
		Category.ADCS: return "ADCS"
		Category.THERMAL: return "Thermal Control"
		Category.INSTRUMENTS: return "Scientific Instruments"
	return "Unknown"

static func get_category_id_string(cat: Category) -> String:
	match cat:
		Category.STRUCTURE: return "structure"
		Category.POWER_GENERATION: return "power_generation"
		Category.BATTERY: return "battery"
		Category.PROPULSION: return "propulsion"
		Category.COMMUNICATIONS: return "comms"
		Category.COMPUTER: return "computer"
		Category.ADCS: return "adcs"
		Category.THERMAL: return "thermal"
		Category.INSTRUMENTS: return "instruments"
	return "misc"

static func get_all_components() -> Dictionary:
	return {
		# 1. STRUCTURE
		"struct_aluminum": {
			"id": "struct_aluminum",
			"category": Category.STRUCTURE,
			"name": "Modular Aluminum 6061 Monocoque",
			"tier": "Standard Heritage",
			"mass_kg": 42.0,
			"cost_m": 12.5,
			"power_w": 0.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 98.0,
			"science_score": 0.0,
			"stowed_diameter_m": 1.05,
			"stowed_height_m": 1.15,
			"stowed_vol_m3": 0.95,
			"description": "Standard aerospace CNC-machined 6061-T6 aluminum bus chassis with high structural heritage (educational model).",
			"tradeoff_positive": "Economical cost and high structural heritage with zero manufacturing risk.",
			"tradeoff_negative": "Substantially heavier than modern composites, consuming mass budget.",
			"engineering_insight": "Aluminum offers high thermal conductivity and radiation shielding, but its density requires sacrifices in payload mass.",
			"visual_variant": "aluminum_frame"
		},
		"struct_carbon": {
			"id": "struct_carbon",
			"category": Category.STRUCTURE,
			"name": "Carbon-Fiber Honeycomb Core",
			"tier": "High Performance",
			"mass_kg": 26.5,
			"cost_m": 22.0,
			"power_w": 0.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 94.0,
			"science_score": 0.0,
			"stowed_diameter_m": 1.00,
			"stowed_height_m": 1.10,
			"stowed_vol_m3": 0.85,
			"description": "Carbon-fiber reinforced polymer (CFRP) face sheets bonded over lightweight aluminum honeycomb core (educational model).",
			"tradeoff_positive": "Saves 15.5 kg in dry mass, freeing mass budget for advanced sensors.",
			"tradeoff_negative": "+$9.5M budget premium and anisotropic thermal expansion requires custom thermal isolation.",
			"engineering_insight": "CFRP delivers extreme specific stiffness (E/ρ), enabling rigid optical and antenna mounts with minimal deflection.",
			"visual_variant": "carbon_fiber"
		},
		"struct_titanium": {
			"id": "struct_titanium",
			"category": Category.STRUCTURE,
			"name": "3D-Printed Titanium Isogrid",
			"tier": "Advanced Additive",
			"mass_kg": 19.5,
			"cost_m": 33.5,
			"power_w": 0.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 90.0,
			"science_score": 0.0,
			"stowed_diameter_m": 0.95,
			"stowed_height_m": 1.05,
			"stowed_vol_m3": 0.75,
			"description": "Direct metal laser sintered Ti-6Al-4V triangular isogrid structure with integrated propellant brackets (educational model).",
			"tradeoff_positive": "Ultra-lightweight (saves 22.5 kg) with maximum internal usable envelope.",
			"tradeoff_negative": "Highest cost ($33.5M) and requires extensive radiographic non-destructive testing.",
			"engineering_insight": "Additive manufacturing allows organic stress-optimized topology, eliminating bolted joints and leak paths.",
			"visual_variant": "titanium_isogrid"
		},

		# 2. POWER GENERATION
		"power_body_silicon": {
			"id": "power_body_silicon",
			"category": Category.POWER_GENERATION,
			"name": "Body-Mounted Silicon Array",
			"tier": "Passive / Low Complexity",
			"mass_kg": 14.0,
			"cost_m": 8.0,
			"power_w": 180.0, # Generation (+)
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 99.0,
			"science_score": 0.0,
			"stowed_diameter_delta_m": 0.04,
			"stowed_height_delta_m": 0.0,
			"stowed_vol_m3": 0.05,
			"description": "Rigid silicon solar cells bonded directly to the satellite perimeter panels (educational model).",
			"tradeoff_positive": "Zero deployment mechanisms or drive motors; impervious to deployment failure.",
			"tradeoff_negative": "Low power output (180 W) and angle-dependent; struggles with high-draw instruments.",
			"engineering_insight": "Body mounting avoids gimbal mass and pointing disturbances, but only ~30% of cell area faces the Sun at any instant.",
			"visual_variant": "body_panels"
		},
		"power_articulated_gaas": {
			"id": "power_articulated_gaas",
			"category": Category.POWER_GENERATION,
			"name": "Articulated Dual-Wing GaAs Array",
			"tier": "High Efficiency",
			"mass_kg": 24.5,
			"cost_m": 19.5,
			"power_w": 420.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 93.0,
			"science_score": 0.0,
			"stowed_diameter_delta_m": 0.18,
			"stowed_height_delta_m": 0.05,
			"stowed_vol_m3": 0.22,
			"description": "Two deployable Gallium Arsenide triple-junction wings with single-axis Solar Array Drive Mechanisms (educational model).",
			"tradeoff_positive": "Generates 420 W with ~30% cell conversion efficiency and active Sun-tracking.",
			"tradeoff_negative": "Adds 10.5 kg in hinges and motors; solar array drive adds slight pointing jitter.",
			"engineering_insight": "Triple-junction cells stack InGaP/InGaAs/Ge layers to harvest distinct wavelengths of the solar spectrum.",
			"visual_variant": "deployable_wings"
		},
		"power_roflex_array": {
			"id": "power_roflex_array",
			"category": Category.POWER_GENERATION,
			"name": "Roll-Out Flexible Array (ROSA)",
			"tier": "Next-Gen Specific Power",
			"mass_kg": 18.0,
			"cost_m": 28.5,
			"power_w": 560.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 91.0,
			"science_score": 0.0,
			"stowed_diameter_delta_m": 0.12,
			"stowed_height_delta_m": 0.10,
			"stowed_vol_m3": 0.16,
			"description": "Lightweight composite boom roll-out flexible photovoltaic blanket (educational model).",
			"tradeoff_positive": "Highest power yield (560 W) at just 18.0 kg (31 W/kg specific power).",
			"tradeoff_negative": "High cost ($28.5M) and flexible dynamics require structural damping filter in ADCS.",
			"engineering_insight": "Stored strain energy in composite slit tubes allows motorless unrolling deployment.",
			"visual_variant": "rollout_wings"
		},

		# 3. BATTERY
		"batt_li_ion_standard": {
			"id": "batt_li_ion_standard",
			"category": Category.BATTERY,
			"name": "Standard Li-Ion Battery (450 Wh)",
			"tier": "Heritage",
			"mass_kg": 16.0,
			"cost_m": 6.5,
			"power_w": -6.0, # BMS base draw
			"storage_wh": 450.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 96.0,
			"science_score": 0.0,
			"stowed_vol_m3": 0.08,
			"description": "Flight-proven Lithium Cobalt Oxide battery pack with redundant cell-bypass diodes (educational model).",
			"tradeoff_positive": "Low procurement cost, robust charge retention, extensive flight test data.",
			"tradeoff_negative": "Marginal energy buffer during ~48-min orbital eclipses; limits night-side operations.",
			"engineering_insight": "Depth of Discharge (DoD) must stay below 70% during orbital eclipses to avoid accelerated capacity loss.",
			"visual_variant": "batt_compact"
		},
		"batt_high_density_lipoly": {
			"id": "batt_high_density_lipoly",
			"category": Category.BATTERY,
			"name": "High-Density Li-Polymer (800 Wh)",
			"tier": "Extended Reserve",
			"mass_kg": 21.0,
			"cost_m": 14.0,
			"power_w": -9.0,
			"storage_wh": 800.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 93.0,
			"science_score": 0.0,
			"stowed_vol_m3": 0.12,
			"description": "Multi-cell lithium polymer pack with active cell balancing and integrated autonomous heaters (educational model).",
			"tradeoff_positive": "800 Wh capacity provides comfortable reserve for full survival heating and night-side data processing.",
			"tradeoff_negative": "+5.0 kg mass penalty and requires strict thermal regulation within +10°C to +30°C.",
			"engineering_insight": "Pouch packaging maximizes volumetric density inside the spacecraft equipment bay.",
			"visual_variant": "batt_dual"
		},
		"batt_solid_state": {
			"id": "batt_solid_state",
			"category": Category.BATTERY,
			"name": "Space-Grade Solid-State (1200 Wh)",
			"tier": "Cutting-Edge Energy Density",
			"mass_kg": 18.5,
			"cost_m": 24.5,
			"power_w": -11.0,
			"storage_wh": 1200.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 89.0,
			"science_score": 0.0,
			"stowed_vol_m3": 0.10,
			"description": "Ceramic electrolyte solid-state cells eliminating flammable organic liquid solvents (educational model).",
			"tradeoff_positive": "Enormous 1200 Wh storage at lower mass than Li-Poly; survives wide temperature excursions.",
			"tradeoff_negative": "Expensive ($24.5M) and novel chemistry with limited spaceflight heritage.",
			"engineering_insight": "Solid electrolyte resists lithium dendrite growth, enabling deeper discharge cycling without degradation.",
			"visual_variant": "batt_solid"
		},

		# 4. PROPULSION
		"prop_cold_gas": {
			"id": "prop_cold_gas",
			"category": Category.PROPULSION,
			"name": "Gaseous Nitrogen Cold Gas Thrusters",
			"tier": "Ultra-Clean / Underpowered",
			"dry_mass_kg": 12.0,
			"propellant_mass_kg": 10.0,
			"mass_kg": 22.0, # 12kg dry + 10kg GN2
			"cost_m": 7.0,
			"power_w": -12.0,
			"isp_s": 68.0,
			"delta_v_ms": 95.0,
			"is_low_thrust": false,
			"thrust_n": 5.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 98.0,
			"science_score": 0.0,
			"stowed_height_delta_m": 0.12,
			"stowed_vol_m3": 0.10,
			"description": "Pressurized GN2 thruster pod with 4 pulsed attitude nozzles (educational model). Completely non-toxic and clean, but produces only ~95 m/s ΔV.",
			"tradeoff_positive": "Completely non-toxic; clean plume guarantees zero sensor or optics contamination.",
			"tradeoff_negative": "Underpowered for lunar capture: 95 m/s ΔV cannot perform Lunar Orbit Insertion (which requires 669.5 m/s in cited low-energy case, ~0.94 km/s in direct case).",
			"engineering_insight": "Cold gas relies strictly on enthalpy of gas expansion; reliable and simple but low thermodynamic energy.",
			"visual_variant": "prop_coldgas"
		},
		"prop_hydrazine_mono": {
			"id": "prop_hydrazine_mono",
			"category": Category.PROPULSION,
			"name": "Dual-Mode Hydrazine / Chemical Propulsion",
			"tier": "Flight-Proven Standard (Nominal)",
			"dry_mass_kg": 24.0,
			"propellant_mass_kg": 66.0,
			"mass_kg": 90.0, # 24kg dry + 66kg propellant
			"cost_m": 18.5,
			"power_w": -20.0,
			"isp_s": 295.0,
			"delta_v_ms": 1020.0,
			"is_low_thrust": false,
			"thrust_n": 220.0, # High thrust for impulsive retro-burn
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 94.0,
			"science_score": 0.0,
			"stowed_height_delta_m": 0.28,
			"stowed_vol_m3": 0.22,
			"description": "Dual-mode chemical propulsion system with high-expansion LOI retro-engine and attitude thrusters (educational model). Carries 66 kg of propellant and delivers high thrust (~220 N) for short impulsive perilune capture burns, mid-course corrections, and annual stationkeeping.",
			"tradeoff_positive": "High thrust-to-weight enables short impulsive LOI burns. Readily fulfills Low-Energy transfer (839.5 m/s req) with positive flight reserve (+106 m/s), or Direct transfer to Quasi-Frozen Elliptical orbit.",
			"tradeoff_negative": "Requires 90.0 kg wet mass and toxic propellant involves specialized launch pad loading operations.",
			"engineering_insight": "Chemical propulsion provides high thrust-to-weight ratio (~220 N), enabling short, impulsive LOI retro-burns at lunar perilune to minimize gravity losses.",
			"visual_variant": "prop_hydrazine"
		},
		"prop_hall_ion": {
			"id": "prop_hall_ion",
			"category": Category.PROPULSION,
			"name": "Miniature Hall-Effect Electric Thruster",
			"tier": "High Specific Impulse (Overpowered)",
			"dry_mass_kg": 22.0,
			"propellant_mass_kg": 18.0,
			"mass_kg": 40.0, # 22kg dry + 18kg Xenon
			"cost_m": 27.5,
			"power_w": -165.0,
			"isp_s": 1650.0,
			"delta_v_ms": 1680.0,
			"is_low_thrust": true, # Millinewton class - cannot do impulsive capture
			"thrust_mn": 25.0, # 25 mN
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 91.0,
			"science_score": 0.0,
			"stowed_height_delta_m": 0.20,
			"stowed_vol_m3": 0.16,
			"description": "Xenon electrostatic ion acceleration thruster with magnetic plasma confinement (educational model). Extremely high specific impulse (1650 s), but produces millinewton-class low thrust (~25 mN) and consumes 165 W of continuous electrical power. Note: Requires a continuous low-thrust spiral trajectory model (typically 6-12 months), which is not yet implemented in this mission. Both modeled Direct and Ballistic Lunar Transfers (BLT) require chemical propulsion for impulsive capture burns.",
			"tradeoff_positive": "Exceptional propellant efficiency (1650 s Isp) provides massive theoretical ΔV margin (>1600 m/s) with only 18 kg of Xenon.",
			"tradeoff_negative": "Millinewton thrust (~25 mN) cannot execute impulsive LOI capture burns. A separate low-thrust spiral trajectory model is not yet implemented. Also draws 165 W electrical power.",
			"engineering_insight": "A Ballistic Lunar Transfer (BLT) is NOT an electric propulsion spiral. While BLT uses Weak Stability Boundary gravity to arrive at perilune with lower velocity, it still requires a short impulsive retro-burn (669.5 m/s) to capture into orbit. Low-thrust ion engines require continuous spiral-out/spiral-in trajectories spanning many months.",
			"visual_variant": "prop_ion"
		},

		# 5. COMMUNICATIONS
		"comm_s_band_patch": {
			"id": "comm_s_band_patch",
			"category": Category.COMMUNICATIONS,
			"name": "S-Band Medium-Gain Patch Antenna",
			"tier": "Broad Beam / Low Overhead",
			"mass_kg": 6.5,
			"cost_m": 5.5,
			"power_w": -25.0,
			"data_rate_gbit_day": 2.2,
			"link_margin_db": 3.8,
			"reliability_pct": 98.0,
			"science_score": 0.0,
			"stowed_height_delta_m": 0.04,
			"stowed_vol_m3": 0.02,
			"description": "Microstrip patch antenna array with compact S-band solid-state power amplifier (educational model).",
			"tradeoff_positive": "Low mass and wide beamwidth means telemetry links close even during tumbling or off-pointing.",
			"tradeoff_negative": "Restricted downlink rate (2.2 Gbit/day); limits high-resolution instrument data return.",
			"engineering_insight": "Wider beamwidth reduces pointing constraints at the expense of lower antenna gain and data rate.",
			"visual_variant": "comm_patch"
		},
		"comm_x_band_dish": {
			"id": "comm_x_band_dish",
			"category": Category.COMMUNICATIONS,
			"name": "X-Band 0.75m Steerable Reflector",
			"tier": "High Throughput Heritage",
			"mass_kg": 15.0,
			"cost_m": 15.0,
			"power_w": -65.0,
			"data_rate_gbit_day": 14.5,
			"link_margin_db": 8.2,
			"reliability_pct": 93.0,
			"science_score": 0.0,
			"stowed_height_delta_m": 0.32,
			"stowed_diameter_delta_m": 0.15,
			"stowed_vol_m3": 0.18,
			"description": "Parabolic composite dish reflector with dual-axis azimuth/elevation pointing gimbal (educational model).",
			"tradeoff_positive": "Transfers 14.5 Gbit/day with robust +8.2 dB link margin to Deep Space Network 34m ground stations.",
			"tradeoff_negative": "Requires precise ±0.2° pointing towards Earth and adds gimbal mass and power draw.",
			"engineering_insight": "Parabolic dish focuses RF energy into a tight directional pencil beam, boosting effective radiated power (EIRP).",
			"visual_variant": "comm_dish"
		},
		"comm_ka_optical_hybrid": {
			"id": "comm_ka_optical_hybrid",
			"category": Category.COMMUNICATIONS,
			"name": "Ka-Band & Optical Laser Transceiver",
			"tier": "Ultra-Broadband Next-Gen",
			"mass_kg": 23.5,
			"cost_m": 26.5,
			"power_w": -105.0,
			"data_rate_gbit_day": 48.0,
			"link_margin_db": 11.4,
			"reliability_pct": 88.0,
			"science_score": 0.0,
			"stowed_height_delta_m": 0.40,
			"stowed_diameter_delta_m": 0.20,
			"stowed_vol_m3": 0.26,
			"description": "High-frequency Ka-band feed combined with infrared optical laser communications terminal (educational model).",
			"tradeoff_positive": "Unprecedented 48.0 Gbit/day downlink; enables continuous streaming of raw uncompressed sensor spectra.",
			"tradeoff_negative": "High cost ($26.5M), 105 W power draw, and requires sub-milliradian precision pointing.",
			"engineering_insight": "Optical frequencies (THz) pack orders of magnitude more information into micro-radian beams.",
			"visual_variant": "comm_optical"
		},

		# 6. ONBOARD COMPUTER (C&DH)
		"comp_rad750": {
			"id": "comp_rad750",
			"category": Category.COMPUTER,
			"name": "Rad-Hardened BAE RAD750 Computer",
			"tier": "Extreme Reliability",
			"mass_kg": 7.5,
			"cost_m": 11.5,
			"power_w": -22.0,
			"data_rate_gbit_day": 0.0,
			"storage_gb": 64.0,
			"reliability_pct": 99.2,
			"science_score": 0.0,
			"stowed_vol_m3": 0.04,
			"description": "Radiation-hardened PowerPC CPU with triple modular redundancy and EDAC memory protection (educational model).",
			"tradeoff_positive": "Extensive flight heritage; immune to solar proton events and single-event latchups (SEL).",
			"tradeoff_negative": "Modest clock speed (133 MHz) and 64 GB storage limit onboard data compression algorithms.",
			"engineering_insight": "Silicon-on-insulator (SOI) manufacturing prevents latch-up by insulating active transistors from cosmic rays.",
			"visual_variant": "comp_radhard"
		},
		"comp_space_vpx": {
			"id": "comp_space_vpx",
			"category": Category.COMPUTER,
			"name": "Quad-Core Fault-Tolerant SpaceVPX",
			"tier": "Balanced High Performance",
			"mass_kg": 5.8,
			"cost_m": 18.0,
			"power_w": -42.0,
			"data_rate_gbit_day": 0.0,
			"storage_gb": 256.0,
			"reliability_pct": 95.0,
			"science_score": 0.0,
			"stowed_vol_m3": 0.04,
			"description": "Quad-core ARM Cortex-R52 system with real-time compression FPGA and 256 GB flash recorder (educational model).",
			"tradeoff_positive": "Real-time CCSDS lossless data compression shrinks raw sensor data volume by 30%.",
			"tradeoff_negative": "Consumes 42 W and requires dedicated thermal conduction strap to radiator.",
			"engineering_insight": "Hardware-accelerated FPGA data compression effectively increases downlink capacity by 40% without larger antennas.",
			"visual_variant": "comp_vpx"
		},
		"comp_edge_ai": {
			"id": "comp_edge_ai",
			"category": Category.COMPUTER,
			"name": "Space-Qualified Neuromorphic Edge AI",
			"tier": "Autonomous Science",
			"mass_kg": 4.6,
			"cost_m": 24.0,
			"power_w": -62.0,
			"data_rate_gbit_day": 0.0,
			"storage_gb": 512.0,
			"reliability_pct": 90.0,
			"science_score": 5.0,
			"stowed_vol_m3": 0.04,
			"description": "Low-power tensor accelerator processing raw neutron counts to detect localized volatile hotspots (educational model).",
			"tradeoff_positive": "Autonomous target prioritization and anomaly classification directly adds science value (+5 pts).",
			"tradeoff_negative": "Higher power draw (62 W) and greater sensitivity to cumulative ionizing radiation dose (TID).",
			"engineering_insight": "Edge AI detects rare transient events and triggers high-speed burst recording.",
			"visual_variant": "comp_edgeai"
		},

		# 7. ADCS
		"adcs_3axis_wheels": {
			"id": "adcs_3axis_wheels",
			"category": Category.ADCS,
			"name": "3-Axis Reaction Wheels & Sun Sensors",
			"tier": "Basic Attitude Control",
			"mass_kg": 11.5,
			"cost_m": 8.5,
			"power_w": -28.0,
			"pointing_accuracy_deg": 0.15,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 94.0,
			"science_score": 0.0,
			"stowed_vol_m3": 0.06,
			"description": "Three orthogonal reaction wheels with coarse digital sun sensors and gyros (educational model).",
			"tradeoff_positive": "Economical cost and compact volume; sufficient for broad-beam instruments.",
			"tradeoff_negative": "0.15° pointing jitter is marginal for narrow-beam radar; lacks wheel redundancy.",
			"engineering_insight": "Reaction wheels exchange angular momentum between motor flywheels and the spacecraft body via Newton's 3rd Law.",
			"visual_variant": "adcs_3wheels"
		},
		"adcs_pyramid_star": {
			"id": "adcs_pyramid_star",
			"category": Category.ADCS,
			"name": "Pyramid 4-Wheel Array & Dual Star Trackers",
			"tier": "Precision Aerospace Standard",
			"mass_kg": 17.0,
			"cost_m": 17.5,
			"power_w": -52.0,
			"pointing_accuracy_deg": 0.012,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 96.5,
			"science_score": 0.0,
			"stowed_vol_m3": 0.09,
			"description": "Four reaction wheels in a skewed tetrahedral pyramid configuration with autonomous star cameras (educational model).",
			"tradeoff_positive": "Survives complete failure of any single reaction wheel; arcsecond pointing accuracy (0.012°).",
			"tradeoff_negative": "+5.5 kg mass penalty and requires unobstructed star tracker field of view.",
			"engineering_insight": "Star trackers match star patterns against onboard celestial star catalogs (Hipparcos) to determine inertial orientation.",
			"visual_variant": "adcs_pyramid"
		},
		"adcs_cmg_cluster": {
			"id": "adcs_cmg_cluster",
			"category": Category.ADCS,
			"name": "Miniature Control Moment Gyro Cluster (CMG)",
			"tier": "Agile High Torque",
			"mass_kg": 27.0,
			"cost_m": 26.5,
			"power_w": -88.0,
			"pointing_accuracy_deg": 0.005,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 89.0,
			"science_score": 3.0,
			"stowed_vol_m3": 0.14,
			"description": "Gimballed constant-speed spinning rotors producing massive gyroscopic torque for rapid slewing (educational model).",
			"tradeoff_positive": "Ultra-fast retargeting between Sun and science observations; optimal for polar sweep scans.",
			"tradeoff_negative": "Heavy (27 kg), draws 88 W, and gimbal singularities require complex steering control laws.",
			"engineering_insight": "CMGs produce torque by tilting the angular momentum vector of a spinning flywheel.",
			"visual_variant": "adcs_cmg"
		},

		# 8. THERMAL CONTROL
		"thermal_passive_mli": {
			"id": "thermal_passive_mli",
			"category": Category.THERMAL,
			"name": "Passive Multi-Layer Insulation (MLI)",
			"tier": "Passive / Low Overhead",
			"mass_kg": 7.5,
			"cost_m": 4.5,
			"power_w": -14.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 98.5,
			"science_score": 0.0,
			"stowed_vol_m3": 0.03,
			"description": "20-layer aluminized Mylar/Kapton blankets with thermostatically-controlled survival strip heaters (educational model).",
			"tradeoff_positive": "Extremely light (7.5 kg), highly reliable with zero moving components.",
			"tradeoff_negative": "Cannot actively dump excess heat during high-power sunlight operations; risk of instrument overheating.",
			"engineering_insight": "MLI blankets reflect infrared radiant heat back and forth between vacuum-separated reflective layers.",
			"visual_variant": "thermal_gold_foil"
		},
		"thermal_heatpipes_radiator": {
			"id": "thermal_heatpipes_radiator",
			"category": Category.THERMAL,
			"name": "Variable Conductance Heat Pipes & Radiator",
			"tier": "Balanced Space Standard",
			"mass_kg": 15.5,
			"cost_m": 12.0,
			"power_w": -26.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 94.0,
			"science_score": 0.0,
			"stowed_vol_m3": 0.08,
			"description": "Closed-loop ammonia heat pipes coupled to quartz mirror ceramic optical solar reflectors (educational model).",
			"tradeoff_positive": "Maintains benign ±5°C bus temperature across extreme lunar thermal swings (-180°C to +120°C).",
			"tradeoff_negative": "+8.0 kg mass and requires dedicated anti-freeze heaters during prolonged shadow transits.",
			"engineering_insight": "Ammonia evaporates at heat sources and condenses at cold radiators, pumping kWs of heat via capillary action.",
			"visual_variant": "thermal_radiator_panels"
		},
		"thermal_active_cryo": {
			"id": "thermal_active_cryo",
			"category": Category.THERMAL,
			"name": "Mechanical Louvers & Stirling Cryo-Cooler",
			"tier": "Advanced Active Refrigeration",
			"mass_kg": 23.5,
			"cost_m": 21.0,
			"power_w": -52.0,
			"data_rate_gbit_day": 0.0,
			"reliability_pct": 89.0,
			"science_score": 4.0,
			"stowed_vol_m3": 0.12,
			"description": "Bimetallic louver blades and miniature Stirling cryocooler providing 77 K sub-cooling for detectors (educational model).",
			"tradeoff_positive": "Cools specialized detectors down to cryogenic temperatures, maximizing signal-to-noise ratio.",
			"tradeoff_negative": "Significant mass (23.5 kg), 52 W continuous power consumption, and mechanical compressor vibration.",
			"engineering_insight": "Sub-100 K cryogenic cooling freezes thermal noise in semiconductor detectors, multiplying spectral resolution.",
			"visual_variant": "thermal_cryo_louvers"
		},

		# 9. SCIENTIFIC INSTRUMENTS (THE MISSION PAYLOADS)
		"inst_neutron_spectrometer": {
			"id": "inst_neutron_spectrometer",
			"category": Category.INSTRUMENTS,
			"name": "Helium-3 Proportional Counter Neutron Spectrometer",
			"tier": "NASA Science Heritage",
			"mass_kg": 14.5,
			"cost_m": 16.5,
			"power_w": -16.0,
			"data_rate_gbit_day": 1.6,
			"reliability_pct": 96.0,
			"science_score": 76.0,
			"stowed_height_delta_m": 0.25,
			"stowed_vol_m3": 0.15,
			"heritage_name": "NASA Lunar Prospector (1998) LP-NS",
			"heritage_url": "https://science.nasa.gov/mission/lunar-prospector/",
			"description": "Educational model based on NASA's 1998 Lunar Prospector Helium-3 proportional counter instrument (LP-NS). Measures thermal and epithermal neutron flux to detect hydrogen moderation in the top meter of lunar regolith.",
			"tradeoff_positive": "Authentic detection physics: cosmic-ray neutrons moderated by hydrogen nuclei. Low power (16 W) and low data volume.",
			"tradeoff_negative": "Coarse spatial resolution (~50 km footprint from 100 km orbit); cannot pinpoint individual crater deposits.",
			"engineering_insight": "When cosmic rays hit the regolith, neutrons bounce off nuclei. Hydrogen has near-identical mass to neutrons, absorbing their energy with highest efficiency.",
			"visual_variant": "inst_lp_neutron"
		},
		"inst_gamma_neutron_lend": {
			"id": "inst_gamma_neutron_lend",
			"category": Category.INSTRUMENTS,
			"name": "Collimated Neutron Detector Array (LRO LEND Heritage)",
			"tier": "High Resolution Spectrometry",
			"mass_kg": 28.5,
			"cost_m": 31.0,
			"power_w": -46.0,
			"data_rate_gbit_day": 5.8,
			"reliability_pct": 92.5,
			"science_score": 90.0,
			"stowed_height_delta_m": 0.35,
			"stowed_vol_m3": 0.25,
			"heritage_name": "LRO Lunar Exploration Neutron Detector (LEND)",
			"heritage_url": "https://lunar.gsfc.nasa.gov/lend.html",
			"description": "Educational model based on the LRO LEND instrument. Uses 4 collimated Helium-3 detectors with cadmium/polyethylene shielding plus uncollimated sensors and stilbene scintillator to map polar hydrogen with 10 km spatial resolution.",
			"tradeoff_positive": "Sharp 10 km spatial resolution resolving individual Permanently Shadowed Regions (PSRs); higher confidence localization.",
			"tradeoff_negative": "Heavier (28.5 kg), draws 46 W, and massive collimator shielding increases dry mass.",
			"engineering_insight": "Passive collimation absorbs off-axis epithermal neutrons, narrowing the field of view down to specific craters like Shackleton.",
			"visual_variant": "inst_lend_gamma"
		},
		"inst_radar_sar_infrared": {
			"id": "inst_radar_sar_infrared",
			"category": Category.INSTRUMENTS,
			"name": "Polarimetric Synthetic Aperture Radar (Mini-RF Heritage)",
			"tier": "Flagship Discovery Radar",
			"mass_kg": 42.0,
			"cost_m": 46.5,
			"power_w": -118.0,
			"data_rate_gbit_day": 16.5,
			"reliability_pct": 88.0,
			"science_score": 98.0,
			"stowed_height_delta_m": 0.45,
			"stowed_diameter_delta_m": 0.18,
			"stowed_vol_m3": 0.38,
			"heritage_name": "LRO Miniature Radio Frequency (Mini-RF) Radar",
			"heritage_url": "https://www.nasa.gov/mission/mini-rf/",
			"description": "Educational model based on LRO's Mini-RF radar instrument (synthetic aperture radar, not an infrared sensor). Transmits circular polarization and receives orthogonal linear polarizations to compute Circular Polarization Ratio (CPR) down to 15m resolution.",
			"tradeoff_positive": "Probes dielectric properties and coherent backscatter of buried ice deposits, distinguishing ice from rough rock.",
			"tradeoff_negative": "Massive mass (42 kg), high power draw (118 W), and huge 16.5 Gbit/day data stream; pushes all spacecraft margins to the limit.",
			"engineering_insight": "Water ice exhibits coherent backscatter resulting in CPR > 1 inside shadowed craters, helping distinguish pure water ice from solar wind hydrogen.",
			"visual_variant": "inst_sar_radar"
		},
		"inst_multispectral_radiometer": {
			"id": "inst_multispectral_radiometer",
			"category": Category.INSTRUMENTS,
			"name": "Multi-Spectral Climate Radiometer (Sentinel-3 OLCI Heritage)",
			"tier": "Earth Observation Optical Suite",
			"mass_kg": 32.0,
			"cost_m": 24.0,
			"power_w": -52.0,
			"data_rate_gbit_day": 12.0,
			"reliability_pct": 95.0,
			"science_score": 82.0,
			"stowed_height_delta_m": 0.30,
			"stowed_vol_m3": 0.20,
			"heritage_name": "ESA Sentinel-3 Ocean & Land Colour Instrument (OLCI)",
			"heritage_url": "https://sentinels.copernicus.eu/web/sentinel/missions/sentinel-3",
			"description": "21-band pushbroom imaging spectrometer measuring ocean color, land vegetation indices (NDVI), and polar ice surface reflectance for Earth climate observation.",
			"tradeoff_positive": "Provides high radiometric fidelity and continuous global coverage across 21 spectral bands.",
			"tradeoff_negative": "Generates 12.0 Gbit/day of continuous optical data requiring dedicated high-latitude ground downlink passes.",
			"engineering_insight": "Narrow spectral band pass filters in the visible and NIR allow atmospheric Rayleigh scattering correction and precise chlorophyll quantification.",
			"visual_variant": "inst_radiometer"
		},
		"inst_ghg_spectrometer": {
			"id": "inst_ghg_spectrometer",
			"category": Category.INSTRUMENTS,
			"name": "Atmospheric Greenhouse Gas Spectrometer (OCO-2 Heritage)",
			"tier": "Atmospheric Sounding Suite",
			"mass_kg": 44.0,
			"cost_m": 34.5,
			"power_w": -78.0,
			"data_rate_gbit_day": 18.5,
			"reliability_pct": 91.5,
			"science_score": 94.0,
			"stowed_height_delta_m": 0.40,
			"stowed_vol_m3": 0.30,
			"heritage_name": "NASA Orbiting Carbon Observatory-2 (OCO-2)",
			"heritage_url": "https://ocov2.jpl.nasa.gov/",
			"description": "High-resolution diffraction grating spectrometer measuring column-averaged CO2 and CH4 dry-air mole fractions through molecular absorption bands.",
			"tradeoff_positive": "Delivers premier climate science return (94 pts) tracking regional carbon sources, sinks, and permafrost methane release.",
			"tradeoff_negative": "Demands 78 W continuous power and 44 kg payload mass, requiring high-capacity solar arrays and battery reserves.",
			"engineering_insight": "Resolving individual CO2 absorption lines in the 1.61 µm and 2.06 µm bands requires cryogenic cooling (-150°C) of the focal plane arrays.",
			"visual_variant": "inst_ghg_spectrometer"
		},
		"inst_polarimetric_ice_sar": {
			"id": "inst_polarimetric_ice_sar",
			"category": Category.INSTRUMENTS,
			"name": "Interferometric Radar Altimeter & Ice SAR (CryoSat-2 Heritage)",
			"tier": "Active Microwave Cryosphere Sensor",
			"mass_kg": 58.0,
			"cost_m": 42.0,
			"power_w": -135.0,
			"data_rate_gbit_day": 24.0,
			"reliability_pct": 89.0,
			"science_score": 98.0,
			"stowed_height_delta_m": 0.50,
			"stowed_diameter_delta_m": 0.22,
			"stowed_vol_m3": 0.42,
			"heritage_name": "ESA CryoSat-2 SAR Interferometric Radar Altimeter (SIRAL)",
			"heritage_url": "https://earth.esa.int/eogateway/missions/cryosat",
			"description": "Ku-band SAR interferometric radar altimeter tracking ice sheet elevation change, glacier terminus velocity, and polar sea ice freeboard thickness through cloud cover.",
			"tradeoff_positive": "Unmatched cryospheric survey precision independent of solar illumination or polar cloud weather (98 science pts).",
			"tradeoff_negative": "Heaviest sensor suite (58 kg), massive 135 W transmitter load, and enormous 24 Gbit/day data stream.",
			"engineering_insight": "Synthetic Aperture Radar (SAR) mode sharpens along-track footprint to 250m, enabling steep coastal ice margin profiling.",
			"visual_variant": "inst_ice_sar"
		}
	}

static func get_components_for_category(cat: Category) -> Array:
	var list: Array = []
	var all_comps = get_all_components()
	for id in all_comps:
		var comp = all_comps[id]
		if comp["category"] == cat:
			list.append(comp)
	# Sort by cost ascending
	list.sort_custom(func(a, b): return a["cost_m"] < b["cost_m"])
	return list

static func get_component(id: String) -> Dictionary:
	var all_comps = get_all_components()
	if all_comps.has(id):
		return all_comps[id]
	return {}

static func get_default_configuration() -> Dictionary:
	return {
		Category.STRUCTURE: "struct_aluminum",
		Category.POWER_GENERATION: "power_articulated_gaas",
		Category.BATTERY: "batt_li_ion_standard",
		Category.PROPULSION: "prop_hydrazine_mono",
		Category.COMMUNICATIONS: "comm_x_band_dish",
		Category.COMPUTER: "comp_rad750",
		Category.ADCS: "adcs_3axis_wheels",
		Category.THERMAL: "thermal_passive_mli",
		Category.INSTRUMENTS: "inst_neutron_spectrometer"
	}
