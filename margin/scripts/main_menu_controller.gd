class_name MainMenuController
extends Node3D

const MissionScenario = preload("res://margin/data/mission_scenario.gd")

@onready var spacecraft: Spacecraft3D = $Spacecraft3D
@onready var orbit_cam: OrbitCamera = $OrbitCamera
@onready var how_to_play_modal: PanelContainer = %HowToPlayModal

func _ready() -> void:
	# Configure default 3D spacecraft for title display
	var default_cfg = ComponentDatabase.get_default_configuration()
	spacecraft.update_spacecraft(default_cfg)
	
	# Enable gentle auto-rotation for title screen
	orbit_cam.auto_rotate = true
	orbit_cam.auto_rotate_speed = 6.0 # deg/sec
	orbit_cam.distance = 3.8
	orbit_cam.pitch = 18.0
	
	how_to_play_modal.visible = false

	var frontier_btn = find_child("LunarFrontierBtn", true, false)
	if frontier_btn and not frontier_btn.pressed.is_connected(_on_lunar_frontier_pressed):
		frontier_btn.pressed.connect(_on_lunar_frontier_pressed)

	var sandbox_btn = find_child("CreativeSandboxBtn", true, false)
	if sandbox_btn and not sandbox_btn.pressed.is_connected(_on_creative_sandbox_pressed):
		sandbox_btn.pressed.connect(_on_creative_sandbox_pressed)

func _on_creative_sandbox_pressed() -> void:
	print("[MainMenu] Navigating to Creative Sandbox Mode!")
	MissionScenario.set_active_scenario("sandbox")
	get_tree().change_scene_to_file("res://margin/scenes/workshop.tscn")

func _on_start_mission_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/mission_briefing.tscn")

func _on_lunar_frontier_pressed() -> void:
	print("[MainMenu] Navigating to Lunar Frontier 3D Gameplay!")
	get_tree().change_scene_to_file("res://margin/scenes/lunar_frontier.tscn")

func _on_mission_briefing_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/mission_briefing.tscn")

func _on_how_to_play_pressed() -> void:
	how_to_play_modal.visible = true

func _on_close_modal_pressed() -> void:
	how_to_play_modal.visible = false

func _on_jump_to_workshop_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/workshop.tscn")
