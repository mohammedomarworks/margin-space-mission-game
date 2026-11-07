class_name Helios4DebriefController
extends Control

# ==============================================================================
# MARGIN — HELIOS-4: MISSION DEBRIEF & SCIENTIFIC AUDIT
# Scorecard, 4-Officer Team Contribution, Stationkeeping Margin, and
# Space Weather Early-Warning Delivery Report.
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")

@onready var outcome_lbl: Label = %OutcomeLabel
@onready var grade_lbl: Label = %GradeLabel
@onready var score_lbl: Label = %ScoreLabel
@onready var summary_text: RichTextLabel = %DebriefSummaryText
@onready var team_report_text: RichTextLabel = %TeamReportText

@onready var save_btn: Button = %SaveAndCompleteBtn
@onready var replay_btn: Button = %ReplayMissionBtn
@onready var menu_btn: Button = %MainMenuBtn

var total_score: float = 0.0
var letter_grade: String = "A"
var is_success: bool = true

func _ready() -> void:
	_calculate_debrief_score()
	_populate_ui()
	
	save_btn.pressed.connect(_on_save_and_complete_pressed)
	replay_btn.pressed.connect(_on_replay_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

	get_tree().process_frame.connect(func():
		if save_btn: print("[Debrief] SaveAndCompleteBtn center: ", save_btn.get_global_rect().get_center())
		if menu_btn: print("[Debrief] MainMenuBtn center: ", menu_btn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _calculate_debrief_score() -> void:
	var l_tel = Helios4CampaignData.launch_telemetry
	var c_res = Helios4CampaignData.crisis_results
	var l1_tel = Helios4CampaignData.l1_telemetry
	
	# 1. Launch & Staging Pillar (Max 25 pts)
	var p1_score: float = 25.0
	var stress = l_tel.get("structural_stress_pct", 0.0)
	var traj_err = l_tel.get("trajectory_error_pct", 0.0)
	p1_score = clamp(p1_score - (stress * 0.25) - (traj_err * 0.3), 5.0, 25.0)
	
	# 2. Crisis Survival Pillar (Max 25 pts)
	var p2_score: float = 25.0
	var deg = c_res.get("equipment_degradation_pct", 5.0)
	var sci_bonus = c_res.get("science_bonus_pts", 10.0)
	p2_score = clamp(p2_score - (deg * 0.4) + (sci_bonus * 0.3), 5.0, 25.0)
	
	# 3. L1 Halo-Orbit & Stationkeeping Pillar (Max 25 pts)
	var p3_score: float = 25.0
	var final_fuel = l1_tel.get("final_propellant_kg", 200.0)
	if final_fuel < 35.0:
		p3_score = 10.0
	elif final_fuel < 80.0:
		p3_score = 18.0
	else:
		p3_score = 25.0
		
	# 4. Early-Warning & Data Quality Pillar (Max 25 pts)
	var p4_score: float = 25.0
	var warning_sent = l1_tel.get("warning_packet_sent", true)
	if not warning_sent:
		p4_score = 0.0
		is_success = false
		
	total_score = p1_score + p2_score + p3_score + p4_score
	
	if total_score >= 90.0:
		letter_grade = "A+"
	elif total_score >= 80.0:
		letter_grade = "A"
	elif total_score >= 70.0:
		letter_grade = "B"
	elif total_score >= 60.0:
		letter_grade = "C"
	else:
		letter_grade = "F"
		is_success = false
		
	Helios4CampaignData.final_debrief_data = {
		"total_score": total_score,
		"letter_grade": letter_grade,
		"is_success": is_success,
		"launch_pillar": p1_score,
		"crisis_pillar": p2_score,
		"l1_pillar": p3_score,
		"warning_pillar": p4_score
	}

func _populate_ui() -> void:
	if is_success:
		outcome_lbl.text = "MISSION SUCCESSFUL — HELIOS-4 FULLY COMMISSIONED"
		outcome_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	else:
		outcome_lbl.text = "MISSION DEGRADED — LOSS OF MINIMUM OBJECTIVES"
		outcome_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
		
	grade_lbl.text = "GRADE: " + letter_grade
	score_lbl.text = "%.1f / 100 PTS" % total_score
	
	var c_res = Helios4CampaignData.crisis_results
	var l1_tel = Helios4CampaignData.l1_telemetry
	var lead_time = l1_tel.get("lead_time_minutes", 42.5)
	var equip_health = 100.0 - c_res.get("equipment_degradation_pct", 5.0)
	var rem_fuel = l1_tel.get("final_propellant_kg", 205.0)
	
	summary_text.text = """[b]SCIENTIFIC & OPERATIONAL DEBRIEF:[/b]
• [color=#38bdf8]Target Orbit:[/color] Stable 3D Halo Orbit around Sun-Earth L1 (~1.5 Million km Sunward).
• [color=#4ade80]Space Weather Warning Lead Time:[/color] [b]%.1f Minutes Advance Notice Delivered to Earth.[/b]
• [color=#fbbf24]Stationkeeping Propellant Reserve:[/color] %.1f kg (Ensures >= 3-Year Extended Operational Baseline).
• [color=#c084fc]Subsystem Health:[/color] %.1f%% Sensor Suite Integrity (Rad-Hardened Avionics Nominal).
• [color=#f87171]Heritage Benchmark:[/color] Validates NASA DSCOVR PlasMag operational architecture.""" % [lead_time, rem_fuel, equip_health]

	var names = Helios4CampaignData.team_player_names
	var prop_name = names.get(Helios4CampaignData.ROLE_PROPULSION, "Specialist 1")
	var struct_name = names.get(Helios4CampaignData.ROLE_STRUCTURAL, "Specialist 2")
	var astro_name = names.get(Helios4CampaignData.ROLE_ASTROGATOR, "Specialist 3")
	var sys_name = names.get(Helios4CampaignData.ROLE_SYSTEMS, "Specialist 4")
	
	team_report_text.text = """[b]COOPERATIVE 4-OFFICER TEAM CONTRIBUTION REPORT:[/b]
• [color=#fb923c]Propulsion Engineer [%s]:[/color] Controlled multi-stage ascent throttle, executed staging separation, and isolated damaged propellant manifold during micrometeoroid strike.
• [color=#4ade80]Structural Architect [%s]:[/color] Maintained aerodynamic static margin > 1.2 calibers, monitored dynamic pressure through Max-Q (32 kPa), and audited spacecraft hull stress.
• [color=#38bdf8]Astrogator [%s]:[/color] Programmed gravity-turn pitch schedule, calculated MCC-1 mid-course burn, and executed halo-orbit insertion capture at Sun-Earth L1.
• [color=#e879f9]Systems Officer [%s]:[/color] Balanced solar power generation vs 165W electrical load, managed radiation safe mode, deployed magnetometer boom, and beamed the early-warning telemetry packet.""" % [prop_name, struct_name, astro_name, sys_name]

func _on_save_and_complete_pressed() -> void:
	Helios4CampaignData.advance_to_stage(Helios4CampaignData.Stage.CAMPAIGN_COMPLETED)
	save_btn.text = "★ CAMPAIGN PROGRESS SAVED!"
	save_btn.disabled = true
	print("[Debrief] HELIOS-4 campaign completed and persisted to user://helios4_campaign.json")

func _on_replay_pressed() -> void:
	Helios4CampaignData.reset_campaign()
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_1_HANGAR, get_tree())

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/main_menu.tscn")
