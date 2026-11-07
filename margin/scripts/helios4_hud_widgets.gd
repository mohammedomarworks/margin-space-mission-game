class_name Helios4HUDWidgets
extends RefCounted

# ==============================================================================
# MARGIN: HELIOS-4 PROCEDURAL VECTOR HUD WIDGETS
# Custom Control-derived visual components for high-tech aerospace telemetry:
# Strictly vector-drawn with _draw() - NO emoji strings or font fallbacks!
#
# Components:
# 1. DialGauge - Circular vector dial with needle, arc, delta symbol, tick marks
# 2. RadarScope - Rotating green phosphor radar sweep with range rings & blips
# 3. SparklineWave - Animated live fluctuating telemetry waveform
# 4. ComponentIcon - 2D blueprint glyphs (engine, tank, truss, solar, dish, boom)
# 5. SpecialistIcon - Crisp vector icons for Wrench, Radar, Planetary, Electrical
# 6. StatusPips - Small glowing rectangular status indicators
# 7. ReadinessBars - 3 horizontal striped progress bars with checkmarks & percentages
# 8. ToolStripIcon - Vertical toolbar icons (sliders, tools, cube, rocket, target)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. RADIAL DIAL GAUGE
# ------------------------------------------------------------------------------
class DialGauge extends Control:
	var value: float = 0.72 # 0.0 to 1.0
	var label_top: String = "Δ"
	var label_bottom: String = "11,399 m/s"
	var arc_color: Color = Color(0.2, 0.85, 1.0, 0.9)
	var bg_color: Color = Color(0.06, 0.09, 0.14, 0.85)
	var track_color: Color = Color(0.15, 0.25, 0.35, 0.5)

	func _process(delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var center = size * 0.5
		var radius = min(center.x, center.y) - 6.0
		if radius <= 4.0:
			return

		# Dark outer bezel & background circle
		draw_circle(center, radius + 2.0, bg_color)
		draw_arc(center, radius, 0.0, TAU, 48, track_color, 2.5, true)

		# Outer tick marks
		var num_ticks = 16
		for i in range(num_ticks):
			var a = -PI * 0.75 + (i / float(num_ticks - 1)) * PI * 1.5
			var p1 = center + Vector2(cos(a), sin(a)) * (radius - 1.0)
			var p2 = center + Vector2(cos(a), sin(a)) * (radius - 5.0)
			draw_line(p1, p2, Color(0.3, 0.5, 0.7, 0.6), 1.5, true)

		# Progress Arc
		var start_angle = -PI * 0.75
		var sweep_angle = PI * 1.5 * clamp(value, 0.0, 1.0)
		if sweep_angle > 0.01:
			draw_arc(center, radius - 2.0, start_angle, start_angle + sweep_angle, 36, arc_color, 4.0, true)

		# Center Pivot & Needle
		var needle_angle = start_angle + sweep_angle
		var needle_tip = center + Vector2(cos(needle_angle), sin(needle_angle)) * (radius - 7.0)
		draw_line(center, needle_tip, Color(1.0, 0.9, 0.4, 0.95), 2.0, true)
		draw_circle(center, 4.0, Color(0.9, 0.95, 1.0, 0.9))

		# Center delta / text symbol
		var font = ThemeDB.fallback_font
		if font:
			var str_top = label_top
			var top_sz = font.get_string_size(str_top, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
			draw_string(font, center + Vector2(-top_sz.x * 0.5, -radius * 0.22), str_top, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.35, 0.85, 1.0))

			var str_bot = label_bottom
			var bot_sz = font.get_string_size(str_bot, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			draw_string(font, center + Vector2(-bot_sz.x * 0.5, radius * 0.58), str_bot, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.9, 0.92, 0.96))

# ------------------------------------------------------------------------------
# 2. RADAR SCOPE WIDGET
# ------------------------------------------------------------------------------
class RadarScope extends Control:
	var sweep_angle: float = 0.0
	var sweep_speed: float = 2.5
	var blips: Array = [
		Vector2(0.3, -0.4),
		Vector2(-0.5, 0.2),
		Vector2(0.2, 0.6)
	]

	func _process(delta: float) -> void:
		sweep_angle = fmod(sweep_angle + sweep_speed * delta, TAU)
		queue_redraw()

	func _draw() -> void:
		var center = size * 0.5
		var radius = min(center.x, center.y) - 4.0
		if radius <= 4.0:
			return

		# Dark green-tinted scope background
		draw_circle(center, radius, Color(0.03, 0.08, 0.05, 0.85))

		# Concentric Range Rings
		for r_pct in [0.33, 0.66, 1.0]:
			draw_arc(center, radius * r_pct, 0.0, TAU, 32, Color(0.15, 0.5, 0.25, 0.5), 1.2, true)

		# Crosshairs
		draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.15, 0.45, 0.25, 0.4), 1.0, true)
		draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.15, 0.45, 0.25, 0.4), 1.0, true)

		# Rotating Sweep Line
		var sweep_dir = Vector2(cos(sweep_angle), sin(sweep_angle))
		var sweep_tip = center + sweep_dir * radius
		draw_line(center, sweep_tip, Color(0.3, 0.95, 0.5, 0.9), 2.0, true)

		# Sweep Trail / Wedge
		for trail in range(1, 10):
			var a = sweep_angle - trail * 0.06
			var p = center + Vector2(cos(a), sin(a)) * radius
			var alpha = (1.0 - trail / 10.0) * 0.25
			draw_line(center, p, Color(0.25, 0.9, 0.45, alpha), 2.0, true)

		# Radar Blips
		for b in blips:
			var b_pos = center + b * radius
			draw_circle(b_pos, 2.5, Color(0.4, 1.0, 0.6, 0.85))

# ------------------------------------------------------------------------------
# 3. TELEMETRY SPARKLINE WAVEFORM
# ------------------------------------------------------------------------------
class SparklineWave extends Control:
	var color: Color = Color(0.25, 0.85, 1.0, 0.85)
	var wave_phase: float = 0.0
	var frequency: float = 2.0
	var amplitude: float = 0.6

	func _process(delta: float) -> void:
		wave_phase = fmod(wave_phase + delta * 2.8, TAU)
		queue_redraw()

	func _draw() -> void:
		if size.x < 10.0 or size.y < 10.0:
			return

		var points: PackedVector2Array = []
		var base_y = size.y * 0.5
		var segments = 24
		for i in range(segments + 1):
			var t = i / float(segments)
			var x = t * size.x
			var y = base_y + sin(t * TAU * frequency + wave_phase) * (size.y * 0.35 * amplitude) + cos(t * PI * 3.0 - wave_phase * 0.5) * (size.y * 0.1)
			points.append(Vector2(x, y))

		if points.size() >= 2:
			draw_polyline(points, color, 1.8, true)

# ------------------------------------------------------------------------------
# 4. COMPONENT BLUEPRINT ICON
# ------------------------------------------------------------------------------
class ComponentIcon extends Control:
	var icon_type: String = "engine" # engine, cluster, tank, truss, solar, dish, boom, avionics, fins
	var is_selected: bool = false
	var icon_color: Color = Color(0.7, 0.85, 0.98)

	func _draw() -> void:
		var c = size * 0.5
		var col = Color(1.0, 0.75, 0.2) if is_selected else icon_color
		var dim_col = col * Color(1, 1, 1, 0.35)

		match icon_type:
			"cluster", "engine":
				# Quad rocket bell nozzles & chamber
				for off in [Vector2(-5, -4), Vector2(5, -4), Vector2(-5, 5), Vector2(5, 5)]:
					draw_circle(c + off, 3.5, dim_col)
					draw_arc(c + off, 3.5, 0.0, TAU, 14, col, 1.2, true)
				draw_line(c + Vector2(-6, -8), c + Vector2(6, -8), col, 1.5)

			"tank":
				# Cylindrical tank with rounded caps & ribs
				var rect = Rect2(c.x - 7, c.y - 11, 14, 22)
				draw_rect(rect, dim_col, true)
				draw_rect(rect, col, false, 1.5)
				draw_line(c + Vector2(-7, -4), c + Vector2(7, -4), col, 1.0)
				draw_line(c + Vector2(-7, 4), c + Vector2(7, 4), col, 1.0)

			"truss":
				# Lattice square truss box with X cross-braces
				var rect = Rect2(c.x - 9, c.y - 9, 18, 18)
				draw_rect(rect, dim_col, true)
				draw_rect(rect, col, false, 1.5)
				draw_line(rect.position, rect.position + rect.size, col, 1.2)
				draw_line(Vector2(rect.position.x + rect.size.x, rect.position.y), Vector2(rect.position.x, rect.position.y + rect.size.y), col, 1.2)

			"solar":
				# Dual deployable solar wing panels
				for sx in [-7, 7]:
					var r = Rect2(c.x + sx - 5, c.y - 9, 10, 18)
					draw_rect(r, dim_col, true)
					draw_rect(r, col, false, 1.5)
					draw_line(Vector2(r.position.x, c.y), Vector2(r.position.x + r.size.x, c.y), col, 1.0)
				draw_circle(c, 3.0, col)

			"dish":
				# Parabolic dish reflector + tripod feed
				draw_arc(c + Vector2(0, 3), 10.0, -PI * 0.8, -PI * 0.2, 16, col, 2.0, true)
				draw_line(c + Vector2(0, 3), c + Vector2(0, -6), col, 1.5)
				draw_circle(c + Vector2(0, -7), 2.5, Color(1.0, 0.8, 0.2))

			"boom":
				# Diagonal magnetometer boom & sensor
				draw_line(c + Vector2(-10, 10), c + Vector2(10, -10), col, 2.0)
				draw_circle(c + Vector2(10, -10), 3.5, Color(1.0, 0.8, 0.2))

			"fins":
				# Perforated grid fin mesh
				var rect = Rect2(c.x - 8, c.y - 8, 16, 16)
				draw_rect(rect, dim_col, true)
				draw_rect(rect, col, false, 1.5)
				for gx in [-3, 3]:
					draw_line(Vector2(c.x + gx, c.y - 8), Vector2(c.x + gx, c.y + 8), col, 1.0)
				for gy in [-3, 3]:
					draw_line(Vector2(c.x - 8, c.y + gy), Vector2(c.x + 8, c.y + gy), col, 1.0)

			_:
				# Gold bus cube / avionics
				var rect = Rect2(c.x - 8, c.y - 8, 16, 16)
				draw_rect(rect, Color(0.95, 0.75, 0.2, 0.4), true)
				draw_rect(rect, Color(1.0, 0.8, 0.25), false, 1.5)
				draw_circle(c, 3.0, Color(1.0, 0.9, 0.5))

# ------------------------------------------------------------------------------
# 5. SPECIALIST VECTOR ICON (Wrench, Radar, Planetary, Electrical)
# ------------------------------------------------------------------------------
class SpecialistIcon extends Control:
	var role_type: String = "wrench" # wrench, radar, planetary, electrical
	var icon_color: Color = Color(0.9, 0.92, 0.96)

	func _draw() -> void:
		var c = size * 0.5
		var col = icon_color
		var r = min(c.x, c.y) - 2.0

		match role_type:
			"wrench":
				# Two crossed wrenches
				var w_pts1 = [
					c + Vector2(-8, -8), c + Vector2(8, 8)
				]
				draw_line(w_pts1[0], w_pts1[1], col, 3.0, true)
				draw_circle(c + Vector2(-8, -8), 4.5, col)
				draw_circle(c + Vector2(-8, -8), 2.0, Color(0.08, 0.1, 0.14))

				var w_pts2 = [
					c + Vector2(8, -8), c + Vector2(-8, 8)
				]
				draw_line(w_pts2[0], w_pts2[1], col, 3.0, true)
				draw_circle(c + Vector2(8, -8), 4.5, col)
				draw_circle(c + Vector2(8, -8), 2.0, Color(0.08, 0.1, 0.14))

			"planetary":
				# Sphere with tilted ring
				draw_circle(c, 6.0, col)
				# Tilted elliptical ring
				var ring_pts: PackedVector2Array = []
				for i in range(25):
					var a = (i / 24.0) * TAU
					var rx = cos(a) * 12.0
					var ry = sin(a) * 4.5
					# Rotate 25 degrees
					var rot_x = rx * cos(deg_to_rad(-22.0)) - ry * sin(deg_to_rad(-22.0))
					var rot_y = rx * sin(deg_to_rad(-22.0)) + ry * cos(deg_to_rad(-22.0))
					ring_pts.append(c + Vector2(rot_x, rot_y))
				draw_polyline(ring_pts, col, 1.8, true)

			"electrical":
				# Outer circle + lightning bolt
				draw_arc(c, r - 1.0, 0.0, TAU, 32, col, 1.5, true)
				var bolt = PackedVector2Array([
					c + Vector2(1, -7),
					c + Vector2(-4, 0),
					c + Vector2(0, 0),
					c + Vector2(-2, 7),
					c + Vector2(5, -1),
					c + Vector2(1, -1),
					c + Vector2(3, -7)
				])
				draw_colored_polygon(bolt, col)

			_:
				# Default target crosshair
				draw_arc(c, 7.0, 0.0, TAU, 16, col, 1.5, true)
				draw_line(c - Vector2(10, 0), c + Vector2(10, 0), col, 1.2)
				draw_line(c - Vector2(0, 10), c + Vector2(0, 10), col, 1.2)

# ------------------------------------------------------------------------------
# 6. STATUS PIPS (Glowing Green/Blue Indicator Rectangles)
# ------------------------------------------------------------------------------
class StatusPips extends Control:
	var pip_count: int = 3
	var active_count: int = 3
	var pip_color: Color = Color(0.2, 0.9, 0.5)

	func _draw() -> void:
		var w = 8.0
		var h = 4.0
		var gap = 4.0
		for i in range(pip_count):
			var col = pip_color if i < active_count else Color(0.2, 0.3, 0.35, 0.5)
			var r = Rect2(i * (w + gap), (size.y - h) * 0.5, w, h)
			draw_rect(r, col, true)

# ------------------------------------------------------------------------------
# 7. READINESS PROGRESS BARS (3 Horizontal Bars matching Reference Center Card)
# ------------------------------------------------------------------------------
class ReadinessBars extends Control:
	var values: Array = [0.90, 0.90, 0.90] # 90%, 90%, 90%
	var colors: Array = [
		Color(0.25, 0.85, 1.0), # Cyan
		Color(0.25, 0.95, 0.5), # Green
		Color(0.2, 0.7, 0.95)   # Blue
	]

	func _draw() -> void:
		var font = ThemeDB.fallback_font
		var row_h = size.y / 3.0
		var bar_h = 7.0
		var chk_sz = 9.0

		for i in range(3):
			var y_center = (i + 0.5) * row_h
			var col = colors[i]
			var val = clamp(values[i], 0.0, 1.0)

			# Checkmark Box
			var chk_rect = Rect2(2.0, y_center - chk_sz * 0.5, chk_sz, chk_sz)
			draw_rect(chk_rect, Color(0.1, 0.2, 0.25, 0.8), true)
			draw_rect(chk_rect, col, false, 1.2)

			# Little checkmark inside box
			var p1 = chk_rect.position + Vector2(2.0, 4.5)
			var p2 = chk_rect.position + Vector2(4.0, 7.0)
			var p3 = chk_rect.position + Vector2(7.5, 2.5)
			draw_polyline(PackedVector2Array([p1, p2, p3]), col, 1.5, true)

			# Progress Bar Track & Fill
			var bar_x = 18.0
			var bar_w = size.x - bar_x - 38.0
			var track_rect = Rect2(bar_x, y_center - bar_h * 0.5, bar_w, bar_h)
			draw_rect(track_rect, Color(0.12, 0.16, 0.22, 0.8), true)

			var fill_rect = Rect2(bar_x, y_center - bar_h * 0.5, bar_w * val, bar_h)
			draw_rect(fill_rect, col, true)

			# Diagonal striped overlay on progress bar fill
			var num_stripes = int((bar_w * val) / 6.0)
			for s in range(num_stripes):
				var sx = bar_x + s * 6.0
				draw_line(Vector2(sx, y_center + bar_h * 0.5), Vector2(sx + 3.0, y_center - bar_h * 0.5), Color(1, 1, 1, 0.25), 1.0)

			# Percentage Text (e.g. "90%")
			if font:
				var pct_str = "%d%%" % int(val * 100)
				draw_string(font, Vector2(size.x - 32.0, y_center + 4.0), pct_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.9, 0.95))

# ------------------------------------------------------------------------------
# 8. LEFT VERTICAL TOOLBAR ICON (Sliders, Tools, Box, Rocket, Target, Eye, Layers)
# ------------------------------------------------------------------------------
class ToolStripIcon extends Control:
	var tool_type: String = "tools" # sliders, tools, box, rocket, target, eye, layers
	var is_active: bool = false

	func _draw() -> void:
		var c = size * 0.5
		var col = Color(0.25, 0.85, 1.0) if is_active else Color(0.5, 0.65, 0.75, 0.7)

		match tool_type:
			"sliders":
				# 2 Horizontal sliders with knobs
				for y_off in [-4, 4]:
					draw_line(c + Vector2(-6, y_off), c + Vector2(6, y_off), col, 1.2)
					var kx = -2 if y_off < 0 else 2
					draw_circle(c + Vector2(kx, y_off), 2.2, col)
			"tools":
				# Crossed wrench and screwdriver
				draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), col, 1.8, true)
				draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), col, 1.8, true)
			"box":
				# 3D isometric cube
				var rect = Rect2(c.x - 5, c.y - 5, 10, 10)
				draw_rect(rect, col, false, 1.2)
			"rocket":
				# Sleek rocket silhouette
				var pts = PackedVector2Array([
					c + Vector2(0, -7),
					c + Vector2(4, 2),
					c + Vector2(5, 7),
					c + Vector2(2, 5),
					c + Vector2(-2, 5),
					c + Vector2(-5, 7),
					c + Vector2(-4, 2)
				])
				draw_polyline(pts, col, 1.2, true)
			"target":
				# Reticle / target circle
				draw_arc(c, 5.5, 0.0, TAU, 16, col, 1.2, true)
				draw_circle(c, 1.5, col)
			"eye":
				# Eye outline
				draw_arc(c + Vector2(0, 4), 7.0, -PI * 0.7, -PI * 0.3, 12, col, 1.2, true)
				draw_arc(c - Vector2(0, 4), 7.0, PI * 0.3, PI * 0.7, 12, col, 1.2, true)
				draw_circle(c, 2.0, col)
			"layers":
				# Stacked parallel rhombuses / layers
				for y_off in [-3, 0, 3]:
					var pts = PackedVector2Array([
						c + Vector2(0, y_off - 2),
						c + Vector2(6, y_off),
						c + Vector2(0, y_off + 2),
						c + Vector2(-6, y_off),
						c + Vector2(0, y_off - 2)
					])
					draw_polyline(pts, col, 1.0, true)
			_:
				draw_circle(c, 3.0, col)
