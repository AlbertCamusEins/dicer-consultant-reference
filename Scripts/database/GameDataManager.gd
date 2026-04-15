extends Node

var characters: Dictionary = {}
var equipments: Dictionary = {}
var hexes: Dictionary = {}
var hex_animations: Dictionary = {}
var enemies: Dictionary = {}
var bosses: Dictionary = {}
var items: Dictionary = {}
var encounters: Dictionary = {}
var statuses: Dictionary = {}
var traits: Dictionary = {}
var effects: Dictionary = {}
var quests: Dictionary = {}

var battle_test_config: Dictionary = {}
var tutorial_battle_template: Dictionary = {}
var tutorial_battle_config: Dictionary = {}

func set_battle_test_config(cfg: Dictionary) -> void:
	battle_test_config = cfg

func update_battle_test_config(updates: Dictionary) -> void:
	for key in updates:
		battle_test_config[key] = updates[key]

func take_battle_test_config() -> Dictionary:
	var cfg = battle_test_config.duplicate(true)
	battle_test_config = {}
	return cfg

func clear_battle_test_config() -> void:
	battle_test_config = {}

func set_tutorial_battle_config(cfg: Dictionary) -> void:
	tutorial_battle_config = cfg.duplicate(true)

func get_tutorial_battle_config() -> Dictionary:
	return tutorial_battle_config.duplicate(true)

func get_tutorial_battle_template() -> Dictionary:
	return tutorial_battle_template.duplicate(true)

func clear_tutorial_battle_config() -> void:
	tutorial_battle_config = {}

func set_test_embedded_faces(data: Dictionary) -> void:
	battle_test_config["embedded_faces"] = data

func get_test_embedded_faces() -> Dictionary:
	return battle_test_config.get("embedded_faces", {})

func set_test_stored_faces(dice_type: String, faces: Array) -> void:
	if not battle_test_config.has("stored_faces"):
		battle_test_config["stored_faces"] = {}
	battle_test_config["stored_faces"][dice_type] = faces

func get_test_stored_faces(dice_type: String) -> Array:
	if battle_test_config.has("stored_faces") and battle_test_config.stored_faces.has(dice_type):
		return battle_test_config.stored_faces[dice_type]
	return []

func _ready() -> void:
	load_all_game_data()

func load_all_game_data() -> void:
	print("[GameDataManager] Loading game data...")
	load_characters()
	load_equipments()
	load_hexes()
	load_hex_animations()
	load_enemies()
	load_bosses()
	load_items()
	load_encounters()
	load_statuses()
	load_traits()
	load_quests()
	load_tutorial_battle_config()

func load_characters() -> void:
	var json_data = load_json_file("res://GameData/characters.json")
	if json_data:
		characters = json_data.characters
		print("[GameDataManager] Loaded ", characters.size(), " characters")

func load_equipments() -> void:
	var json_data = load_json_file("res://GameData/equipments_v2.json")
	if json_data:
		equipments = json_data.equipments
		print("[GameDataManager] Loaded ", equipments.size(), " equipments")

func load_hexes() -> void:
	var json_data = load_json_file("res://GameData/hexes.json")
	if json_data:
		hexes = json_data.hexes
		print("[GameDataManager] Loaded ", hexes.size(), " hexes")

func load_hex_animations() -> void:
	var json_data = load_json_file("res://GameData/hex_animations.json")
	if json_data:
		hex_animations = json_data.get("hex_animations", {})
		print("[GameDataManager] Loaded ", hex_animations.size(), " hex animations")

func load_enemies() -> void:
	var json_data = load_json_file("res://GameData/enemies.json")
	if json_data:
		enemies = json_data.enemies
		print("[GameDataManager] Loaded ", enemies.size(), " enemies")

func load_bosses() -> void:
	var json_data = load_json_file("res://GameData/bosses.json")
	if json_data:
		bosses = json_data.bosses
		print("[GameDataManager] Loaded ", bosses.size(), " bosses")

func load_items() -> void:
	var json_data = load_json_file("res://GameData/items.json")
	if json_data:
		items = json_data.items
		print("[GameDataManager] Loaded ", items.size(), " items")

func load_encounters() -> void:
	var json_data = load_json_file("res://GameData/encounters_test.json")
	if json_data:
		encounters = json_data.encounters
	print("[GameDataManager] Loaded ", encounters.size(), " encounters")

func load_statuses() -> void:
	var json_data = load_json_file("res://GameData/statuses_v2.json")
	if json_data:
		statuses = json_data.statuses
		print("[GameDataManager] Loaded ", statuses.size(), " statuses")

func load_traits() -> void:
	var json_data = load_json_file("res://GameData/traits_v2.json")
	if json_data:
		traits = json_data.get("traits", {})
		print("[GameDataManager] Loaded ", traits.size(), " traits")

func load_quests() -> void:
	var json_data = load_json_file("res://GameData/quests.json")
	if json_data:
		quests = json_data.get("quests", {})
		print("[GameDataManager] Loaded ", quests.size(), " quests")

func load_tutorial_battle_config() -> void:
	var json_data = load_json_file("res://GameData/tutorial_config.json")
	if json_data:
		tutorial_battle_template = json_data.duplicate(true)
		print("[GameDataManager] Loaded tutorial battle config")

func load_json_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		print("[GameDataManager] Error: File not found:", file_path)
		return {}

	var json_file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = json_file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		print("[GameDataManager] JSON Parse Error:", json.get_error_message())
		return {}

	return json.get_data()

func get_character_data(id: String) -> Dictionary:
	if characters.has(id):
		return _resolve_character_data(id, characters[id])
	print("[GameDataManager] Character not found:", id)
	return {}

func get_equipment_data(id: String) -> Dictionary:
	if equipments.has(id):
		return _resolve_equipment_data(id, equipments[id])
	print("[GameDataManager] Action not found: ", id)
	return {}

func get_hex_data(id: String) -> Dictionary:
	if hexes.has(id):
		return _resolve_hex_data(id, hexes[id])
	print("[GameDataManager] Hex not found: ", id)
	return {}

func get_enemy_data(id: String) -> Dictionary:
	if enemies.has(id):
		return _resolve_enemy_data(id, enemies[id])
	print("[GameDataManager] Enemy not found: ", id)
	return {}

func get_boss_data(id: String) -> Dictionary:
	if bosses.has(id):
		return _resolve_enemy_data(id, bosses[id])
	print("[GameDataManager] Boss not found: ", id)
	return {}

func get_item_data(id: String) -> Dictionary:
	if items.has(id):
		return _resolve_item_data(id, items[id])
	print("[GameDataManager] Item not found: ", id)
	return {}

func get_status_data(id: String) -> Dictionary:
	if statuses.has(id):
		return _resolve_status_data(id, statuses[id])
	print("[GameDataManager] Status not found: ", id)
	return {}

func get_status_data_by_name(status_name: String) -> Dictionary:
	if statuses.has(status_name):
		return _resolve_status_data(status_name, statuses[status_name])
	for id in statuses:
		var data = _resolve_status_data(id, statuses[id])
		if _name_matches(data, status_name, [
			str(data.get("id", "")),
			str(data.get("display_name", "")),
			str(data.get("status_name", "")),
			str(data.get("legacy_name", ""))
		]):
			return data
	return {}

func get_trait_data(id: String) -> Dictionary:
	if traits.has(id):
		return _resolve_trait_data(id, traits[id])
	return {}

func get_quest_data(id: String) -> Dictionary:
	if quests.has(id):
		return _resolve_quest_data(id, quests[id])
	print("[GameDataManager] Quest not found: ", id)
	return {}

func get_all_quests() -> Array:
	var quest_array = []
	for id in quests:
		var quest_data = _resolve_quest_data(id, quests[id])
		var quest = QuestData.new()
		var payload = quest_data.duplicate(true)
		payload["quest_id"] = id
		quest.init(payload)
		quest_array.append(quest)
	return quest_array

func _normalize_character_traits(char_data: Dictionary) -> Array:
	var trait_ids = char_data.get("traits", [])
	if typeof(trait_ids) == TYPE_ARRAY:
		return trait_ids.duplicate()
	if typeof(trait_ids) == TYPE_STRING and trait_ids != "":
		return [trait_ids]
	var legacy_trait_id = str(char_data.get("trait_id", ""))
	if legacy_trait_id != "":
		return [legacy_trait_id]
	return []

func _normalize_enemy_traits(enemy_data: Dictionary) -> Array:
	var trait_ids = enemy_data.get("traits", [])
	if typeof(trait_ids) == TYPE_ARRAY:
		return trait_ids.duplicate()
	if typeof(trait_ids) == TYPE_STRING and trait_ids != "":
		return [trait_ids]
	var legacy_trait_id = str(enemy_data.get("trait", ""))
	if legacy_trait_id != "":
		return [legacy_trait_id]
	return []

func _normalize_equipment_traits(equip_data: Dictionary) -> Array:
	var trait_ids = equip_data.get("traits", [])
	if typeof(trait_ids) == TYPE_ARRAY:
		return trait_ids.duplicate()
	return []

func _normalize_equipment_trait_descs(equip_data: Dictionary) -> Array:
	var trait_descs = equip_data.get("trait_descs", [])
	if typeof(trait_descs) == TYPE_ARRAY:
		return trait_descs.duplicate()
	var raw_traits = equip_data.get("traits", [])
	if typeof(raw_traits) == TYPE_STRING and raw_traits != "":
		return [raw_traits]
	return []

func _normalize_hex_traits(hex_data: Dictionary) -> Array:
	var trait_ids = hex_data.get("traits", [])
	if typeof(trait_ids) == TYPE_ARRAY:
		return trait_ids.duplicate()
	return []

func get_all_characters() -> Array:
	var character_array = []
	for id in characters:
		var char_data = _resolve_character_data(id, characters[id])
		var character = CharacterData.new()
		character.init(char_data)
		character_array.append(character)
	return character_array

func get_all_enemies() -> Array:
	var enemy_array = []
	for id in enemies:
		var enemy_data = _resolve_enemy_data(id, enemies[id])
		var enemy = EnemyData.new()
		enemy.init({
			"id": id,
			"enemy_name": enemy_data.get("display_name", enemy_data.get("name", enemy_data.get("enemy_name", ""))),
			"texture_path": enemy_data.get("texture_path", ""),
			"health": enemy_data.get("base_health", enemy_data.get("health", 0)),
			"traits": _normalize_enemy_traits(enemy_data),
			"health_per_occupied_face": enemy_data.get("health_per_occupied_face", 0)
		})
		enemy_array.append(enemy)
	return enemy_array

func get_all_bosses() -> Array:
	var boss_array = []
	for id in bosses:
		var boss_data = _resolve_enemy_data(id, bosses[id])
		var boss = EnemyData.new()
		boss.init({
			"id": id,
			"enemy_name": boss_data.get("display_name", boss_data.get("name", boss_data.get("enemy_name", ""))),
			"texture_path": boss_data.get("texture_path", ""),
			"health": boss_data.get("base_health", boss_data.get("health", 0)),
			"traits": _normalize_enemy_traits(boss_data)
		})
		boss_array.append(boss)
	return boss_array

func get_all_equipments() -> Array:
	var equipment_array = []
	for id in equipments:
		var equip_data = _resolve_equipment_data(id, equipments[id])
		var equipment = EquipmentData.new()
		equipment.init(equip_data)
		equipment_array.append(equipment)
	return equipment_array

func get_all_hexes() -> Array:
	var hex_array = []
	for id in hexes:
		var hex_data = _resolve_hex_data(id, hexes[id])
		var hex = HexData.new()
		hex.init(hex_data)
		hex_array.append(hex)
	return hex_array

func get_all_items() -> Array:
	var item_array = []
	for id in items:
		var item_data = _resolve_item_data(id, items[id])
		var item = ItemData.new()
		item.init(item_data)
		item_array.append(item)
	return item_array

func get_hex_animation_entries(hex_id: String) -> Array:
	var entries: Array = []
	if hex_id == "":
		return entries
	for entry_id in hex_animations.keys():
		var raw_entry = hex_animations.get(entry_id, {})
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		if str(raw_entry.get("hex_id", "")) != hex_id:
			continue
		if raw_entry.has("enabled") and not bool(raw_entry.get("enabled", true)):
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		entry["id"] = str(entry_id)
		entries.append(entry)
	entries.sort_custom(func(a, b): return int(a.get("play_order", 0)) < int(b.get("play_order", 0)))
	return entries

func get_hex_visual_total_duration(hex_id: String) -> float:
	var total_duration := 0.0
	for entry in get_hex_animation_entries(hex_id):
		total_duration += maxf(float(entry.get("duration", 0.0)), 0.0)
	return total_duration

func get_character_id_by_name(name: String) -> String:
	for id in characters:
		var data = _resolve_character_data(id, characters[id])
		if _name_matches(data, name, [data.get("display_name", ""), data.get("legacy_name", ""), data.get("character_name", "")]):
			return id
	return ""

func get_equipment_id_by_name(name: String) -> String:
	for id in equipments:
		var data = _resolve_equipment_data(id, equipments[id])
		if _name_matches(data, name, [data.get("display_name", ""), data.get("legacy_name", ""), data.get("equipment_name", "")]):
			return id
	return ""

func get_hex_id_by_name(name: String) -> String:
	for id in hexes:
		var data = _resolve_hex_data(id, hexes[id])
		if _name_matches(data, name, [data.get("display_name", ""), data.get("legacy_name", ""), data.get("hex_name", ""), data.get("name", "")]):
			return id
	return ""

func get_item_id_by_name(name: String) -> String:
	for id in items:
		var data = _resolve_item_data(id, items[id])
		if _name_matches(data, name, [data.get("display_name", ""), data.get("legacy_name", ""), data.get("item_name", "")]):
			return id
	return ""

func get_encounter_difficulty(encounter_id: String) -> int:
	if not encounters.has(encounter_id):
		return 0

	var encounter = encounters[encounter_id]
	var total_weight = 0
	for enemy_id in encounter.get("enemies", []):
		if enemies.has(enemy_id):
			total_weight += enemies[enemy_id].get("weight", 0)
	return total_weight

func get_valid_encounters(floor_num: int, type: String) -> Array:
	var valid_encounters = []
	var min_weight = 0
	var max_weight = 0

	match type:
		"normal":
			min_weight = 6
			max_weight = 8
		_:
			return []

	for id in encounters:
		var difficulty = get_encounter_difficulty(id)
		if difficulty >= min_weight and difficulty <= max_weight:
			valid_encounters.append(id)

	return valid_encounters

func _resolve_character_data(id: String, source: Dictionary) -> Dictionary:
	var data = source.duplicate(true)
	data["id"] = id
	data["display_name_key"] = str(data.get("display_name_key", "char.%s.name" % id))
	data["legacy_name"] = str(data.get("name", data.get("character_name", "")))
	data["display_name"] = LocalizationManager.tr_data(data["display_name_key"], data["legacy_name"] if data["legacy_name"] != "" else id)
	data["name"] = data["display_name"]
	data["character_name"] = data["display_name"]
	data["traits"] = _normalize_character_traits(data)
	data["health"] = int(data.get("base_health", data.get("health", 0)))
	return data

func _resolve_enemy_data(id: String, source: Dictionary) -> Dictionary:
	var data = source.duplicate(true)
	data["id"] = id
	data["display_name_key"] = str(data.get("display_name_key", "enemy.%s.name" % id))
	data["legacy_name"] = str(data.get("name", data.get("enemy_name", "")))
	data["display_name"] = LocalizationManager.tr_data(data["display_name_key"], data["legacy_name"] if data["legacy_name"] != "" else id)
	data["name"] = data["display_name"]
	data["enemy_name"] = data["display_name"]
	data["traits"] = _normalize_enemy_traits(data)
	return data

func _resolve_equipment_data(id: String, source: Dictionary) -> Dictionary:
	var data = source.duplicate(true)
	data["id"] = id
	data["display_name_key"] = str(data.get("display_name_key", "equipment.%s.name" % id))
	data["legacy_name"] = str(data.get("equipment_name", ""))
	data["display_name"] = LocalizationManager.tr_data(data["display_name_key"], data["legacy_name"] if data["legacy_name"] != "" else id)
	data["equipment_name"] = data["display_name"]
	data["traits"] = _normalize_equipment_traits(data)
	data["trait_desc_keys"] = _normalize_equipment_trait_desc_keys(id, data)
	data["trait_descs"] = _resolve_equipment_trait_descs(id, data)
	if not data.has("tags"):
		data["tags"] = []
	if not data.has("forged_variant_id"):
		data["forged_variant_id"] = ""
	if not data.has("is_forged"):
		data["is_forged"] = false
	return data

func _resolve_hex_data(id: String, source: Dictionary) -> Dictionary:
	var data = source.duplicate(true)
	data["id"] = id
	data["display_name_key"] = str(data.get("display_name_key", "hex.%s.name" % id))
	data["description_key"] = str(data.get("description_key", "hex.%s.desc" % id))
	data["legacy_name"] = str(data.get("name", data.get("hex_name", "")))
	data["display_name"] = LocalizationManager.tr_data(data["display_name_key"], data["legacy_name"] if data["legacy_name"] != "" else id)
	data["description"] = LocalizationManager.tr_data(data["description_key"], str(data.get("hex_desc", "")))
	data["name"] = data["display_name"]
	data["hex_name"] = data["display_name"]
	data["hex_desc"] = data["description"]
	data["traits"] = _normalize_hex_traits(data)
	return data

func _resolve_status_data(id: String, source: Dictionary) -> Dictionary:
	var data = source.duplicate(true)
	data["id"] = id
	data["display_name_key"] = str(data.get("display_name_key", "status.%s.name" % id))
	data["description_key"] = str(data.get("description_key", "status.%s.desc" % id))
	var hover_description_key := "status.%s.hover" % id
	data["legacy_name"] = str(data.get("status_name", ""))
	data["display_name"] = LocalizationManager.tr_data(data["display_name_key"], data["legacy_name"] if data["legacy_name"] != "" else id)
	data["description"] = LocalizationManager.tr_data(data["description_key"], str(data.get("description", "")))
	data["hover_description"] = LocalizationManager.tr_data(hover_description_key, str(data.get("hover_description", "")))
	data["status_name"] = data["display_name"]
	return data

func build_runtime_status_display(status_key: String, status: Dictionary) -> Dictionary:
	if typeof(status) != TYPE_DICTIONARY or status.is_empty():
		return {}
	var status_data := _resolve_runtime_status_data(status_key, status)
	if status_data.is_empty():
		return {}
	var stacks := int(status.get("stacks", status.get("stack_count", 1)))
	var duration := int(status.get("duration", status_data.get("duration", 0)))
	var effects = status.get("effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		effects = {}
	var tick_damage := int(effects.get("tick_damage", 0))
	var template := str(status_data.get("hover_description", ""))
	if template == "":
		template = str(status_data.get("description", ""))
	return {
		"id": str(status_data.get("id", "")),
		"display_name": str(status_data.get("display_name", status_key)),
		"texture_path": str(status_data.get("texture_path", "")),
		"stacks": stacks,
		"duration": duration,
		"description": _render_status_hover_template(template, stacks, duration, effects, tick_damage)
	}

func _resolve_runtime_status_data(status_key: String, status: Dictionary) -> Dictionary:
	var status_id := str(status.get("id", ""))
	if status_id != "":
		var by_id := get_status_data(status_id)
		if not by_id.is_empty():
			return by_id
	var by_name := get_status_data_by_name(status_key)
	if not by_name.is_empty():
		return by_name
	var runtime_name := str(status.get("status_name", ""))
	if runtime_name != "":
		return get_status_data_by_name(runtime_name)
	return {}

func _render_status_hover_template(template: String, stacks: int, duration: int, effects: Dictionary, tick_damage: int) -> String:
	if template == "":
		return ""
	var replacements := {
		"stacks": str(stacks),
		"duration": "无限" if duration == -1 else str(max(duration, 0)),
		"tick_damage": str(tick_damage),
		"total_tick_damage": str(tick_damage * stacks),
		"tick_phase": str(effects.get("tick_phase", "")),
		"on_apply_self_countdown_delta": str(effects.get("on_apply_self_countdown_delta", ""))
	}
	for effect_key in effects.keys():
		var effect_value = effects.get(effect_key)
		if _is_status_template_scalar(effect_value):
			replacements[str(effect_key)] = _status_template_value_to_string(effect_value)
	var rendered := template
	for key in replacements.keys():
		rendered = rendered.replace("{%s}" % key, str(replacements[key]))
	return rendered

func _is_status_template_scalar(value) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_STRING or value_type == TYPE_INT or value_type == TYPE_FLOAT or value_type == TYPE_BOOL

func _status_template_value_to_string(value) -> String:
	if typeof(value) == TYPE_BOOL:
		return "true" if bool(value) else "false"
	return str(value)

func _resolve_item_data(id: String, source: Dictionary) -> Dictionary:
	var data = source.duplicate(true)
	data["item_id"] = str(data.get("item_id", id))
	data["display_name_key"] = str(data.get("display_name_key", "item.%s.name" % id))
	data["description_key"] = str(data.get("description_key", "item.%s.desc" % id))
	data["legacy_name"] = str(data.get("item_name", ""))
	data["display_name"] = LocalizationManager.tr_data(data["display_name_key"], data["legacy_name"] if data["legacy_name"] != "" else id)
	data["description"] = LocalizationManager.tr_data(data["description_key"], str(data.get("description", "")))
	data["item_name"] = data["display_name"]
	return data

func _resolve_trait_data(id: String, source: Dictionary) -> Dictionary:
	var data = source.duplicate(true)
	data["id"] = id
	data["display_name_key"] = str(data.get("display_name_key", "trait.%s.name" % id))
	data["description_key"] = str(data.get("description_key", "trait.%s.desc" % id))
	data["legacy_name"] = str(data.get("name", ""))
	data["display_name"] = LocalizationManager.tr_data(data["display_name_key"], data["legacy_name"] if data["legacy_name"] != "" else id)
	data["description"] = LocalizationManager.tr_data(data["description_key"], str(data.get("desc", "")))
	data["name"] = data["display_name"]
	data["desc"] = data["description"]
	return data

func _resolve_quest_data(id: String, source: Dictionary) -> Dictionary:
	var data = source.duplicate(true)
	data["quest_id"] = str(data.get("quest_id", id))
	data["title_key"] = str(data.get("title_key", "quest.%s.title" % id))
	data["legacy_name"] = str(data.get("quest_name", ""))
	data["quest_name"] = LocalizationManager.tr_data(data["title_key"], data["legacy_name"] if data["legacy_name"] != "" else id)
	return data

func _normalize_equipment_trait_desc_keys(id: String, equip_data: Dictionary) -> Array:
	var keys = equip_data.get("trait_desc_keys", [])
	if typeof(keys) == TYPE_ARRAY:
		return keys.duplicate()
	var legacy_descs = equip_data.get("trait_descs", [])
	if typeof(legacy_descs) != TYPE_ARRAY:
		return []
	var generated: Array = []
	for index in range(legacy_descs.size()):
		generated.append("equipment.%s.trait_desc.%d" % [id, index])
	return generated

func _resolve_equipment_trait_descs(id: String, equip_data: Dictionary) -> Array:
	var desc_keys := _normalize_equipment_trait_desc_keys(id, equip_data)
	var legacy_descs = equip_data.get("trait_descs", [])
	var resolved: Array = []
	for index in range(desc_keys.size()):
		var fallback := ""
		if typeof(legacy_descs) == TYPE_ARRAY and index < legacy_descs.size():
			fallback = str(legacy_descs[index])
		resolved.append(LocalizationManager.tr_data(str(desc_keys[index]), fallback))
	return resolved

func _name_matches(data: Dictionary, candidate: String, options: Array) -> bool:
	var target := candidate.strip_edges()
	if target == "":
		return false
	if str(data.get("id", "")) == target:
		return true
	for option in options:
		if str(option) == target:
			return true
	return false
