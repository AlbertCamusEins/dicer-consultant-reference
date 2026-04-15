extends Node

class_name EquipmentData

var id: String = ""
var equipment_name: String
var display_name_key: String = ""
var texture_path: String
var slot_limit: int
var attack_bonus: int
var defense_bonus: int
var traits: Array = []
var trait_descs: Array = []
var tags: Array = []
var forged_variant_id: String = ""
var is_forged: bool = false
var trait_desc_keys: Array = []

func init(data:Dictionary) -> EquipmentData:
	id = data.get("id", "")
	display_name_key = str(data.get("display_name_key", ""))
	equipment_name = data.get("equipment_name","")
	texture_path = data.get("texture_path","")
	slot_limit = data.get("slot_limit",0)
	attack_bonus = data.get("attack_bonus", 0)
	defense_bonus = data.get("defense_bonus", 0)
	var raw_traits = data.get("traits", [])
	if typeof(raw_traits) == TYPE_ARRAY:
		traits = raw_traits.duplicate()
	else:
		traits = []
	var raw_trait_descs = data.get("trait_descs", [])
	trait_descs = []
	var raw_trait_desc_keys = data.get("trait_desc_keys", [])
	trait_desc_keys = raw_trait_desc_keys.duplicate() if typeof(raw_trait_desc_keys) == TYPE_ARRAY else []
	if typeof(raw_trait_descs) == TYPE_ARRAY:
		trait_descs = raw_trait_descs.duplicate()
	elif typeof(raw_traits) == TYPE_STRING and raw_traits != "":
		trait_descs = [raw_traits]
	var raw_tags = data.get("tags", [])
	tags = []
	if typeof(raw_tags) == TYPE_ARRAY:
		tags = raw_tags.duplicate()
	forged_variant_id = str(data.get("forged_variant_id", ""))
	is_forged = bool(data.get("is_forged", false))
	return self

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name_key": display_name_key,
		"equipment_name": equipment_name,
		"texture_path": texture_path,
		"slot_limit": slot_limit,
		"attack_bonus": attack_bonus,
		"defense_bonus": defense_bonus,
		"traits": traits.duplicate(),
		"trait_descs": trait_descs.duplicate(),
		"trait_desc_keys": trait_desc_keys.duplicate(),
		"tags": tags.duplicate(),
		"forged_variant_id": forged_variant_id,
		"is_forged": is_forged
	}
