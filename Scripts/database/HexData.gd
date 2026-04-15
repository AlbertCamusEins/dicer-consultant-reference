extends Node

class_name HexData

var hex_name: String
var display_name_key: String = ""
var description_key: String = ""
var hex_desc: String = ""
var texture_path: String
var caster: String = "ally facing up"
var cast_condition: DiceFace = DiceFace.UP

enum TargetTeam { ALLY, ENEMY }
enum TargetType { CHARACTER, DICEFACE, DICE }
enum DiceType { FRIEND, EQUIPMENT, HEX }
enum DiceFace { UP, DOWN, SIDE }

var target_template = {
	"team": TargetTeam.ENEMY,
	"type": TargetType.CHARACTER,
	"condition": {
		"dice_reference": {
			"type": DiceType.FRIEND,
			"face": DiceFace.UP
		},
		"status_check": [],
		"index": 0
	}
}
var target_data: Array = []

enum EffectType { HEALTH_CHANGE, STATUS_APPLY, SPECIAL, SHIELD_CHANGE }
enum StatusType { BUFF, DEBUFF, SPECIAL }
enum Category { DoT, DAMAGE_MOD, CROWD_CONTROL, AGGRO }
enum StatusTarget { CHARACTER, DICE, DICE_FACE }

var effect_template = {
	"cast_condition": DiceFace.UP,
	"type": EffectType.HEALTH_CHANGE,
	"value": 0,
	"status_info": {
		"status_type": StatusType.BUFF,
		"category": Category.DoT,
		"status_target": StatusTarget.CHARACTER,
		"status_name": "",
		"duration": 0,
		"stack_count": 1,
		"effects": {}
	},
	"target_index": [0, 1]
}

var effect_data: Array = []
var traits: Array = []

var is_peak: bool = false
var is_soul: bool = false
var enemy_owned: bool = false
var owner_character: String = ""
var id: String = ""
var slot_limit: int = 0

func init(data: Dictionary) -> HexData:
	id = data.get("id", "")
	display_name_key = str(data.get("display_name_key", ""))
	description_key = str(data.get("description_key", ""))
	hex_name = data.get("hex_name", "")
	hex_desc = data.get("hex_desc", "")
	texture_path = data.get("texture_path", "")
	caster = data.get("caster", "ally facing up")
	cast_condition = data.get("cast_condition", DiceFace.UP)
	target_data = data.get("target_data", [])
	effect_data = data.get("effect_data", [])
	traits = data.get("traits", [])
	is_peak = data.get("is_peak", false)
	is_soul = data.get("is_soul", false)
	enemy_owned = data.get("enemy_owned", false)
	owner_character = data.get("owner_character", "")
	slot_limit = data.get("slot_limit", 0)
	_merge_canonical_hex_data()
	_enrich_status_effects()
	return self

func to_dict() -> Dictionary:
	var serialized_target_data = []
	for target in target_data:
		var serialized_target = target.duplicate(true)
		if target.has("team"):
			serialized_target["team"] = int(target["team"])
		if target.has("type"):
			serialized_target["type"] = int(target["type"])
		if target.has("condition") and target["condition"].has("dice_reference"):
			var dice_ref = target["condition"]["dice_reference"]
			if dice_ref.has("type"):
				serialized_target["condition"]["dice_reference"]["type"] = int(dice_ref["type"])
			if dice_ref.has("face"):
				serialized_target["condition"]["dice_reference"]["face"] = int(dice_ref["face"])
		serialized_target_data.append(serialized_target)

	var serialized_effect_data = []
	for effect in effect_data:
		var serialized_effect = effect.duplicate(true)
		if effect.has("type"):
			var effect_type = effect["type"]
			if typeof(effect_type) == TYPE_INT or typeof(effect_type) == TYPE_FLOAT:
				serialized_effect["type"] = int(effect_type)
			else:
				serialized_effect["type"] = str(effect_type)
		if effect.has("cast_condition"):
			serialized_effect["cast_condition"] = int(effect["cast_condition"])
		if effect.has("status_info") and effect["status_info"].has("status_type"):
			serialized_effect["status_info"]["status_type"] = int(effect["status_info"]["status_type"])
		if effect.has("status_info") and effect["status_info"].has("category"):
			serialized_effect["status_info"]["category"] = int(effect["status_info"]["category"])
		if effect.has("status_info") and effect["status_info"].has("status_target"):
			serialized_effect["status_info"]["status_target"] = int(effect["status_info"]["status_target"])
		serialized_effect_data.append(serialized_effect)

	return {
		"hex_name": hex_name,
		"display_name_key": display_name_key,
		"description_key": description_key,
		"hex_desc": hex_desc,
		"texture_path": texture_path,
		"target_data": serialized_target_data,
		"effect_data": serialized_effect_data,
		"traits": traits.duplicate(),
		"cast_condition": int(cast_condition),
		"is_peak": is_peak,
		"is_soul": is_soul,
		"enemy_owned": enemy_owned,
		"owner_character": owner_character,
		"id": id,
		"slot_limit": slot_limit
	}

func from_dict(data: Dictionary) -> void:
	hex_name = data.get("hex_name", "")
	display_name_key = str(data.get("display_name_key", ""))
	description_key = str(data.get("description_key", ""))
	hex_desc = data.get("hex_desc", "")
	texture_path = data.get("texture_path", "")
	cast_condition = data.get("cast_condition", DiceFace.UP)

	target_data = []
	for target in data.get("target_data", []):
		var deserialized_target = target.duplicate(true)
		if target.has("team"):
			deserialized_target["team"] = TargetTeam.values()[int(target["team"])]
		if target.has("type"):
			deserialized_target["type"] = TargetType.values()[int(target["type"])]
		if target.has("condition") and target["condition"].has("dice_reference"):
			var dice_ref = target["condition"]["dice_reference"]
			if dice_ref.has("type"):
				deserialized_target["condition"]["dice_reference"]["type"] = DiceType.values()[int(dice_ref["type"])]
			if dice_ref.has("face"):
				deserialized_target["condition"]["dice_reference"]["face"] = DiceFace.values()[int(dice_ref["face"])]
		target_data.append(deserialized_target)

	effect_data = []
	for effect in data.get("effect_data", []):
		var deserialized_effect = effect.duplicate(true)
		if effect.has("type"):
			var effect_type = effect["type"]
			if typeof(effect_type) == TYPE_INT or typeof(effect_type) == TYPE_FLOAT:
				deserialized_effect["type"] = EffectType.values()[int(effect_type)]
			else:
				deserialized_effect["type"] = str(effect_type)
		if effect.has("cast_condition"):
			deserialized_effect["cast_condition"] = DiceFace.values()[int(effect["cast_condition"])]
		if effect.has("status_info") and effect["status_info"].has("status_type"):
			deserialized_effect["status_info"]["status_type"] = StatusType.values()[int(effect["status_info"]["status_type"])]
		if effect.has("status_info") and effect["status_info"].has("category"):
			deserialized_effect["status_info"]["category"] = Category.values()[int(effect["status_info"]["category"])]
		if effect.has("status_info") and effect["status_info"].has("status_target"):
			deserialized_effect["status_info"]["status_target"] = StatusTarget.values()[int(effect["status_info"]["status_target"])]
		effect_data.append(deserialized_effect)
	traits = data.get("traits", []).duplicate()

	is_peak = data.get("is_peak", false)
	is_soul = data.get("is_soul", false)
	enemy_owned = data.get("enemy_owned", false)
	owner_character = data.get("owner_character", "")
	id = data.get("id", "")
	slot_limit = data.get("slot_limit", 0)
	_merge_canonical_hex_data()
	_enrich_status_effects()

func _merge_canonical_hex_data() -> void:
	var canonical_data := _get_canonical_hex_data()
	if canonical_data.is_empty():
		return
	id = str(canonical_data.get("id", id))
	hex_name = str(canonical_data.get("name", canonical_data.get("hex_name", hex_name)))
	hex_desc = str(canonical_data.get("hex_desc", hex_desc))
	texture_path = str(canonical_data.get("texture_path", texture_path))
	cast_condition = canonical_data.get("cast_condition", cast_condition)
	target_data = canonical_data.get("target_data", []).duplicate(true)
	effect_data = canonical_data.get("effect_data", []).duplicate(true)
	traits = canonical_data.get("traits", []).duplicate()
	enemy_owned = bool(canonical_data.get("enemy_owned", enemy_owned))
	slot_limit = int(canonical_data.get("slot_limit", slot_limit))

func _get_canonical_hex_data() -> Dictionary:
	if id != "":
		var canonical_by_id = GameDataManager.get_hex_data(id)
		if not canonical_by_id.is_empty():
			var resolved = canonical_by_id.duplicate(true)
			resolved["id"] = id
			return resolved
	if hex_name != "":
		var resolved_id = GameDataManager.get_hex_id_by_name(hex_name)
		if resolved_id != "":
			var canonical_by_name = GameDataManager.get_hex_data(resolved_id)
			if not canonical_by_name.is_empty():
				var resolved = canonical_by_name.duplicate(true)
				resolved["id"] = resolved_id
				return resolved
	return {}

func _enrich_status_effects() -> void:
	for effect in effect_data:
		if effect.has("status_id") and effect["status_id"] != "":
			var s_data = GameDataManager.get_status_data(effect["status_id"])
			if not s_data.is_empty():
				var info = effect.get("status_info", {}).duplicate(true)
				info["status_name"] = s_data.get("status_name", "")
				if not info.has("status_type"):
					info["status_type"] = s_data.get("status_type", StatusType.BUFF)
				if not info.has("category"):
					info["category"] = s_data.get("category", Category.DoT)
				if not info.has("status_target"):
					info["status_target"] = s_data.get("status_target", StatusTarget.CHARACTER)
				if not info.has("duration"):
					info["duration"] = s_data.get("duration", 0)
				if not info.has("stack_count"):
					info["stack_count"] = s_data.get("stack_count", 1)
				if not info.has("max_stacks") and s_data.has("max_stacks"):
					info["max_stacks"] = s_data.get("max_stacks", -1)
				var merged_effects = s_data.get("effects", {}).duplicate(true)
				var info_effects = info.get("effects", {})
				if typeof(info_effects) == TYPE_DICTIONARY:
					for key in info_effects.keys():
						merged_effects[key] = info_effects[key]
				info["effects"] = merged_effects
				effect["status_info"] = info
