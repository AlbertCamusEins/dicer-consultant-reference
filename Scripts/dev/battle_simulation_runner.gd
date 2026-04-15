extends Node

const DEFAULT_CONFIG_PATH := "res://GameData/battle_simulation_config.json"
const BATTLE_SCENE_PATH := "res://Scenes/battle_scene.tscn"
const ROLL_SEQUENCE := [
	"frien",
	"equipment",
	"hex2",
	"enemy_frien",
	"enemy_equipment",
	"enemy_hex2"
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	GameDataManager.load_all_game_data()
	var config_path: String = _resolve_config_path()
	var config: Dictionary = _load_json_dict(config_path)
	print("[BattleSimulationRunner] Config path: %s" % config_path)
	if config.is_empty():
		push_error("[BattleSimulationRunner] Failed to load config: %s" % config_path)
		get_tree().quit(1)
		return
	var runs: int = max(int(config.get("runs", 1)), 1)
	var base_seed: int = int(config.get("seed", 0))
	var results: Array = []
	for run_index in range(runs):
		var battle_index: int = run_index + 1
		var battle_seed: int = base_seed + run_index
		print("[BattleSimulationRunner] Starting battle %d seed=%d" % [battle_index, battle_seed])
		var encounter_info: Dictionary = _resolve_encounter_setup(config.get("encounter_setup", {}))
		if encounter_info.is_empty():
			push_error("[BattleSimulationRunner] Failed to resolve encounter setup")
			get_tree().quit(1)
			return
		var battle_config: Dictionary = _build_battle_test_config(config, encounter_info, battle_index, battle_seed)
		var summary: Dictionary = await _run_single_battle(battle_config)
		results.append(summary)
	var output_paths: Dictionary = _write_outputs(config, results)
	print("[BattleSimulationRunner] Completed %d runs" % runs)
	print("[BattleSimulationRunner] JSON: %s" % output_paths.get("json", ""))
	print("[BattleSimulationRunner] CSV: %s" % output_paths.get("csv", ""))
	get_tree().quit()

func _resolve_config_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--config="):
			return arg.trim_prefix("--config=")
		if arg.ends_with(".json"):
			return arg
	return DEFAULT_CONFIG_PATH

func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("[BattleSimulationRunner] JSON parse error: %s" % json.get_error_message())
		return {}
	var data = json.get_data()
	return data if typeof(data) == TYPE_DICTIONARY else {}

func _resolve_encounter_setup(encounter_setup) -> Dictionary:
	if typeof(encounter_setup) != TYPE_DICTIONARY:
		return {}
	var mode: String = str(encounter_setup.get("mode", ""))
	match mode:
		"enemy_entries":
			var enemies = encounter_setup.get("enemies", [])
			if typeof(enemies) != TYPE_ARRAY:
				return {}
			return {
				"enemy_entries": enemies.duplicate(true),
				"encounter_id": str(encounter_setup.get("encounter_id", "")),
				"enemy_config_label": str(encounter_setup.get("label", encounter_setup.get("encounter_id", "enemy_entries")))
			}
		"encounter_list":
			return _expand_encounter_list(encounter_setup)
	return {}

func _expand_encounter_list(encounter_setup: Dictionary) -> Dictionary:
	var encounter_ids = encounter_setup.get("encounter_ids", encounter_setup.get("encounters", []))
	if typeof(encounter_ids) != TYPE_ARRAY or encounter_ids.is_empty():
		return {}
	var encounters: Dictionary = GameDataManager.encounters
	var source_path: String = str(encounter_setup.get("encounter_source_path", ""))
	if source_path != "":
		var source_data: Dictionary = _load_json_dict(source_path)
		if not source_data.is_empty():
			encounters = source_data.get("encounters", {})
	var enemies: Array = []
	var labels: Array[String] = []
	for raw_id in encounter_ids:
		var encounter_id: String = str(raw_id)
		if encounter_id == "":
			continue
		var encounter_data = encounters.get(encounter_id, {})
		if typeof(encounter_data) != TYPE_DICTIONARY:
			continue
		var encounter_enemies = encounter_data.get("enemies", [])
		if typeof(encounter_enemies) == TYPE_ARRAY:
			enemies.append_array(encounter_enemies.duplicate(true))
			labels.append(encounter_id)
	if enemies.is_empty():
		return {}
	return {
		"enemy_entries": enemies,
		"encounter_id": ",".join(labels),
		"enemy_config_label": str(encounter_setup.get("label", "encounter_list:%s" % ",".join(labels)))
	}

func _build_battle_test_config(config: Dictionary, encounter_info: Dictionary, battle_index: int, battle_seed: int) -> Dictionary:
	var player_setup = config.get("player_setup", {})
	if typeof(player_setup) != TYPE_DICTIONARY:
		player_setup = {}
	return {
		"is_test_mode": true,
		"is_simulation_mode": true,
		"fast_mode": bool(config.get("fast_mode", false)),
		"battle_type": int(config.get("battle_type", BattleManager.BattleType.BATTLE)),
		"reroll_count": int(player_setup.get("reroll_count", 0)),
		"player_character_ids": player_setup.get("player_character_ids", []).duplicate(true) if typeof(player_setup.get("player_character_ids", [])) == TYPE_ARRAY else [],
		"player_equipment_ids": player_setup.get("player_equipment_ids", []).duplicate(true) if typeof(player_setup.get("player_equipment_ids", [])) == TYPE_ARRAY else [],
		"player_hex_ids": player_setup.get("player_hex_ids", []).duplicate(true) if typeof(player_setup.get("player_hex_ids", [])) == TYPE_ARRAY else [],
		"embedded_faces": _build_player_embedded_faces(player_setup),
		"enemies": encounter_info.get("enemy_entries", []).duplicate(true),
		"persist_on_exit": false,
		"simulation_context": {
			"battle_index": battle_index,
			"seed": battle_seed,
			"encounter_id": str(encounter_info.get("encounter_id", "")),
			"enemy_config_label": str(encounter_info.get("enemy_config_label", "")),
			"enemy_entries": encounter_info.get("enemy_entries", []).duplicate(true)
		}
	}

func _build_player_embedded_faces(player_setup: Dictionary) -> Dictionary:
	var embedded_faces: Dictionary = {
		"frien": _build_face_section(
			player_setup.get("player_character_ids", []),
			func(face_id: String): return GameDataManager.get_character_data(face_id)
		),
		"equipment": _build_face_section(
			player_setup.get("player_equipment_ids", []),
			func(face_id: String): return GameDataManager.get_equipment_data(face_id)
		),
		"hex": _build_face_section(
			player_setup.get("player_hex_ids", []),
			func(face_id: String): return GameDataManager.get_hex_data(face_id)
		)
	}
	var overrides = player_setup.get("embedded_faces", {})
	if typeof(overrides) == TYPE_DICTIONARY:
		embedded_faces = _merge_dict_recursive(embedded_faces, overrides)
	return embedded_faces

func _build_face_section(face_ids, resolver: Callable) -> Dictionary:
	var section: Dictionary = {}
	if typeof(face_ids) != TYPE_ARRAY or face_ids.is_empty():
		return section
	for face_index in range(6):
		var face_id: String = str(face_ids[face_index % face_ids.size()])
		if face_id == "":
			continue
		var data = resolver.call(face_id)
		if typeof(data) != TYPE_DICTIONARY or data.is_empty():
			continue
		section[str(face_index)] = data.duplicate(true)
	return section

func _merge_dict_recursive(base: Dictionary, override: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	for key in override.keys():
		var base_value = merged.get(key)
		var override_value = override.get(key)
		if typeof(base_value) == TYPE_DICTIONARY and typeof(override_value) == TYPE_DICTIONARY:
			merged[key] = _merge_dict_recursive(base_value, override_value)
		else:
			merged[key] = override_value
	return merged

func _run_single_battle(battle_config: Dictionary) -> Dictionary:
	seed(int(battle_config.get("simulation_context", {}).get("seed", 0)))
	GameDataManager.set_battle_test_config(battle_config)
	BattleManager.reset_battle_state()
	var battle_scene_resource: PackedScene = load(BATTLE_SCENE_PATH)
	if battle_scene_resource == null:
		push_error("[BattleSimulationRunner] Failed to load battle scene")
		return {}
	var battle_scene: Node = battle_scene_resource.instantiate()
	get_tree().root.add_child(battle_scene)
	get_tree().current_scene = battle_scene
	await get_tree().process_frame
	await _simulate_battle_loop()
	await BattleManager.wait_health_queue_flushed()
	var summary: Dictionary = BattleManager.get_last_battle_summary()
	if summary.is_empty():
		summary = BattleManager.current_battle_stats.duplicate(true)
		summary["result"] = BattleManager.battle_result
	if get_tree().current_scene == battle_scene:
		get_tree().current_scene = null
	battle_scene.queue_free()
	await get_tree().process_frame
	return summary

func _simulate_battle_loop() -> void:
	while BattleManager.battle_result == "":
		for dice_type in ROLL_SEQUENCE:
			if BattleManager.battle_result != "":
				break
			await _roll_single_dice(dice_type)

func _roll_single_dice(dice_type: String) -> void:
	var face_index: int = _choose_face_index(dice_type)
	var dice_node = _find_dice_node(dice_type)
	if dice_node != null:
		var anim_sprite = dice_node.get_node_or_null("Dice Animations")
		if anim_sprite != null:
			anim_sprite.play("faces")
			anim_sprite.frame = face_index
			anim_sprite.pause()
		dice_node.current_face_index = face_index
	await BattleManager.update_dice_result(dice_type, face_index, true)
	DiceManager.emit_signal("dice_result_updated", dice_type)
	await get_tree().process_frame

func _choose_face_index(dice_type: String) -> int:
	var candidates = BattleManager.get_filtered_roll_candidates(dice_type)
	if candidates.is_empty():
		candidates = [0, 1, 2, 3, 4, 5]
	return BattleManager.get_biased_roll_face(dice_type, candidates)

func _find_dice_node(dice_type: String):
	for dice in get_tree().get_nodes_in_group("dice"):
		if str(dice.get("dice_type")) == dice_type:
			return dice
	return null

func _write_outputs(config: Dictionary, results: Array) -> Dictionary:
	var output_path: String = str(config.get("output_path", "user://battle_simulation_results.json"))
	var json_payload: Dictionary = {
		"runs": max(int(config.get("runs", results.size())), 1),
		"seed": int(config.get("seed", 0)),
		"config_snapshot": config.duplicate(true),
		"results": results.duplicate(true)
	}
	var json_text: String = JSON.stringify(json_payload, "\t")
	_write_text_file(output_path, json_text)
	var csv_path: String = output_path.get_basename() + ".csv"
	_write_text_file(csv_path, _build_csv_text(results))
	return {
		"json": ProjectSettings.globalize_path(output_path),
		"csv": ProjectSettings.globalize_path(csv_path)
	}

func _write_text_file(path: String, contents: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var directory: String = absolute_path.get_base_dir()
	if directory != "":
		DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("[BattleSimulationRunner] Failed to write file: %s" % absolute_path)
		return
	file.store_string(contents)

func _build_csv_text(results: Array) -> String:
	var headers: Array[String] = [
		"battle_index",
		"result",
		"total_ticks",
		"player_total_casts",
		"enemy_config_label",
		"encounter_id",
		"enemy_healing_received_total",
		"enemy_shield_received_total",
		"player_damage_dealt_by_unit",
		"player_damage_taken_by_unit",
		"player_healing_received_by_unit",
		"player_shield_received_by_unit"
	]
	var lines: Array[String] = [",".join(headers)]
	for result in results:
		if typeof(result) != TYPE_DICTIONARY:
			continue
		var row: Array[String] = []
		for header in headers:
			var value = result.get(header, "")
			if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
				value = JSON.stringify(value)
			row.append(_csv_escape(str(value)))
		lines.append(",".join(row))
	return "\n".join(lines) + "\n"

func _csv_escape(value: String) -> String:
	var escaped: String = value.replace("\"", "\"\"")
	if escaped.contains(",") or escaped.contains("\n") or escaped.contains("\r") or escaped.contains("\""):
		return "\"%s\"" % escaped
	return escaped
