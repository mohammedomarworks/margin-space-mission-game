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
			draw_string_outline(font, center + Vector2(-top_sz.x * 0.5, -radius * 0.22), str_top, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, 2, Color(0.005, 0.01, 0.025, 0.98))
			draw_string(font, center + Vector2(-top_sz.x * 0.5, -radius * 0.22), str_top, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.35, 0.85, 1.0))

			var str_bot = label_bottom
			var bot_sz = font.get_string_size(str_bot, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			draw_string_outline(font, center + Vector2(-bot_sz.x * 0.5, radius * 0.58), str_bot, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, 2, Color(0.005, 0.01, 0.025, 0.98))
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
# 7. LIVE MARGIN BARS (Mass, Power, ΔV, Thermal, Budget)
# ------------------------------------------------------------------------------
class ReadinessBars extends Control:
	var labels: Array = ["MASS", "POWER", "ΔV", "THERMAL", "BUDGET"]
	var values: Array = [0.90, 0.90, 0.90, 0.90, 0.90]:
		set(value):
			values = value
			queue_redraw()

	func _draw() -> void:
		var font = ThemeDB.fallback_font
		var row_h = size.y / 5.0
		var bar_h = 5.0

		for i in range(min(values.size(), labels.size())):
			var y_center = (i + 0.5) * row_h
			var val = clamp(float(values[i]), 0.0, 1.0)
			var col = Color(0.96, 0.28, 0.25) if val < 0.4 else (Color(1.0, 0.68, 0.18) if val < 0.7 else Color(0.25, 0.9, 0.58))
			if font:
				draw_string_outline(font, Vector2(0.0, y_center + 3.0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, 48.0, 8, 2, Color(0.005, 0.01, 0.025, 0.98))
				draw_string(font, Vector2(0.0, y_center + 3.0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, 48.0, 8, Color(0.84, 0.89, 0.95))

			# Progress Bar Track & Fill
			var bar_x = 54.0
			var bar_w = size.x - bar_x - 34.0
			var track_rect = Rect2(bar_x, y_center - bar_h * 0.5, bar_w, bar_h)
			draw_rect(track_rect, Color(0.12, 0.16, 0.22, 0.8), true)

			var fill_rect = Rect2(bar_x, y_center - bar_h * 0.5, bar_w * val, bar_h)
			draw_rect(fill_rect, col, true)

			# Diagonal striped overlay on progress bar fill
			# Percentage label and shadow keep all five gauges readable on the hangar view.
			if font:
				var pct_str = "%d%%" % int(val * 100)
				draw_string_outline(font, Vector2(size.x - 29.0, y_center + 3.0), pct_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.005, 0.01, 0.025, 0.98))
				draw_string(font, Vector2(size.x - 29.0, y_center + 3.0), pct_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.9, 0.95))

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

# ------------------------------------------------------------------------------
# 9. NAVBALL / ATTITUDE DIRECTOR SPHERE (Matching Reference 02)
# ------------------------------------------------------------------------------
class NavBall extends Control:
	var pitch_deg: float = 90.0 # 90 = vertical ascent, 0 = horizontal
	var roll_deg: float = 0.0
	var heading_deg: float = 90.0
	var flight_vector: Vector2 = Vector2.ZERO # Steering vector

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var center = size * 0.5
		var radius = min(center.x, center.y) - 6.0
		if radius <= 8.0:
			return

		# Dark outer bezel casing
		draw_circle(center, radius + 3.0, Color(0.04, 0.06, 0.10, 0.95))
		draw_arc(center, radius + 1.5, 0.0, TAU, 48, Color(0.25, 0.45, 0.65, 0.8), 2.0, true)

		# Ground hemisphere (Amber/Brown)
		draw_circle(center, radius, Color(0.68, 0.38, 0.12, 0.95))

		# Sky hemisphere (Cyan/Azure)
		# Calculate horizon line offset based on pitch:
		# Pitch 0 = horizon at center. Pitch 90 = all sky. Pitch -90 = all ground.
		var norm_pitch = clamp(pitch_deg / 90.0, -1.0, 1.0)
		var h_offset = norm_pitch * radius # positive moves horizon down

		# Draw sky hemisphere polygon
		var sky_pts = PackedVector2Array()
		var steps = 32
		# Semi-circle for sky
		for i in range(steps + 1):
			var a = -PI + (float(i) / steps) * PI
			sky_pts.append(center + Vector2(cos(a) * radius, sin(a) * radius))
		# Bottom edge along the horizon line
		sky_pts.append(center + Vector2(radius, radius - h_offset * 2.0))
		sky_pts.append(center + Vector2(-radius, radius - h_offset * 2.0))
		
		# Fill sky hemisphere
		if norm_pitch > 0.05:
			# Sky covers upper portion down to horizon
			var horizon_y = center.y + (1.0 - norm_pitch) * radius * 0.85
			var sky_rect = Rect2(center.x - radius, center.y - radius, radius * 2.0, horizon_y - (center.y - radius))
			# Draw circle masked sky
			var sky_poly = PackedVector2Array()
			for i in range(48):
				var a = (float(i) / 47.0) * TAU
				var pt = center + Vector2(cos(a), sin(a)) * radius
				if pt.y <= horizon_y:
					sky_poly.append(pt)
			if sky_poly.size() >= 3:
				draw_colored_polygon(sky_poly, Color(0.18, 0.62, 0.82, 0.95))

			# White Horizon Line
			var h_half_w = sqrt(max(0.0, radius * radius - pow(horizon_y - center.y, 2.0)))
			draw_line(Vector2(center.x - h_half_w, horizon_y), Vector2(center.x + h_half_w, horizon_y), Color(1.0, 1.0, 1.0, 0.95), 2.5, true)

		# Pitch Ladder Lines
		var font = ThemeDB.fallback_font
		for p in [30, 60, 80]:
			var py_offset = center.y - (p / 90.0) * radius * 0.75 + (1.0 - norm_pitch) * 15.0
			if abs(py_offset - center.y) < radius - 8.0:
				var line_w = 14.0 if p != 80 else 22.0
				draw_line(Vector2(center.x - line_w, py_offset), Vector2(center.x + line_w, py_offset), Color(1.0, 1.0, 1.0, 0.75), 1.5, true)
				if font and p != 80:
					draw_string_outline(font, Vector2(center.x + line_w + 2.0, py_offset + 3.0), str(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.005, 0.01, 0.025, 0.98))
					draw_string(font, Vector2(center.x + line_w + 2.0, py_offset + 3.0), str(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 1.0, 1.0, 0.8))

		# Center Flight Reticle (Yellow Aircraft symbol -- • --)
		var reticle_col = Color(0.98, 0.85, 0.15, 0.95)
		draw_line(Vector2(center.x - 14.0, center.y), Vector2(center.x - 4.0, center.y), reticle_col, 2.2, true)
		draw_line(Vector2(center.x + 4.0, center.y), Vector2(center.x + 14.0, center.y), reticle_col, 2.2, true)
		draw_line(Vector2(center.x, center.y - 2.0), Vector2(center.x, center.y + 6.0), reticle_col, 2.0, true)
		draw_circle(center, 2.5, reticle_col)

		# Outer Bezel Roll Ticks & Cardinal Marks
		for i in range(12):
			var a = (float(i) / 12.0) * TAU
			var p1 = center + Vector2(cos(a), sin(a)) * (radius + 1.0)
			var p2 = center + Vector2(cos(a), sin(a)) * (radius - 2.0)
			draw_line(p1, p2, Color(0.4, 0.75, 0.95, 0.8), 1.2, true)

		# Top Roll Indicator Arrow
		var top_arrow = PackedVector2Array([
			center + Vector2(0.0, -radius - 3.0),
			center + Vector2(-3.5, -radius + 2.5),
			center + Vector2(3.5, -radius + 2.5)
		])
		draw_colored_polygon(top_arrow, Color(0.98, 0.85, 0.15))

# ------------------------------------------------------------------------------
# 10. DYNAMIC MAX-Q WARNING ARC WIDGET (Matching Reference 02)
# ------------------------------------------------------------------------------
class MaxQArcWidget extends Control:
	var dynamic_pressure_kpa: float = 0.0 # 0.0 to 45.0 kPa
	var max_limit_kpa: float = 35.0
	var is_warning: bool = false
	var pulse_time: float = 0.0

	func _process(delta: float) -> void:
		pulse_time += delta * 6.0
		is_warning = dynamic_pressure_kpa >= 27.5
		queue_redraw()

	func _draw() -> void:
		var center = Vector2(size.x * 0.45, size.y * 0.75)
		var radius = min(size.x, size.y) * 0.65
		if radius <= 10.0:
			return

		# Start angle ~ -125 deg, sweep ~ 90 deg (forming curved arc to upper-right)
		var start_rad = -PI * 0.70
		var sweep_rad = PI * 0.55
		var norm_q = clamp(dynamic_pressure_kpa / 40.0, 0.0, 1.0)

		# Background Track Arc
		draw_arc(center, radius, start_rad, start_rad + sweep_rad, 32, Color(0.15, 0.22, 0.30, 0.5), 6.0, true)

		# Dynamic Active Pressure Arc (Amber to Red gradient)
		var active_sweep = sweep_rad * norm_q
		var arc_col = Color(0.98, 0.65, 0.15, 0.95)
		if is_warning:
			var flash = sin(pulse_time) * 0.5 + 0.5
			arc_col = lerp(Color(0.98, 0.55, 0.12), Color(1.0, 0.20, 0.15), flash)

		if active_sweep > 0.02:
			draw_arc(center, radius, start_rad, start_rad + active_sweep, 24, arc_col, 6.0, true)

		# Segmented outer tick marks
		for i in range(11):
			var a = start_rad + (float(i) / 10.0) * sweep_rad
			var p1 = center + Vector2(cos(a), sin(a)) * (radius + 5.0)
			var p2 = center + Vector2(cos(a), sin(a)) * (radius + 9.0)
			var tick_col = Color(0.95, 0.65, 0.15, 0.8) if i >= 7 else Color(0.4, 0.6, 0.8, 0.6)
			draw_line(p1, p2, tick_col, 1.5, true)

		# Pointer needle at current dynamic pressure
		var needle_a = start_rad + active_sweep
		var tip = center + Vector2(cos(needle_a), sin(needle_a)) * (radius + 4.0)
		var base1 = center + Vector2(cos(needle_a - 0.08), sin(needle_a - 0.08)) * (radius - 5.0)
		var base2 = center + Vector2(cos(needle_a + 0.08), sin(needle_a + 0.08)) * (radius - 5.0)
		draw_colored_polygon(PackedVector2Array([tip, base1, base2]), Color(1.0, 0.95, 0.4))

		# Triangular Warning Badge [▲ !] at top-right
		var warn_pos = center + Vector2(cos(start_rad + sweep_rad * 0.85), sin(start_rad + sweep_rad * 0.85)) * (radius + 16.0)
		var tri_pts = PackedVector2Array([
			warn_pos + Vector2(0.0, -9.0),
			warn_pos + Vector2(-8.0, 6.0),
			warn_pos + Vector2(8.0, 6.0)
		])
		draw_colored_polygon(tri_pts, Color(0.98, 0.60, 0.10, 0.95))
		draw_polyline(tri_pts, Color(1.0, 0.9, 0.4), 1.2, true)
		# Exclamation mark inside warning badge
		draw_line(warn_pos + Vector2(0.0, -4.0), warn_pos + Vector2(0.0, 1.0), Color(0.05, 0.05, 0.08), 1.8, true)
		draw_circle(warn_pos + Vector2(0.0, 3.5), 1.0, Color(0.05, 0.05, 0.08))

		# Stylized [Q] Magnifier Badge with callout arrow pointing to rocket nose
		var q_badge_pos = center + Vector2(cos(start_rad + active_sweep), sin(start_rad + active_sweep)) * (radius - 16.0)
		draw_circle(q_badge_pos, 9.0, Color(0.08, 0.12, 0.18, 0.95))
		draw_arc(q_badge_pos, 9.0, 0.0, TAU, 24, arc_col, 2.0, true)

		var font = ThemeDB.fallback_font
		if font:
			draw_string_outline(font, q_badge_pos + Vector2(-4.0, 4.0), "Q", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, 2, Color(0.005, 0.01, 0.025, 0.98))
			draw_string(font, q_badge_pos + Vector2(-4.0, 4.0), "Q", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.98, 0.85, 0.3))

		# Callout arrow pointing towards bottom-left (rocket direction)
		var arrow_tip = q_badge_pos + Vector2(-12.0, 8.0)
		draw_line(q_badge_pos, arrow_tip, arc_col, 1.5, true)
		draw_circle(arrow_tip, 2.0, arc_col)

# ------------------------------------------------------------------------------
# 11. VERTICAL ALTITUDE TAPE WIDGET (Matching Reference 02)
# ------------------------------------------------------------------------------
class AltitudeTape extends Control:
	var altitude_km: float = 0.0 # Current altitude in km
	var max_display_km: float = 185.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		if h <= 20.0:
			return

		# Dark translucent background strip
		draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.07, 0.11, 0.85), true)
		draw_rect(Rect2(0, 0, w, h), Color(0.25, 0.40, 0.60, 0.7), false, 1.0)

		# Vertical ruler line
		var ruler_x = w * 0.40
		draw_line(Vector2(ruler_x, 10.0), Vector2(ruler_x, h - 10.0), Color(0.35, 0.55, 0.75, 0.6), 1.5, true)

		# Moving altitude scale:
		# Display +/- 15 km around the current altitude
		var visible_window_km = 30.0
		var km_start = floor((altitude_km - visible_window_km * 0.5) / 5.0) * 5.0
		var km_end = km_start + visible_window_km + 10.0

		var font = ThemeDB.fallback_font
		for k in range(int(km_start), int(km_end), 5):
			if k < 0:
				continue
			var frac = (float(k) - (altitude_km - visible_window_km * 0.5)) / visible_window_km
			var y_pos = h - (frac * h)
			if y_pos >= 8.0 and y_pos <= h - 8.0:
				var is_major = (k % 10 == 0)
				var tick_len = 10.0 if is_major else 5.0
				draw_line(Vector2(ruler_x, y_pos), Vector2(ruler_x + tick_len, y_pos), Color(0.7, 0.85, 1.0, 0.8 if is_major else 0.4), 1.2, true)
				if is_major and font:
					var txt = "%.0f" % k
					draw_string_outline(font, Vector2(4.0, y_pos + 3.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 2, Color(0.005, 0.01, 0.025, 0.98))
					draw_string(font, Vector2(4.0, y_pos + 3.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.65, 0.75, 0.90, 0.8))

		# Active Pointer Box in Center
		var center_y = h * 0.5
		var box_rect = Rect2(ruler_x - 2.0, center_y - 12.0, w - ruler_x + 1.0, 24.0)
		draw_rect(box_rect, Color(0.12, 0.50, 0.85, 0.95), true)
		draw_rect(box_rect, Color(0.40, 0.85, 1.0, 1.0), false, 1.5)

		# Left triangle pointer
		var arrow_pts = PackedVector2Array([
			Vector2(ruler_x - 6.0, center_y),
			Vector2(ruler_x - 1.0, center_y - 6.0),
			Vector2(ruler_x - 1.0, center_y + 6.0)
		])
		draw_colored_polygon(arrow_pts, Color(0.40, 0.85, 1.0))

		if font:
			var alt_txt = "%.1f" % altitude_km
			draw_string_outline(font, Vector2(ruler_x + 4.0, center_y + 4.0), alt_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 2, Color(0.005, 0.01, 0.025, 0.98))
			draw_string(font, Vector2(ruler_x + 4.0, center_y + 4.0), alt_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 1.0, 1.0))
			draw_string_outline(font, Vector2(ruler_x + 4.0, center_y + 11.0), "km", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.005, 0.01, 0.025, 0.98))
			draw_string(font, Vector2(ruler_x + 4.0, center_y + 11.0), "km", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.95, 1.0))

# ------------------------------------------------------------------------------
# 12. VERTICAL THROTTLE GAUGE (Matching Reference 02)
# ------------------------------------------------------------------------------
class VerticalThrottleGauge extends Control:
	var throttle: float = 1.0 # 0.0 to 1.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		if h <= 20.0:
			return

		# Dark container frame
		draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.07, 0.11, 0.85), true)
		draw_rect(Rect2(0, 0, w, h), Color(0.25, 0.40, 0.60, 0.7), false, 1.0)

		# Header %
		var font = ThemeDB.fallback_font
		if font:
			draw_string_outline(font, Vector2(w * 0.5 - 4.0, 14.0), "%", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, 2, Color(0.005, 0.01, 0.025, 0.98))
			draw_string(font, Vector2(w * 0.5 - 4.0, 14.0), "%", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.7, 0.85, 1.0))

		# Progress bar area
		var bar_y = 20.0
		var bar_h = h - 38.0
		var bar_w = w * 0.45
		var bar_x = (w - bar_w) * 0.5

		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.10, 0.15, 0.22, 0.9), true)

		# Striped segments fill
		var num_segs = 16
		var filled_segs = int(round(throttle * num_segs))
		var seg_h = bar_h / float(num_segs)

		for i in range(num_segs):
			var sy = bar_y + bar_h - (i + 1) * seg_h + 1.0
			var is_filled = (i < filled_segs)
			var col = Color(0.18, 0.22, 0.28, 0.5)
			if is_filled:
				col = Color(0.98, 0.65, 0.15) if i >= 12 else Color(0.25, 0.85, 0.95)
			draw_rect(Rect2(bar_x + 1.0, sy, bar_w - 2.0, seg_h - 1.5), col, true)

		# Bottom Rocket Icon
		var bot_c = Vector2(w * 0.5, h - 9.0)
		var r_pts = PackedVector2Array([
			bot_c + Vector2(0, -6),
			bot_c + Vector2(3, 2),
			bot_c + Vector2(4, 5),
			bot_c + Vector2(1, 4),
			bot_c + Vector2(-1, 4),
			bot_c + Vector2(-4, 5),
			bot_c + Vector2(-3, 2)
		])
		draw_polyline(r_pts, Color(0.98, 0.70, 0.20), 1.0, true)

# ------------------------------------------------------------------------------
# 13. STAGING SELECTION COLUMN (Matching Reference 02)
# ------------------------------------------------------------------------------
class StagingColumn extends Control:
	var active_stage: int = 1 # 1 = Boosters, 2 = Core/Vacuum, 3 = Fairing/Probe

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		if h <= 20.0:
			return

		var font = ThemeDB.fallback_font
		var box_h = (h - 16.0) / 3.0

		# 3 Staging tiers
		# Tier 3 (Top): Upper Stage & Fairing
		_draw_stage_box(Rect2(4, 4, w - 8, box_h - 4), 3, active_stage == 3, "UPPER")
		# Tier 2 (Middle): Stage 1 Booster Core
		_draw_stage_box(Rect2(4, 4 + box_h, w - 8, box_h - 4), 2, active_stage <= 2, "BOOSTER")
		# Tier 1 (Bottom): Engines
		_draw_stage_box(Rect2(4, 4 + box_h * 2, w - 8, box_h - 4), 1, active_stage == 1, "ENGINES")

	func _draw_stage_box(rect: Rect2, stage_num: int, is_active: bool, label_str: String) -> void:
		var bg_col = Color(0.18, 0.14, 0.06, 0.9) if is_active else Color(0.06, 0.09, 0.13, 0.85)
		var border_col = Color(0.98, 0.75, 0.15, 0.95) if is_active else Color(0.25, 0.35, 0.50, 0.6)
		draw_rect(rect, bg_col, true)
		draw_rect(rect, border_col, false, 1.5 if is_active else 1.0)

		# Stylized Icon inside
		var c = rect.get_center()
		match stage_num:
			3:
				# Nose cone outline
				draw_polyline(PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 4), c + Vector2(-5, 4), c + Vector2(0, -6)]), border_col, 1.2, true)
			2:
				# Quad rocket booster outline
				draw_rect(Rect2(c.x - 6, c.y - 7, 12, 14), border_col, false, 1.2)
				draw_line(Vector2(c.x, c.y - 7), Vector2(c.x, c.y + 7), border_col, 1.0, true)
			1:
				# Engine bells
				draw_polyline(PackedVector2Array([c + Vector2(-5, 5), c + Vector2(-2, -3), c + Vector2(2, -3), c + Vector2(5, 5)]), border_col, 1.2, true)

# ------------------------------------------------------------------------------
# 14. ATTITUDE VECTOR / GYRO SCOPE (Bottom Right, Matching Reference 02)
# ------------------------------------------------------------------------------
class AttitudeScope extends Control:
	var pitch_deg: float = 48.0
	var heading_deg: float = 90.0
	var flight_path_angle: float = 45.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var center = size * 0.5
		var radius = min(center.x, center.y) - 6.0
		if radius <= 8.0:
			return

		# Dark scope circle
		draw_circle(center, radius + 2.0, Color(0.04, 0.08, 0.12, 0.85))
		draw_arc(center, radius, 0.0, TAU, 36, Color(0.18, 0.45, 0.65, 0.7), 1.5, true)

		# Reticle crosshairs
		var cross_col = Color(0.25, 0.65, 0.85, 0.6)
		draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), cross_col, 1.0, true)
		draw_line(center - Vector2(0, radius), center + Vector2(0, radius), cross_col, 1.0, true)

		# Inner range circle
		draw_arc(center, radius * 0.5, 0.0, TAU, 24, Color(0.18, 0.45, 0.65, 0.4), 1.0, true)

		# Sweeping attitude target arc
		var sweep_rad = PI * 0.35
		var a_start = -PI * 0.2
		draw_arc(center, radius * 0.85, a_start, a_start + sweep_rad, 16, Color(0.25, 0.85, 0.75, 0.7), 2.0, true)

		# Flight path vector indicator (Cyan arrow / marker)
		var f_offset = Vector2(cos(deg_to_rad(heading_deg - 90.0)), -sin(deg_to_rad(pitch_deg))) * (radius * 0.45)
		var bug_pos = center + f_offset
		draw_circle(bug_pos, 3.5, Color(0.35, 0.95, 1.0, 0.95))
		draw_line(bug_pos - Vector2(8, 0), bug_pos + Vector2(8, 0), Color(0.35, 0.95, 1.0, 0.9), 1.5, true)
		draw_line(bug_pos - Vector2(0, 8), bug_pos + Vector2(0, 8), Color(0.35, 0.95, 1.0, 0.9), 1.5, true)
