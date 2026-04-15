extends Node

class_name CharacterData

var id: String = ""
var character_name: String
var display_name_key: String = ""
var texture_path: String
var health: int
var traits: Array = []
var special_action: String
var experience: int
var countdown: int # action countdown ticks
var slot_limit: int = 0

var prime_hex_id: String
var peak_hex_id: String
var soul_hex_id: String

const unlock_level: int = 2

const level_data: Dictionary = {
		1: {"exp_required" : 100, "health_gain" : 2},
		2: {"exp_required" : 150, "health_gain" : 2}
	}

func init(data: Dictionary) -> CharacterData:
		id = data.get("id", "")
		display_name_key = str(data.get("display_name_key", ""))
		character_name = data.get("character_name", "")
		texture_path = data.get("texture_path", "")
		health = data.get("health", 0)
		var raw_traits = data.get("traits", [])
		if typeof(raw_traits) == TYPE_ARRAY:
			traits = raw_traits.duplicate()
		elif typeof(raw_traits) == TYPE_STRING and raw_traits != "":
			traits = [raw_traits]
		else:
			var legacy_trait_id = str(data.get("trait_id", ""))
			traits = [legacy_trait_id] if legacy_trait_id != "" else []
		special_action = data.get("special_action", "")
		experience = data.get("experience", 0)
		countdown = data.get("countdown", 999)
		slot_limit = data.get("slot_limit", 0)
		
		prime_hex_id = data.get("prime_hex_id", data.get("prime_hex", ""))
		peak_hex_id = data.get("peak_hex_id", data.get("peak_hex", ""))
		soul_hex_id = data.get("soul_hex_id", data.get("soul_hex", ""))
		return self
