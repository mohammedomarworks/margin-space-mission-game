class_name Helios4EngineeringReviewController
extends Control

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")

@onready var check_list: VBoxContainer = %CheckList
@onready var launch_btn: Button = %ProceedToLaunchBtn
@onready var override_launch_btn: Button = %OverrideAndProceedBtn
@onready var return_hangar_btn: Button = %ReturnToHangarBtn
@onready var status_banner: Label = %StatusBanner

# Role Votes
var votes: Dictionary = {
	Helios4CampaignData.ROLE_PROPULSION: false,
	Helios4CampaignData.ROLE_STRUCTURAL: false,
	Helios4CampaignData.ROLE_ASTROGATOR: false,
	Helios4CampaignData.ROLE_SYSTEMS: false
}

var telemetry: Dictionary = {}
var _risk_banner_panel: PanelContainer = null
var _risk_banner_label: Label = null

func _ready() -> void:
	theme = MarginTheme.get_theme()
	telemetry = Helios4CampaignData.calculate_hangar_telemetry()
	_setup_risk_banner()
	_populate_checks()
	_setup_role_voting_buttons()
	
	launch_btn.pressed.connect(_on_launch_pressed)
	override_launch_btn.pressed.connect(_on_override_launch_pressed)
	return_hangar_btn.pressed.connect(_on_return_hangar_pressed)
	launch_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	override_launch_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	return_hangar_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_update_launch_button_state()
	MarginTheme.apply_interactive_polish(self)

func _setup_risk_banner() -> void:
	var main_layout := find_child("MainLayout", true, false) as VBoxContainer
	if not main_layout or _risk_banner_panel != null:
		return
	_risk_banner_panel = PanelContainer.new()
	_risk_banner_panel.name = "RiskWaiverBanner"
	_risk_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_risk_banner_panel.visible = false
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.22, 0.08, 0.04, 0.92)
	r_style.border_color = Color(0.98, 0.45, 0.18, 0.95)
	r_style.set_border_width_all(1)
	r_style.set_corner_radius_all(5)
	r_style.content_margin_left = 12
	r_style.content_margin_right = 12
	r_style.content_margin_top = 6
	r_style.content_margin_bottom = 6
	_risk_banner_panel.add_theme_stylebox_override("panel", r_style)
	_risk_banner_label = Label.new()
	_risk_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_risk_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_risk_banner_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	_risk_banner_label.add_theme_font_size_override("font_size", 11)
	_risk_banner_panel.add_child(_risk_banner_label)
	main_layout.add_child(_risk_banner_panel)
	if status_banner:
		main_layout.move_child(_risk_banner_panel, status_banner.get_index() + 1)

func _collect_failed_gate_names() -> Array[String]:
	var failed: Array[String] = []
	for chk in telemetry.get("gate_checks", []):
		if str(chk.get("status", "FAIL")) != "PASS":
			failed.append(str(chk.get("name", "Unknown Gate")))
	return failed

	get_tree().process_frame.connect(func():
		if launch_btn: print("[EngineeringReview] ProceedToLaunchBtn global_rect: ", launch_btn.get_global_rect(), " center: ", launch_btn.get_global_rect().get_center())
		for r_id in [Helios4CampaignData.ROLE_PROPULSION, Helios4CampaignData.ROLE_STRUCTURAL, Helios4CampaignData.ROLE_ASTROGATOR, Helios4CampaignData.ROLE_SYSTEMS]:
			var vbtn = find_child("VoteBtn_" + r_id, true, false)
			if vbtn: print("[EngineeringReview] VoteBtn_", r_id, " center: ", vbtn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _populate_checks() -> void:
	for child in check_list.get_children():
		child.queue_free()
		
	var checks: Array = telemetry.get("gate_checks", [])
	for chk in checks:
		var panel := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		var is_pass: bool = (chk["status"] == "PASS")
		var is_warn: bool = (chk["status"] == "WARN")
		
		if is_pass:
			p_style.bg_color = Color(0.04, 0.12, 0.08, 0.9)
			p_style.border_color = Color(0.35, 0.85, 0.55, 0.8)
		elif is_warn:
			p_style.bg_color = Color(0.14, 0.1, 0.04, 0.9)
			p_style.border_color = Color(0.98, 0.65, 0.2, 0.8)
		else:
			p_style.bg_color = Color(0.15, 0.05, 0.05, 0.9)
			p_style.border_color = Color(0.95, 0.3, 0.3, 0.8)
			
		p_style.set_border_width_all(1)
		p_style.set_corner_radius_all(6)
		p_style.content_margin_left = 16
		p_style.content_margin_top = 10
		p_style.content_margin_right = 16
		p_style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", p_style)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		
		var hbox := HBoxContainer.new()
		var title_lbl := Label.new()
		title_lbl.text = "[%s] %s" % [chk["status"], chk["name"]]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_col = Color(0.35, 0.9, 0.55) if is_pass else (Color(0.98, 0.65, 0.2) if is_warn else Color(0.95, 0.35, 0.35))
		title_lbl.add_theme_color_override("font_color", title_col)
		title_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(title_lbl)
		
		var val_lbl := Label.new()
		val_lbl.text = "%s (Target: %s)" % [chk["value_str"], chk["target_str"]]
		val_lbl.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98))
		val_lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(val_lbl)
		vbox.add_child(hbox)
		
		var adv_lbl := Label.new()
		adv_lbl.text = "Responsible Role: %s • %s" % [chk["role"].to_upper(), chk["advice"]]
		adv_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
		adv_lbl.add_theme_font_size_override("font_size", 11)
		adv_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(adv_lbl)
		
		if not is_pass:
			var fix_hbox := HBoxContainer.new()
			var cor_lbl := Label.new()
			cor_lbl.text = "Recommended Fix: %s" % chk.get("correction", "Adjust parameters in Hangar.")
			cor_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cor_lbl.add_theme_color_override("font_color", Color(0.98, 0.65, 0.25))
			cor_lbl.add_theme_font_size_override("font_size", 11)
			cor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fix_hbox.add_child(cor_lbl)
			
			var fix_btn := Button.new()
			fix_btn.text = "FIX IN %s >" % chk["role"].to_upper()
			fix_btn.add_theme_font_size_override("font_size", 10)
			var btn_style := StyleBoxFlat.new()
			btn_style.bg_color = Color(0.2, 0.08, 0.08, 0.95)
			btn_style.border_color = Color(0.95, 0.4, 0.3)
			btn_style.set_border_width_all(1)
			btn_style.set_corner_radius_all(4)
			btn_style.content_margin_left = 8
			btn_style.content_margin_right = 8
			fix_btn.add_theme_stylebox_override("normal", btn_style)
			fix_btn.pressed.connect(func():
				Helios4CampaignData.active_role = chk["role"]
				Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_1_HANGAR, get_tree())
			)
			fix_hbox.add_child(fix_btn)
			vbox.add_child(fix_hbox)
		
		panel.add_child(vbox)
		check_list.add_child(panel)

func _setup_role_voting_buttons() -> void:
	# Auto-cast votes if checks pass, or allow manual pass-and-play GO sign-offs
	for r_id in [Helios4CampaignData.ROLE_PROPULSION, Helios4CampaignData.ROLE_STRUCTURAL, Helios4CampaignData.ROLE_ASTROGATOR, Helios4CampaignData.ROLE_SYSTEMS]:
		var btn = find_child("VoteBtn_" + r_id, true, false) as Button
		if btn:
			var role_name = Helios4CampaignData.team_player_names.get(r_id, "Specialist")
			btn.text = "SIGN OFF [GO]: %s" % role_name
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.focus_mode = Control.FOCUS_ALL
			btn.disabled = false
			btn.pressed.connect(_on_role_vote_pressed.bind(r_id, btn, role_name))

func _on_role_vote_pressed(role_id: String, btn: Button, role_name: String) -> void:
	votes[role_id] = not bool(votes.get(role_id, false))
	btn.button_pressed = votes[role_id]
	btn.text = ("SIGNED [GO]: %s" % role_name) if votes[role_id] else ("SIGN OFF [GO]: %s" % role_name)
	_update_launch_button_state()

func _update_launch_button_state() -> void:
	var all_checks_passed: bool = telemetry.get("all_gate_checks_passed", false)
	var all_voted: bool = (votes[Helios4CampaignData.ROLE_PROPULSION] and votes[Helios4CampaignData.ROLE_STRUCTURAL] and votes[Helios4CampaignData.ROLE_ASTROGATOR] and votes[Helios4CampaignData.ROLE_SYSTEMS])
	var failed_names := _collect_failed_gate_names()
	override_launch_btn.disabled = false

	if _risk_banner_panel and _risk_banner_label:
		if not failed_names.is_empty():
			_risk_banner_panel.visible = true
			_risk_banner_label.text = "RISK WARNING (%d MARGIN HOLD%s): Waiving %s" % [
				failed_names.size(),
				"S" if failed_names.size() > 1 else "",
				", ".join(failed_names)
			]
		elif Helios4CampaignData.launch_readiness_override and not Helios4CampaignData.waived_gates.is_empty():
			_risk_banner_panel.visible = true
			_risk_banner_label.text = "WAIVER RECORDED: Proceeding under Flight Director waiver (%s)" % ", ".join(Helios4CampaignData.waived_gates)
		else:
			_risk_banner_panel.visible = false
	
	if not all_checks_passed:
		status_banner.text = "REVIEW HOLD: use SIGN OFF ALL / FLIGHT DIRECTOR WAIVER to proceed with trade-offs, or return to the Hangar."
		status_banner.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
		launch_btn.disabled = true
		launch_btn.text = "REVIEW HOLD — WAIVER AVAILABLE"
		Helios4CampaignData.is_launch_authorized = false
	elif not all_voted:
		status_banner.text = "- ENGINEERING CHECKS PASSED: All 4 workstations must sign off [GO] for final launchpad clearance."
		status_banner.add_theme_color_override("font_color", Color(0.98, 0.65, 0.2))
		launch_btn.disabled = true
		launch_btn.text = "AWAITING 4-OFFICER GO SIGN-OFF"
		Helios4CampaignData.is_launch_authorized = false
	else:
		status_banner.text = "* UNANIMOUS GO FOR LAUNCH: HELIOS-4 Launchpad clearance granted."
		status_banner.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
		launch_btn.disabled = false
		launch_btn.text = "PROCEED TO EARTH LAUNCH (PHASE 2) >"
		Helios4CampaignData.set_launch_authorized(true)

func _on_launch_pressed() -> void:
	print("[EngineeringReview] FRR Approval Unanimous! Advancing to Earth Launch Pad (Phase 2)")
	Helios4CampaignData.launch_readiness_override = false
	Helios4CampaignData.set_launch_authorized(true)
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_2_LAUNCH, get_tree())

func _on_override_launch_pressed() -> void:
	var failed_names := _collect_failed_gate_names()
	print("[EngineeringReview] Flight Director waiver used; auto-resolving four GO votes and entering Launch. Waived: ", failed_names)
	for role_id in [Helios4CampaignData.ROLE_PROPULSION, Helios4CampaignData.ROLE_STRUCTURAL, Helios4CampaignData.ROLE_ASTROGATOR, Helios4CampaignData.ROLE_SYSTEMS]:
		votes[role_id] = true
		var vote_btn := find_child("VoteBtn_" + role_id, true, false) as Button
		if vote_btn:
			vote_btn.button_pressed = true
			vote_btn.text = "SIGNED [GO]: %s" % Helios4CampaignData.team_player_names.get(role_id, "Specialist")
	Helios4CampaignData.waived_gates = failed_names.duplicate()
	Helios4CampaignData.launch_readiness_override = true
	var waiver_detail: String = "Auto-resolved four GO votes." if failed_names.is_empty() else ("Waived %d hold(s): %s" % [failed_names.size(), ", ".join(failed_names)])
	Helios4CampaignData.record_team_decision(Helios4CampaignData.active_role, "Flight Readiness Waiver", waiver_detail)
	Helios4CampaignData.set_launch_authorized(true)
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_2_LAUNCH, get_tree())

func _on_return_hangar_pressed() -> void:
	Helios4CampaignData.set_launch_authorized(false)
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_1_HANGAR, get_tree())
