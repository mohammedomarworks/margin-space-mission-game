class_name Helios4CrisisController
extends Control

# ==============================================================================
# MARGIN — HELIOS-4: PHASE 4 — DEEP SPACE CRISIS
# Three deterministic interactive aerospace emergencies:
# 1. Solar Particle Event (SPE) / Radiation Alert
# 2. Micrometeoroid Impact & Propellant Line Leakage
# 3. Star Tracker Blackout & Attitude Stabilization
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")

enum CrisisStep {
	EVENT_A_SOLAR_STORM,
	EVENT_B_MICROMETEOROID,
	EVENT_C_SENSOR_BLACKOUT,
	ALL_CRISES_RESOLVED
}

var current_step: CrisisStep = CrisisStep.EVENT_A_SOLAR_STORM

# UI References
@onready var step_title: Label = %CrisisTitle
@onready var step_desc: Label = %CrisisDescription
@onready var warning_banner: Label = %WarningBanner
@onready var opt1_btn: Button = %Option1Btn
@onready var opt2_btn: Button = %Option2Btn
@onready var opt3_btn: Button = %Option3Btn
@onready var proceed_l1_btn: Button = %ProceedToL1Btn
@onready var role_advice_label: Label = %RoleAdviceLabel

# Accumulated Crisis State
var equipment_degradation_pct: float = 0.0
var science_bonus_pts: float = 0.0
var propellant_lost_kg: float = 0.0
var attitude_accuracy_deg: float = 0.05
var decisions_log: Array = []

func _ready() -> void:
	opt1_btn.pressed.connect(func(): _make_choice(1))
	opt2_btn.pressed.connect(func(): _make_choice(2))
	opt3_btn.pressed.connect(func(): _make_choice(3))
	proceed_l1_btn.pressed.connect(_on_proceed_to_l1_pressed)
	
	_load_crisis_step(current_step)

	get_tree().process_frame.connect(func():
		if opt1_btn: print("[Crisis] Option1Btn center: ", opt1_btn.get_global_rect().get_center())
		if opt2_btn: print("[Crisis] Option2Btn center: ", opt2_btn.get_global_rect().get_center())
		if opt3_btn: print("[Crisis] Option3Btn center: ", opt3_btn.get_global_rect().get_center())
		if proceed_l1_btn: print("[Crisis] ProceedToL1Btn center: ", proceed_l1_btn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _load_crisis_step(step: CrisisStep) -> void:
	match step:
		CrisisStep.EVENT_A_SOLAR_STORM:
			step_title.text = "EVENT A: PRECURSOR SOLAR PARTICLE EVENT (SPE) / RADIATION SURGE"
			warning_banner.text = "▲ PROTON FLUX WARNING: High-energy solar proton event (>1,200 pfu at >10 MeV) from flaring at Active Region AR-4890 sweeping past spacecraft bus."
			warning_banner.add_theme_color_override("font_color", Color(0.98, 0.55, 0.15))
			step_desc.text = "Pre-storm flares at Active Region AR-4890 have accelerated relativistic protons along interplanetary magnetic field lines. While the critical CME shock front itself has not yet erupted toward Earth, this proton flux threatens unshielded sensor optics and high-voltage power lines. Changing spacecraft orientation does NOT deflect incoming relativistic protons."
			
			role_advice_label.text = "ADVISORY: Systems Officer advises Safe Mode to prevent single-event latchups. Astrogator verifies deep-space comm link remains stable."
			
			opt1_btn.text = "1. FULL SAFE MODE\n• Power down sensitive science optics\n• Maintain essential avionics & thermal\n• 0% equipment degradation • -12 science pts"
			opt2_btn.text = "2. PARTIAL PROTECTION\n• Safe vulnerable detector optics only\n• Retain hardened magnetic/plasma sensors\n• 5% minor wear • Normal science yield (+10 pts)"
			opt3_btn.text = "3. CONTINUE SCIENCE OBSERVATIONS\n• Keep full instrument suite active through peak storm\n• Capture high-resolution storm data\n• 18% degradation risk • +25 bonus science pts"
			
		CrisisStep.EVENT_B_MICROMETEOROID:
			step_title.text = "EVENT B: MICROMETEOROID IMPACT & PROPELLANT LEAK"
			warning_banner.text = "▲ CRITICAL LEAK: High-velocity particle punctured Propellant Manifold B (Active leak: ~1.5 kg/s)."
			warning_banner.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
			step_desc.text = "A hypervelocity micrometeoroid has breached a propellant line on the probe's service bus. Trajectory Astrogators must recompute available Delta-V after isolation to ensure enough fuel remains for Sun-Earth L1 halo-orbit insertion and stationkeeping."
			
			role_advice_label.text = "ADVISORY: Propulsion Engineer commands isolation valve sequence. Structural Architect confirms bus frame integrity held."
			
			opt1_btn.text = "1. RAPID ISOLATION VALVE CLOSURE\n• Fire pyrotechnic isolation valve on Manifold B immediately\n• Seals leak within 10s (15 kg fuel lost)\n• Delta-V preserved: ~412 m/s (Ample for L1 Halo + SK)"
			opt2_btn.text = "2. REROUTE THROUGH BACKUP RCS CIRCUIT\n• Cross-feed thrusters through auxiliary line\n• Takes 25s to stabilize (38 kg fuel lost)\n• Delta-V preserved: ~348 m/s (Viable, tighter SK reserve)"
			opt3_btn.text = "3. EMERGENCY BLOWDOWN & PURGE\n• Vent compromised manifold to avoid tank overpressure\n• Takes 45s (75 kg fuel lost)\n• Delta-V preserved: ~285 m/s (Bare minimum for L1 insertion)"
			
		CrisisStep.EVENT_C_SENSOR_BLACKOUT:
			step_title.text = "EVENT C: PRIMARY STAR TRACKER BLACKOUT"
			warning_banner.text = "▲ SENSOR BLINDED: Radiation-induced optical noise saturated the primary star tracker CCD."
			warning_banner.add_theme_color_override("font_color", Color(0.98, 0.65, 0.2))
			step_desc.text = "Deep-space attitude knowledge has degraded. The probe needs stable 3-axis pointing toward Sun-Earth L1 for the upcoming halo-orbit insertion burn. Simplified kinematic models (s = ut + 0.5*a*t^2) model local angular rate settling, though full orbital navigation relies on ground DSN radiometric fixes."
			
			role_advice_label.text = "ADVISORY: Astrogator recommends Ground DSN or Inertial reference to lock attitude before the L1 insertion burn."
			
			opt1_btn.text = "1. BACKUP FIBER-OPTIC GYRO (IMU)\n• Switch to onboard inertial measurement unit\n• Proven internal reference, zero optical dependence\n• Attitude accuracy: ±0.08° (Nominal insertion)"
			opt2_btn.text = "2. DSN GROUND RADIOMETRIC ATTITUDE UPLINK\n• Request ground station antenna array radiometric angle update\n• Takes 12s signal round-trip via Goldstone DSN\n• Attitude accuracy: ±0.02° (High precision)"
			opt3_btn.text = "3. MANUAL RCS PULSE TRIM CHALLENGE\n• Astrogator commands calibrated 2.4s thruster pulse (s = ut + 0.5*a*t^2)\n• Arrests bus body rates manually\n• Attitude accuracy: ±0.15° (Acceptable)"
			
		CrisisStep.ALL_CRISES_RESOLVED:
			step_title.text = "PHASE 4 COMPLETE: ALL CRISIS HAZARDS MITIGATED"
			warning_banner.text = "★ MISSION STATE STABILIZED: Spacecraft systems secured for Sun-Earth L1 Halo-Orbit Insertion."
			warning_banner.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
			step_desc.text = "Decision audit recorded:\n• Solar Storm Strategy: %s\n• Leak Mitigation: %s (Propellant lost: %.1f kg)\n• Attitude Recovery: %s (Attitude accuracy: ±%.2f°)\n\nEquipment Health: %.1f%% • Science Points: +%.1f pts" % [
				decisions_log[0]["title"], decisions_log[1]["title"], propellant_lost_kg, decisions_log[2]["title"], attitude_accuracy_deg,
				100.0 - equipment_degradation_pct, science_bonus_pts
			]
			role_advice_label.text = "ALL CREW: Stationkeeping and halo-orbit insertion parameters locked. Approaching Sun-Earth L1."
			
			opt1_btn.visible = false
			opt2_btn.visible = false
			opt3_btn.visible = false
			proceed_l1_btn.visible = true
			get_tree().process_frame.connect(func():
				print("[Crisis] ProceedToL1Btn center: ", proceed_l1_btn.get_global_rect().get_center())
			, CONNECT_ONE_SHOT)

func _make_choice(choice_idx: int) -> void:
	match current_step:
		CrisisStep.EVENT_A_SOLAR_STORM:
			var title = ""
			match choice_idx:
				1: # Full Safe Mode
					equipment_degradation_pct += 0.0
					science_bonus_pts -= 12.0
					title = "Full Safe Mode"
				2: # Partial Protection
					equipment_degradation_pct += 5.0
					science_bonus_pts += 10.0
					title = "Partial Protection"
				3: # Continue Science
					equipment_degradation_pct += 18.0
					science_bonus_pts += 25.0
					title = "Continue Science"
			decisions_log.append({"event": "Solar Storm", "choice": choice_idx, "title": title, "role": Helios4CampaignData.ROLE_SYSTEMS})
			Helios4CampaignData.record_team_decision(Helios4CampaignData.ROLE_SYSTEMS, "Precursor Solar Storm Mitigation", title)
			current_step = CrisisStep.EVENT_B_MICROMETEOROID
			_load_crisis_step(current_step)
			
		CrisisStep.EVENT_B_MICROMETEOROID:
			var title = ""
			match choice_idx:
				1: # Rapid Isolation
					propellant_lost_kg += 15.0
					title = "Rapid Isolation Valve"
				2: # Backup RCS
					propellant_lost_kg += 38.0
					title = "Backup RCS Reroute"
				3: # Blowdown
					propellant_lost_kg += 75.0
					title = "Emergency Blowdown"
			decisions_log.append({"event": "Micrometeoroid", "choice": choice_idx, "title": title, "role": Helios4CampaignData.ROLE_PROPULSION})
			Helios4CampaignData.record_team_decision(Helios4CampaignData.ROLE_PROPULSION, "Propellant Line Rupture", title)
			current_step = CrisisStep.EVENT_C_SENSOR_BLACKOUT
			_load_crisis_step(current_step)
			
		CrisisStep.EVENT_C_SENSOR_BLACKOUT:
			var title = ""
			match choice_idx:
				1: # IMU
					attitude_accuracy_deg = 0.08
					title = "Inertial IMU Switch"
				2: # Ground DSN
					attitude_accuracy_deg = 0.02
					title = "DSN Radiometric Uplink"
				3: # Manual RCS Challenge
					attitude_accuracy_deg = 0.15
					title = "Manual RCS Kinematic Pulse"
			decisions_log.append({"event": "Sensor Blackout", "choice": choice_idx, "title": title, "role": Helios4CampaignData.ROLE_ASTROGATOR})
			Helios4CampaignData.record_team_decision(Helios4CampaignData.ROLE_ASTROGATOR, "Star Tracker Attitude Recovery", title)
			current_step = CrisisStep.ALL_CRISES_RESOLVED
			_load_crisis_step(current_step)

func _on_proceed_to_l1_pressed() -> void:
	Helios4CampaignData.crisis_results = {
		"equipment_degradation_pct": equipment_degradation_pct,
		"science_bonus_pts": science_bonus_pts,
		"propellant_lost_kg": propellant_lost_kg,
		"attitude_accuracy_deg": attitude_accuracy_deg,
		"decisions_log": decisions_log
	}
	print("[Crisis] All emergencies resolved. Advancing to Phase 5: L1 Halo-Orbit Insertion")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_5_L1_INSERTION, get_tree())
