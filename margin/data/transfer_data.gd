class_name TransferDatabase
extends RefCounted

# ==============================================================================
# EDUCATIONAL TRANSLUNAR TRANSFER STRATEGIES
# Source: NASA/JPL Lunar Trajectory Monograph (Series 12)
# Reference: https://descanso.jpl.nasa.gov/monograph/series12/LunarTraj--Overall.pdf
# 
# Consistent Pair of Reference Examples from JPL Monograph:
# 1. Direct Conventional Transfer:
#    - Duration: 4.036 days
#    - Lunar Orbit Insertion (LOI): 839.878 m/s (into 100 km circular lunar orbit)
# 2. Low-Energy Ballistic Transfer (Weak Stability Boundary / BLT):
#    - Duration: 83.706 days
#    - Lunar Orbit Insertion (LOI): 669.543 m/s (into low polar lunar orbit)
#
# IMPORTANT:
# - Both values are particular reference examples from the JPL monograph, NOT
#   universal mission requirements.
# - A Ballistic Lunar Transfer (BLT) is NOT an electric propulsion spiral. Both modeled
#   ballistic/direct transfers require chemical propulsion for impulsive capture burns.
# - A separate low-thrust electric spiral trajectory model (6-12 months) is not yet implemented.
# ==============================================================================

static func get_all_transfers() -> Dictionary:
	return {
		"transfer_low_energy": {
			"id": "transfer_low_energy",
			"name": "Low-Energy Ballistic Transfer (WSB/BLT)",
			"tag": "Fuel Efficient / 83.7-Day Transit",
			"duration_days": 83.706,
			"duration_desc": "83.706 Days (JPL Monograph BLT Example)",
			"loi_ref_100km_ms": 669.543,
			"requires_chemical_propulsion": true,
			"requires_impulsive_thrust": true, # Ballistic capture requires impulsive chemical burn
			"thrust_requirement_text": "Requires Chemical Propulsion (Ballistic Perilune Capture)",
			"description": "A Weak Stability Boundary / Ballistic Lunar Transfer (BLT) utilizing Sun-Earth L1/L2 three-body gravity. Reduces insertion ΔV to 669.543 m/s in the cited JPL monograph example, at the cost of an 83.706-day cruise.",
			"tradeoff_positive": "Saves ~170.3 m/s insertion ΔV compared to direct transfer (669.543 m/s vs 839.878 m/s in cited cases), maximizing payload mass and propellant reserve.",
			"tradeoff_negative": "Transit takes 83.706 days (cited example); increases deep-space cruise operations and thermal cycle exposure before science operations begin.",
			"educational_tradeoff": "Utilizing Sun-Earth-Moon gravitational three-body interactions (Weak Stability Boundary) slashes capture ΔV to 669.543 m/s. The trade-off is an 83.7-day transit requiring robust thermal control and cruise communications. Note: Ballistic capture requires an impulsive chemical burn; low-thrust electric spiral is not yet implemented.",
			"jpl_citation": "NASA/JPL lunar trajectory monograph (Series 12) cites 83.706 days transit and 669.543 m/s LOI for a specific low-energy Weak Stability Boundary transfer to a low polar lunar orbit (cited as a specific trajectory example, not a universal constant).",
			"source_url": "https://descanso.jpl.nasa.gov/monograph/series12/LunarTraj--Overall.pdf"
		},
		"transfer_direct": {
			"id": "transfer_direct",
			"name": "Direct Conventional Transfer",
			"tag": "Fast Transit (4.0 Days) / High Capture ΔV",
			"duration_days": 4.036,
			"duration_desc": "4.036 Days (JPL Monograph Direct Example)",
			"loi_ref_100km_ms": 839.878,
			"requires_chemical_propulsion": true,
			"requires_impulsive_thrust": true, # Hyperbolic flyby requires high-thrust impulsive chemical burn
			"thrust_requirement_text": "Requires High-Thrust Chemical Propulsion (Impulsive Burn)",
			"description": "A high-energy direct translunar injection trajectory delivering the spacecraft from Earth to the Moon in 4.036 days. Minimizes cruise duration and radiation exposure, but arrives with high hyperbolic excess velocity requiring an 839.878 m/s braking retro-burn.",
			"tradeoff_positive": "Fast transit (4.036 days in cited example) minimizes cruise operations costs and deep-space radiation/thermal degradation.",
			"tradeoff_negative": "Demands 839.878 m/s LOI capture ΔV (cited JPL 100 km case). Requires high-thrust chemical engines; millinewton electric thrusters cannot brake fast enough during rapid hyperbolic flyby.",
			"educational_tradeoff": "Direct translunar injection reaches the Moon in 4.036 days but with high hyperbolic speed. Capturing into lunar orbit requires a short, impulsive high-thrust chemical burn (839.878 m/s). Low-thrust electric propulsion lacks the thrust-to-weight ratio for this rapid maneuver.",
			"jpl_citation": "NASA/JPL lunar trajectory monograph (Series 12) cites 4.036 days transit and 839.878 m/s LOI for a specific direct transfer into a 100 km circular lunar orbit (cited as an illustrative reference case, not a universal lunar requirement).",
			"source_url": "https://descanso.jpl.nasa.gov/monograph/series12/LunarTraj--Overall.pdf"
		}
	}

static func get_transfer(id: String) -> Dictionary:
	var transfers = get_all_transfers()
	return transfers.get(id, transfers["transfer_low_energy"])

static func get_default_transfer_id() -> String:
	return "transfer_low_energy"
