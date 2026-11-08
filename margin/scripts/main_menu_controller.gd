class_name MainMenuController
extends Node3D

const MissionScenario = preload("res://margin/data/mission_scenario.gd")
const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")

@onready var spacecraft: Spacecraft3D = $Spacecraft3D
@onready var orbit_cam: OrbitCamera = $OrbitCamera
@onready var how_to_play_modal: PanelContainer = %HowToPlayModal

var quick_missions_modal: PanelContainer = null
var continue_btn: Button = null

func _ready() -> void:
	# Configure default 3D spacecraft for title display
	var default_cfg = ComponentDatabase.get_default_configuration()
	# Equip DSCOVR plasma boom if available for title display
	default_cfg[ComponentDatabase.Category.INSTRUMENTS] = "inst_dscovr_plasmapack"
	spacecraft.update_spacecraft(default_cfg)
	
	# Enable gentle auto-rotation for title screen
	orbit_cam.auto_rotate = true
	orbit_cam.auto_rotate_speed = 6.0 # deg/sec
	orbit_cam.distance = 3.8
	orbit_cam.pitch = 18.0
	
	if how_to_play_modal:
		how_to_play_modal.visible = false

	# Locate or connect Campaign Primary Buttons
	var new_camp_btn = find_child("NewCampaignBtn", true, false)
	if new_camp_btn:
		if not new_camp_btn.pressed.is_connected(_on_new_campaign_pressed):
			new_camp_btn.pressed.connect(_on_new_campaign_pressed)
		get_tree().process_frame.connect(func():
			print("[MainMenu] NewCampaignBtn global_rect: ", new_camp_btn.get_global_rect(), " center: ", new_camp_btn.get_global_rect().get_center())
		, CONNECT_ONE_SHOT)

	continue_btn = find_child("ContinueCampaignBtn", true, false) as Button
	if continue_btn:
		if not continue_btn.pressed.is_connected(_on_continue_campaign_pressed):
			continue_btn.pressed.connect(_on_continue_campaign_pressed)
		_update_continue_button_state()

	var quick_btn = find_child("QuickMissionsBtn", true, false)
	if quick_btn and not quick_btn.pressed.is_connected(_on_quick_missions_pressed):
		quick_btn.pressed.connect(_on_quick_missions_pressed)

	var sandbox_btn = find_child("CreativeSandboxBtn", true, false)
	if sandbox_btn and not sandbox_btn.pressed.is_connected(_on_creative_sandbox_pressed):
		sandbox_btn.pressed.connect(_on_creative_sandbox_pressed)

	var settings_btn = find_child("SettingsHowToPlayBtn", true, false)
	if settings_btn and not settings_btn.pressed.is_connected(_on_how_to_play_pressed):
		settings_btn.pressed.connect(_on_how_to_play_pressed)

	quick_missions_modal = find_child("QuickMissionsModal", true, false) as PanelContainer
	if quick_missions_modal:
		quick_missions_modal.visible = false
		_setup_quick_mission_buttons()

	# Backward compatibility with existing tests
	var start_btn = find_child("StartMissionBtn", true, false)
	if start_btn and not start_btn.pressed.is_connected(_on_start_mission_pressed):
		start_btn.pressed.connect(_on_start_mission_pressed)

	var frontier_btn = find_child("LunarFrontierBtn", true, false)
	if frontier_btn and not frontier_btn.pressed.is_connected(_on_lunar_frontier_pressed):
		frontier_btn.pressed.connect(_on_lunar_frontier_pressed)

func _update_continue_button_state() -> void:
	if not continue_btn:
		return
	if Helios4CampaignData.has_saved_campaign():
		continue_btn.disabled = false
		continue_btn.text = "CONTINUE CAMPAIGN [HELIOS-4]"
		continue_btn.tooltip_text = "Resume active HELIOS-4 campaign progress."
	else:
		continue_btn.disabled = true
		continue_btn.text = "CONTINUE CAMPAIGN (NO SAVE)"
		continue_btn.tooltip_text = "Start a New Campaign to begin."

func _on_new_campaign_pressed() -> void:
	print("[MainMenu] Launching New HELIOS-4 Campaign!")
	Helios4CampaignData.reset_campaign()
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PROLOGUE, get_tree())

func _on_continue_campaign_pressed() -> void:
	print("[MainMenu] Continuing Saved Campaign...")
	if Helios4CampaignData.load_campaign_state():
		Helios4CampaignData.load_stage(Helios4CampaignData.current_stage, get_tree())
	else:
		_on_new_campaign_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if quick_missions_modal and quick_missions_modal.visible:
			quick_missions_modal.visible = false
		if how_to_play_modal and how_to_play_modal.visible:
			how_to_play_modal.visible = false

func _on_quick_missions_pressed() -> void:
	print("[MainMenu] Opening Quick Missions modal")
	if quick_missions_modal:
		quick_missions_modal.visible = true
		get_tree().process_frame.connect(func():
			var close_btn = quick_missions_modal.find_child("CloseQuickMissionsBtn", true, false)
			if close_btn:
				print("[MainMenu] CloseQuickMissionsBtn center: ", close_btn.get_global_rect().get_center())
		, CONNECT_ONE_SHOT)

func _setup_quick_mission_buttons() -> void:
	var lsp_btn = quick_missions_modal.find_child("QuickLSPBtn", true, false)
	if lsp_btn:
		lsp_btn.pressed.connect(func():
			print("[MainMenu] Quick Mission: Lunar South Pole (LSP-01)")
			MissionScenario.set_active_scenario("lunar_south_pole")
			get_tree().change_scene_to_file("res://margin/scenes/mission_briefing.tscn")
		)
		
	var ecs_btn = quick_missions_modal.find_child("QuickECSBtn", true, false)
	if ecs_btn:
		ecs_btn.pressed.connect(func():
			print("[MainMenu] Quick Mission: Earth Climate Sentinel (ECS-01)")
			MissionScenario.set_active_scenario("earth_climate_sentinel")
			get_tree().change_scene_to_file("res://margin/scenes/mission_briefing.tscn")
		)
		
	var frontier_btn = quick_missions_modal.find_child("QuickFrontierBtn", true, false)
	if frontier_btn:
		frontier_btn.pressed.connect(func():
			print("[MainMenu] Quick Mission: Lunar Frontier 3D Exploration")
			get_tree().change_scene_to_file("res://margin/scenes/lunar_frontier.tscn")
		)
		
	var close_quick_btn = quick_missions_modal.find_child("CloseQuickMissionsBtn", true, false)
	if close_quick_btn:
		close_quick_btn.pressed.connect(func():
			quick_missions_modal.visible = false
		)

func _on_creative_sandbox_pressed() -> void:
	print("[MainMenu] Navigating to Creative Sandbox Mode!")
	MissionScenario.set_active_scenario("sandbox")
	get_tree().change_scene_to_file("res://margin/scenes/workshop.tscn")

func _on_start_mission_pressed() -> void:
	# Default to HELIOS-4 campaign if started via legacy button
	_on_new_campaign_pressed()

func _on_lunar_frontier_pressed() -> void:
	print("[MainMenu] Navigating to Lunar Frontier 3D Gameplay!")
	get_tree().change_scene_to_file("res://margin/scenes/lunar_frontier.tscn")

func _on_mission_briefing_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/mission_briefing.tscn")

func _on_how_to_play_pressed() -> void:
	if how_to_play_modal:
		how_to_play_modal.visible = true

func _on_close_modal_pressed() -> void:
	if how_to_play_modal:
		how_to_play_modal.visible = false

func _on_jump_to_workshop_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/workshop.tscn")
