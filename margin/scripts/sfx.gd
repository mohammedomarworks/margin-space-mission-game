class_name Sfx
extends RefCounted

# ==============================================================================
# MARGIN — SOUND FORWARDER
# Controllers call Sfx.* instead of touching the SoundManager autoload directly.
# Two reasons:
#   1. `godot --headless --script test.gd` does NOT register autoloads, so a
#      direct `SoundManager.` reference fails to compile inside test suites.
#   2. If the autoload is missing for any reason at runtime, audio silently
#      no-ops instead of taking the scene down.
# ==============================================================================

static func _mgr() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root := tree.root
	if root == null:
		return null
	return root.get_node_or_null("SoundManager")


static func play(method: String, args: Array = []) -> void:
	var m := _mgr()
	if m != null and m.has_method(method):
		m.callv(method, args)


static func call_ret(method: String, args: Array = []) -> Variant:
	var m := _mgr()
	if m != null and m.has_method(method):
		return m.callv(method, args)
	return null


# --- Convenience wrappers used by the scene controllers ---

static func ui_hover() -> void: play("play_ui_hover")
static func ui_click() -> void: play("play_ui_click")
static func ui_back() -> void: play("play_ui_back")
static func part_attach() -> void: play("play_part_attach")
static func part_detach() -> void: play("play_part_detach")
static func warning_buzzer() -> void: play("play_warning_buzzer")
static func success_chime() -> void: play("play_success_chime")

static func countdown_beep(is_final: bool = false) -> void: play("play_countdown_beep", [is_final])
static func telemetry_tick() -> void: play("play_telemetry_tick")
static func start_engine_roar() -> void: play("start_engine_roar")
static func set_engine_level(throttle: float, density: float) -> void:
	play("set_engine_level", [throttle, density])
static func stop_engine_roar() -> void: play("stop_engine_roar")
static func thump(intensity: float = 1.0) -> void: play("play_thump", [intensity])
static func meco() -> void: play("play_meco")

static func start_space_ambient() -> void: play("start_space_ambient")
static func stop_space_ambient() -> void: play("stop_space_ambient")
static func rcs_hiss() -> void: play("play_rcs_hiss")
static func radar_ping() -> void: play("play_radar_ping")
static func start_klaxon() -> void: play("start_klaxon")
static func stop_klaxon() -> void: play("stop_klaxon")
static func victory_fanfare() -> void: play("play_victory_fanfare")
static func failure_powerdown() -> void: play("play_failure_powerdown")

static func attach_hud_toggle(root_ui: Control) -> Button:
	return call_ret("attach_hud_toggle", [root_ui]) as Button
