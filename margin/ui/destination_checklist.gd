class_name DestinationChecklist
extends PanelContainer

# ==============================================================================
# MARGIN — DESTINATION REQUIREMENT CHECKLIST
# Live per-target engineering gate list for the Hangar. Reads the active
# destination from Helios4CampaignData and evaluates it against current hangar
# telemetry, so the player sees exactly which NASA requirement is still red.
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")

var _rows_box: VBoxContainer = null
var _title: Label = null
var _summary: Label = null
var _last_all_passed: bool = true


func _ready() -> void:
	theme = MarginTheme.get_theme()
	_build()
	refresh()


func _build() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.15, 0.92)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.22, 0.34, 0.48)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	add_child(vb)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	vb.add_child(_title)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 11)
	vb.add_child(_summary)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 2)
	vb.add_child(_rows_box)


func refresh() -> void:
	if _rows_box == null:
		return
	var dest_id: String = Helios4CampaignData.get_destination()
	var meta: Dictionary = DestinationData.get_metadata(dest_id)
	var tel: Dictionary = Helios4CampaignData.calculate_hangar_telemetry()
	var probe: Dictionary = Helios4CampaignData.probe_config
	if probe.is_empty():
		probe = Helios4CampaignData.get_default_probe_config()

	var rows: Array = DestinationData.evaluate(tel, dest_id, probe)

	_title.text = "%s REQUIREMENTS" % meta["name"]
	_title.add_theme_color_override("font_color", meta["accent"])

	var passed: int = DestinationData.count_passed(rows)
	var all_ok: bool = DestinationData.all_passed(rows)
	_summary.text = "%d / %d gates green — %s" % [
		passed, rows.size(), "FLIGHT READY" if all_ok else "NOT READY"
	]
	_summary.add_theme_color_override("font_color",
		Color(0.35, 0.95, 0.55) if all_ok else Color(1.0, 0.55, 0.30))

	# Buzz once when a gate flips to red
	if _last_all_passed and not all_ok:
		Sfx.warning_buzzer()
	_last_all_passed = all_ok

	for c in _rows_box.get_children():
		c.queue_free()

	for r in rows:
		var line := Label.new()
		var ok: bool = r.get("passed", false)
		var unit: String = r.get("unit", "")
		var actual: float = float(r.get("actual", 0.0))
		var required: float = float(r.get("required", 0.0))
		var actual_str: String = ("%.0f" % actual) if unit in ["m/s", "W", "Wh", "pts"] else ("%.1f" % actual)
		var req_str: String = ("%.0f" % required) if unit in ["m/s", "W", "Wh", "pts"] else ("%.1f" % required)
		if unit == "":
			line.text = ("[OK] " if ok else "[X] ") + str(r.get("label", ""))
		else:
			line.text = ("[OK] " if ok else "[X] ") + "%s: %s / %s %s" % [
				str(r.get("label", "")), actual_str, req_str, unit
			]
		line.add_theme_font_size_override("font_size", 10)
		line.add_theme_color_override("font_color",
			Color(0.45, 0.92, 0.60) if ok else Color(0.98, 0.45, 0.38))
		_rows_box.add_child(line)
