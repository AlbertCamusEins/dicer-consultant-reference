extends Node

class_name EnemyData

var id: String = ""
var enemy_name: String
var texture_path: String
var health: int
var traits: Array = []
var weight: int = 0
var unique_id: String = ""
var equipment: Array = []
var hexes: Array = []
var countdown: int
var health_per_occupied_face: int = 0

func init(data: Dictionary) -> EnemyData:
		id = str(data.get("id", ""))
		enemy_name = data.get("enemy_name", data.get("name", ""))
		texture_path = data.get("texture_path", "")
		health = data.get("health", data.get("base_health", 0))
		var raw_traits = data.get("traits", [])
		if typeof(raw_traits) == TYPE_ARRAY:
			traits = raw_traits.duplicate()
		elif typeof(raw_traits) == TYPE_STRING and raw_traits != "":
			traits = [raw_traits]
		else:
			var legacy_trait_id = str(data.get("trait", ""))
			traits = [legacy_trait_id] if legacy_trait_id != "" else []
		weight = data.get("weight", 0)
		unique_id = data.get("unique_id", "")
		equipment = data.get("equipment", [])
		hexes = data.get("hexes", [])
		countdown = data.get("countdown", 999)
		health_per_occupied_face = int(data.get("health_per_occupied_face", 0))
		return self
