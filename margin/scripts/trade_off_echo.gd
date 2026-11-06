class_name TradeOffEcho
extends RefCounted

static func analyze_tradeoff(cat: ComponentDatabase.Category, old_comp: Dictionary, new_comp: Dictionary) -> Dictionary:
	var cat_name: String = ComponentDatabase.get_category_name(cat)
	var new_name: String = new_comp.get("name", "Unknown")
	var old_name: String = old_comp.get("name", "None")
	
	var delta_mass: float = new_comp.get("mass_kg", 0.0) - old_comp.get("mass_kg", 0.0)
	var delta_cost: float = new_comp.get("cost_m", 0.0) - old_comp.get("cost_m", 0.0)
	var delta_science: float = new_comp.get("science_score", 0.0) - old_comp.get("science_score", 0.0)
	var delta_rel: float = new_comp.get("reliability_pct", 0.0) - old_comp.get("reliability_pct", 0.0)
	
	# Power analysis
	var old_p: float = old_comp.get("power_w", 0.0)
	var new_p: float = new_comp.get("power_w", 0.0)
	var delta_power: float = new_p - old_p
	
	# Data analysis
	var delta_data: float = new_comp.get("data_rate_gbit_day", 0.0) - old_comp.get("data_rate_gbit_day", 0.0)
	
	var positives: Array[String] = []
	var negatives: Array[String] = []
	
	# Mass effect
	if delta_mass < -0.1:
		positives.append("▲ Mass Savings: -%0.1f kg (Freed launch capacity)" % abs(delta_mass))
	elif delta_mass > 0.1:
		negatives.append("▼ Mass Penalty: +%0.1f kg (Eats launch vehicle margin)" % delta_mass)
	
	# Cost effect
	if delta_cost < -0.1:
		positives.append("▲ Budget Savings: -$%0.1fM (Increases reserve fund)" % abs(delta_cost))
	elif delta_cost > 0.1:
		negatives.append("▼ Budget Impact: +$%0.1fM (Narrows fiscal ceiling)" % delta_cost)
	
	# Power effect
	if cat == ComponentDatabase.Category.POWER_GENERATION:
		if delta_power > 1.0:
			positives.append("▲ Power Surplus: +%0.0f W (Energizes demanding payloads)" % delta_power)
		elif delta_power < -1.0:
			negatives.append("▼ Power Reduction: -%0.0f W (Less generation margin)" % abs(delta_power))
	else:
		if delta_power > 1.0:
			positives.append("▲ Efficiency: Draws %0.0f W less power" % delta_power)
		elif delta_power < -1.0:
			negatives.append("▼ Power Draw: Consumes +%0.0f W extra power" % abs(delta_power))
	
	# Science effect
	if delta_science > 0.5:
		positives.append("▲ Science Fidelity: +%0.0f pts (Deeper volatile characterization)" % delta_science)
	elif delta_science < -0.5:
		negatives.append("▼ Science Compromise: -%0.0f pts (Lower detection resolution)" % abs(delta_science))
	
	# Data effect
	if cat == ComponentDatabase.Category.INSTRUMENTS:
		if delta_data > 0.1:
			negatives.append("▼ Telemetry Load: +%0.1f Gbit/day (Requires robust downlink)" % delta_data)
		elif delta_data < -0.1:
			positives.append("▲ Data Lean: %0.1f Gbit/day less downlink demand" % abs(delta_data))
	elif cat == ComponentDatabase.Category.COMMUNICATIONS:
		if delta_data > 0.1:
			positives.append("▲ Downlink Bandwidth: +%0.1f Gbit/day throughput" % delta_data)
		elif delta_data < -0.1:
			negatives.append("▼ Downlink Bottleneck: -%0.1f Gbit/day bandwidth" % abs(delta_data))
	
	# Delta-V effect
	if new_comp.has("delta_v_ms") and old_comp.has("delta_v_ms"):
		var delta_dv: float = new_comp["delta_v_ms"] - old_comp["delta_v_ms"]
		if delta_dv > 5.0:
			positives.append("▲ Propulsion Margin: +%0.0f m/s ΔV (LOI capture & orbital maintenance)" % delta_dv)
		elif delta_dv < -5.0:
			negatives.append("▼ Propulsion Deficit: -%0.0f m/s ΔV (Reduced insertion/lifetime margin)" % abs(delta_dv))
	
	# Storage effect
	if new_comp.has("storage_wh") and old_comp.has("storage_wh"):
		var delta_wh: float = new_comp["storage_wh"] - old_comp["storage_wh"]
		if delta_wh > 10.0:
			positives.append("▲ Eclipse Endurance: +%0.0f Wh (Deeper shadow survival)" % delta_wh)
		elif delta_wh < -10.0:
			negatives.append("▼ Eclipse Risk: -%0.0f Wh (Higher battery Depth of Discharge)" % abs(delta_wh))
	
	# Reliability effect
	if delta_rel > 0.5:
		positives.append("▲ Reliability: +%0.1f%% (Flight-proven heritage)" % delta_rel)
	elif delta_rel < -0.5:
		negatives.append("▼ Complexity Risk: -%0.1f%% reliability" % abs(delta_rel))
	
	var insight: String = new_comp.get("engineering_insight", "")
	var summary_pos: String = new_comp.get("tradeoff_positive", "")
	var summary_neg: String = new_comp.get("tradeoff_negative", "")
	
	return {
		"category_name": cat_name,
		"new_name": new_name,
		"old_name": old_name,
		"positives": positives,
		"negatives": negatives,
		"insight": insight,
		"summary_pos": summary_pos,
		"summary_neg": summary_neg
	}
