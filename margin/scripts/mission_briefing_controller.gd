class_name MissionBriefingController
extends Control

func _on_proceed_to_workshop_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/workshop.tscn")

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/main_menu.tscn")
