class_name Helios4TeamAssignmentController
extends Control

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")

@onready var p1_btn: Button = %Player1Btn
@onready var p2_btn: Button = %Player2Btn
@onready var p3_btn: Button = %Player3Btn
@onready var p4_btn: Button = %Player4Btn

@onready var name_propulsion: LineEdit = %NamePropulsion
@onready var name_structural: LineEdit = %NameStructural
@onready var name_astrogator: LineEdit = %NameAstrogator
@onready var name_systems: LineEdit = %NameSystems

@onready var timed_check: CheckBox = %TimedChallengeCheck
@onready var confirm_btn: Button = %ConfirmCrewBtn
@onready var back_btn: Button = %BackBtn

var selected_player_count: int = 1

func _ready() -> void:
	theme = MarginTheme.get_theme()
	selected_player_count = Helios4CampaignData.player_count
	timed_check.button_pressed = Helios4CampaignData.is_timed_challenge
	
	p1_btn.pressed.connect(func(): _set_player_count(1))
	p2_btn.pressed.connect(func(): _set_player_count(2))
	p3_btn.pressed.connect(func(): _set_player_count(3))
	p4_btn.pressed.connect(func(): _set_player_count(4))
	
	confirm_btn.pressed.connect(_on_confirm_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	_load_existing_names()
	_update_ui_for_player_count()
	
	get_tree().process_frame.connect(func():
		if confirm_btn: print("[TeamAssignment] ConfirmCrewBtn global_rect: ", confirm_btn.get_global_rect(), " center: ", confirm_btn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _load_existing_names() -> void:
	var names = Helios4CampaignData.team_player_names
	name_propulsion.text = names.get(Helios4CampaignData.ROLE_PROPULSION, "Specialist 1")
	name_structural.text = names.get(Helios4CampaignData.ROLE_STRUCTURAL, "Specialist 2")
	name_astrogator.text = names.get(Helios4CampaignData.ROLE_ASTROGATOR, "Specialist 3")
	name_systems.text = names.get(Helios4CampaignData.ROLE_SYSTEMS, "Specialist 4")

func _set_player_count(count: int) -> void:
	selected_player_count = count
	_update_ui_for_player_count()

func _update_ui_for_player_count() -> void:
	# Update active button styles
	p1_btn.button_pressed = (selected_player_count == 1)
	p2_btn.button_pressed = (selected_player_count == 2)
	p3_btn.button_pressed = (selected_player_count == 3)
	p4_btn.button_pressed = (selected_player_count == 4)
	
	var mode_desc = find_child("PlayerCountDesc", true, false) as Label
	if mode_desc:
		match selected_player_count:
			1:
				mode_desc.text = "SOLO MISSION: You control all four workstations and can switch roles freely."
			2:
				mode_desc.text = "2-PLAYER CO-OP: Player 1 commands Propulsion & Trajectory; Player 2 commands Structures & Systems."
			3:
				mode_desc.text = "3-PLAYER CO-OP: Dedicated Propulsion & Structures officers; shared Astrogator & Systems duty."
			4:
				mode_desc.text = "4-PLAYER CO-OP: Four dedicated specialist workstations with full pass-and-play handoff."

func _on_confirm_pressed() -> void:
	Helios4CampaignData.player_count = selected_player_count
	Helios4CampaignData.is_timed_challenge = timed_check.button_pressed
	Helios4CampaignData.hangar_time_remaining = 600.0 if timed_check.button_pressed else 0.0
	
	var names: Dictionary = {
		Helios4CampaignData.ROLE_PROPULSION: name_propulsion.text.strip_edges() if not name_propulsion.text.is_empty() else "Propulsion Lead",
		Helios4CampaignData.ROLE_STRUCTURAL: name_structural.text.strip_edges() if not name_structural.text.is_empty() else "Structural Lead",
		Helios4CampaignData.ROLE_ASTROGATOR: name_astrogator.text.strip_edges() if not name_astrogator.text.is_empty() else "Astrogator Lead",
		Helios4CampaignData.ROLE_SYSTEMS: name_systems.text.strip_edges() if not name_systems.text.is_empty() else "Systems Lead"
	}
	Helios4CampaignData.team_player_names = names
	Helios4CampaignData.active_role = Helios4CampaignData.ROLE_PROPULSION
	
	print("[TeamAssignment] Configured crew of %d players. Transitioning to Phase 1: Hangar" % selected_player_count)
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_1_HANGAR, get_tree())

func _on_back_pressed() -> void:
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PROLOGUE, get_tree())
