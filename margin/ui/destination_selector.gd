class_name DestinationSelector
extends PanelContainer

# ==============================================================================
# MARGIN — 3-DESTINATION MISSION SELECTOR
# Arcade-style target picker with three planet preview cards. Each card shows a
# live 3D-ish planet disc, difficulty stars, delta-V, hazards and the NASA
# requirement list for that target. Selecting a card commits the destination to
# Helios4CampaignData and emits destination_selected.
# ==============================================================================

signal destination_selected(dest_id: String)

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")

var selected_id: String = "sun_earth_l1"
var _cards: Dictionary = {}
var _detail_labels: Dictionary = {}
var _confirm_btn: Button = null


class PlanetDisc:
	extends Control

	var body_color: Color = Color(0.4, 0.6, 1.0)
	var accent: Color = Color(0.6, 0.8, 1.0)
	var _t: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(96, 96)
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.40

		# Outer glow
		for i in range(6, 0, -1):
			var gr: float = r + i * 3.0
			var a: float = 0.05 * (7 - i) / 6.0
			draw_circle(c, gr, Color(accent.r, accent.g, accent.b, a))

		# Planet body with a simple terminator shading
		draw_circle(c, r, body_color)
		var shade := PackedVector2Array()
		var steps: int = 28
		for i in steps + 1:
			var ang: float = PI * 0.5 + PI * float(i) / float(steps)
			shade.append(c + Vector2(cos(ang), sin(ang)) * r)
		draw_colored_polygon(shade, Color(0, 0, 0, 0.28))

		# Rotating surface bands for a sense of motion
		for b in 3:
			var off: float = fmod(_t * 0.35 + b * 0.33, 1.0)
			var y: float = c.y - r + off * 2.0 * r
			var half: float = sqrt(maxf(r * r - pow(y - c.y, 2), 0.0))
			if half > 1.0:
				draw_line(Vector2(c.x - half, y), Vector2(c.x + half, y),
					Color(accent.r, accent.g, accent.b, 0.16), 2.0)

		# Rim light
		draw_arc(c, r, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.85), 2.0, true)


func _ready() -> void:
	theme = MarginTheme.get_theme()
	_build()


func _build() -> void:
	custom_minimum_size = Vector2(0, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := Label.new()
	header.text = "SELECT MISSION DESTINATION"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(header)

	var sub := Label.new()
	sub.text = "Your target decides the engineering requirements. Choose before you build."
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.62, 0.72, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	for meta in DestinationData.get_all():
		var card := _make_card(meta)
		row.add_child(card)
		_cards[meta["id"]] = card

	_confirm_btn = Button.new()
	_confirm_btn.name = "ConfirmDestinationBtn"
	_confirm_btn.text = "CONFIRM TARGET →"
	_confirm_btn.custom_minimum_size = Vector2(0, 44)
	_confirm_btn.add_theme_font_size_override("font_size", 16)
	_confirm_btn.pressed.connect(_on_confirm)
	root.add_child(_confirm_btn)

	_refresh_selection()


func _make_card(meta: Dictionary) -> PanelContainer:
	var dest_id: String = meta["id"]
	var card := PanelContainer.new()
	card.name = "DestCard_" + dest_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var disc := PlanetDisc.new()
	disc.body_color = meta["body_color"]
	disc.accent = meta["accent"]
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(disc)

	var name_lbl := Label.new()
	name_lbl.text = meta["name"]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", meta["accent"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name_lbl)

	var code_lbl := Label.new()
	code_lbl.text = meta["code"] + " • " + meta["subtitle"]
	code_lbl.add_theme_font_size_override("font_size", 10)
	code_lbl.add_theme_color_override("font_color", Color(0.60, 0.70, 0.82))
	code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(code_lbl)

	var stars := Label.new()
	stars.text = "★".repeat(int(meta["difficulty_stars"])) + "☆".repeat(3 - int(meta["difficulty_stars"]))
	stars.add_theme_font_size_override("font_size", 13)
	stars.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(stars)

	var stats := Label.new()
	stats.text = "Δv %s\n%s • %s" % [meta["delta_v_label"], meta["distance_label"], meta["flight_time_label"]]
	stats.add_theme_font_size_override("font_size", 10)
	stats.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(stats)

	var needs := Label.new()
	var need_lines: Array = []
	for n in meta["needs"]:
		need_lines.append("• " + str(n))
	needs.text = "\n".join(need_lines)
	needs.add_theme_font_size_override("font_size", 10)
	needs.add_theme_color_override("font_color", Color(0.66, 0.76, 0.86))
	needs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(needs)

	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_select(dest_id)
	)
	return card


func _select(dest_id: String) -> void:
	if selected_id == dest_id:
		return
	selected_id = dest_id
	Sfx.ui_click()
	_refresh_selection()


func _refresh_selection() -> void:
	for dest_id in _cards:
		var card: PanelContainer = _cards[dest_id]
		var meta: Dictionary = DestinationData.get_metadata(dest_id)
		var is_sel: bool = (dest_id == selected_id)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.14, 0.22, 0.95) if is_sel else Color(0.06, 0.09, 0.14, 0.85)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2 if is_sel else 1)
		sb.border_color = meta["accent"] if is_sel else Color(0.20, 0.28, 0.38)
		sb.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", sb)

	if _confirm_btn:
		var m: Dictionary = DestinationData.get_metadata(selected_id)
		_confirm_btn.text = "CONFIRM TARGET: %s →" % m["name"]


func _on_confirm() -> void:
	Helios4CampaignData.set_destination(selected_id)
	Sfx.success_chime()
	destination_selected.emit(selected_id)
