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
var selected_lead_role: String = Helios4CampaignData.ROLE_PROPULSION
var _lead_perk_btns: Dictionary = {}
var _role_cards: Dictionary = {}
var _perk_banner_lbl: Label = null

func _ready() -> void:
	theme = MarginTheme.get_theme()
	selected_player_count = Helios4CampaignData.player_count
	selected_lead_role = Helios4CampaignData.team_perk_id if not Helios4CampaignData.team_perk_id.is_empty() else Helios4CampaignData.active_role
	timed_check.button_pressed = Helios4CampaignData.is_timed_challenge
	
	p1_btn.pressed.connect(func(): _set_player_count(1))
	p2_btn.pressed.connect(func(): _set_player_count(2))
	p3_btn.pressed.connect(func(): _set_player_count(3))
	p4_btn.pressed.connect(func(): _set_player_count(4))
	
	confirm_btn.pressed.connect(_on_confirm_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	_setup_lead_perk_selectors()
	_load_existing_names()
	_update_ui_for_player_count()
	_update_lead_perk_ui()
	MarginTheme.apply_interactive_polish(self)
	
	get_tree().process_frame.connect(func():
		if confirm_btn: print("[TeamAssignment] ConfirmCrewBtn global_rect: ", confirm_btn.get_global_rect(), " center: ", confirm_btn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _setup_lead_perk_selectors() -> void:
	var card_map := {
		Helios4CampaignData.ROLE_PROPULSION: "RolePropulsion",
		Helios4CampaignData.ROLE_STRUCTURAL: "RoleStructural",
		Helios4CampaignData.ROLE_ASTROGATOR: "RoleAstrogator",
		Helios4CampaignData.ROLE_SYSTEMS: "RoleSystems"
	}
	for role_id in card_map:
		var card := find_child(card_map[role_id], true, false) as PanelContainer
		if not card:
			continue
		_role_cards[role_id] = card
		var vbox := card.get_node_or_null("VBox") as VBoxContainer
		if not vbox:
			continue
		var perk_meta: Dictionary = Helios4CampaignData.TEAM_PERK_METADATA.get(role_id, {})
		var perk_lbl := Label.new()
		perk_lbl.text = "ENGINEERING PERK: %s" % perk_meta.get("summary", "")
		perk_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		perk_lbl.add_theme_font_size_override("font_size", 10)
		var col: Color = perk_meta.get("color", Color(0.25, 0.78, 1.0))
		perk_lbl.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.25))
		vbox.add_child(perk_lbl)

		var lead_btn := Button.new()
		lead_btn.name = "LeadPerkBtn_" + role_id
		lead_btn.toggle_mode = true
		lead_btn.custom_minimum_size = Vector2(0, 28)
		lead_btn.add_theme_font_size_override("font_size", 11)
		lead_btn.pressed.connect(func(): _select_lead_role(role_id))
		vbox.add_child(lead_btn)
		_lead_perk_btns[role_id] = lead_btn

	var main_layout := find_child("MainLayout", true, false) as VBoxContainer
	if main_layout:
		var banner := PanelContainer.new()
		banner.name = "TeamPerkBannerPanel"
		var b_style := StyleBoxFlat.new()
		b_style.bg_color = Color(0.05, 0.09, 0.16, 0.92)
		b_style.border_color = Color(0.25, 0.78, 1.0, 0.7)
		b_style.set_border_width_all(1)
		b_style.set_corner_radius_all(5)
		b_style.content_margin_left = 12
		b_style.content_margin_right = 12
		b_style.content_margin_top = 6
		b_style.content_margin_bottom = 6
		banner.add_theme_stylebox_override("panel", b_style)
		_perk_banner_lbl = Label.new()
		_perk_banner_lbl.add_theme_font_size_override("font_size", 11)
		banner.add_child(_perk_banner_lbl)
		main_layout.add_child(banner)
		var bottom_bar := find_child("BottomBar", true, false)
		if bottom_bar:
			main_layout.move_child(banner, bottom_bar.get_index())

func _select_lead_role(role_id: String) -> void:
	selected_lead_role = role_id
	_update_lead_perk_ui()

func _update_lead_perk_ui() -> void:
	for role_id in _lead_perk_btns:
		var btn: Button = _lead_perk_btns[role_id]
		var is_sel: bool = (role_id == selected_lead_role)
		btn.button_pressed = is_sel
		btn.text = "ACTIVE LEAD PERK (SELECTED)" if is_sel else "SELECT AS MISSION LEAD PERK"
		var card: PanelContainer = _role_cards.get(role_id, null)
		if card:
			var col: Color = Helios4CampaignData.ROLE_METADATA[role_id]["color"]
			var box := StyleBoxFlat.new()
			box.bg_color = Color(col.r * 0.16, col.g * 0.16, col.b * 0.18, 0.92) if is_sel else Color(0.06, 0.09, 0.15, 0.88)
			box.border_color = col if is_sel else Color(0.20, 0.28, 0.40, 0.7)
			box.set_border_width_all(2 if is_sel else 1)
			box.set_corner_radius_all(6)
			box.content_margin_left = 14
			box.content_margin_right = 14
			box.content_margin_top = 12
			box.content_margin_bottom = 12
			card.add_theme_stylebox_override("panel", box)
	if _perk_banner_lbl:
		var meta: Dictionary = Helios4CampaignData.TEAM_PERK_METADATA.get(selected_lead_role, {})
		var col: Color = meta.get("color", Color(0.35, 0.9, 1.0))
		_perk_banner_lbl.text = "ACTIVE CAMPAIGN PERK: %s — %s (Persists across Hangar, Crisis & L1 HUDs)" % [
			meta.get("title", "Propulsion Lead"),
			meta.get("summary", "")
		]
		_perk_banner_lbl.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.30))

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
	Helios4CampaignData.set_team_lead_perk(selected_lead_role)
	
	print("[TeamAssignment] Configured crew of %d players (Lead Perk: %s). Transitioning to Phase 1: Hangar" % [selected_player_count, selected_lead_role])
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_1_HANGAR, get_tree())

func _on_back_pressed() -> void:
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PROLOGUE, get_tree())
