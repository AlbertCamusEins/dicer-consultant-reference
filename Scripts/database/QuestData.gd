extends Node

class_name QuestData

var quest_id: String = ""
var quest_name: String = ""
var title_key: String = ""
var category: String = "generic"
var prerequisites: Array = []
var requirements: Array = []
var variants: Array = []
var time_limit: Dictionary = {}
var rewards: Dictionary = {
	"gold": 0,
	"faces": [],
	"items": [],
	"flags": []
}
var failure: Dictionary = {}

func init(data: Dictionary) -> QuestData:
	quest_id = str(data.get("quest_id", ""))
	quest_name = str(data.get("quest_name", ""))
	title_key = str(data.get("title_key", ""))
	category = str(data.get("category", "generic"))

	var raw_prerequisites = data.get("prerequisites", [])
	prerequisites = raw_prerequisites.duplicate(true) if typeof(raw_prerequisites) == TYPE_ARRAY else []

	var raw_requirements = data.get("requirements", [])
	requirements = raw_requirements.duplicate(true) if typeof(raw_requirements) == TYPE_ARRAY else []

	var raw_variants = data.get("variants", [])
	variants = raw_variants.duplicate(true) if typeof(raw_variants) == TYPE_ARRAY else []

	var raw_time_limit = data.get("time_limit", {})
	time_limit = raw_time_limit.duplicate(true) if typeof(raw_time_limit) == TYPE_DICTIONARY else {}

	var raw_rewards = data.get("rewards", {})
	rewards = {
		"gold": 0,
		"faces": [],
		"items": [],
		"flags": []
	}
	if typeof(raw_rewards) == TYPE_DICTIONARY:
		rewards["gold"] = int(raw_rewards.get("gold", 0))
		var rewards_faces = raw_rewards.get("faces", [])
		rewards["faces"] = rewards_faces.duplicate(true) if typeof(rewards_faces) == TYPE_ARRAY else []
		var rewards_items = raw_rewards.get("items", [])
		rewards["items"] = rewards_items.duplicate(true) if typeof(rewards_items) == TYPE_ARRAY else []
		var rewards_flags = raw_rewards.get("flags", [])
		rewards["flags"] = rewards_flags.duplicate(true) if typeof(rewards_flags) == TYPE_ARRAY else []

	var raw_failure = data.get("failure", {})
	failure = raw_failure.duplicate(true) if typeof(raw_failure) == TYPE_DICTIONARY else {}
	return self

func to_dict() -> Dictionary:
	return {
		"quest_id": quest_id,
		"quest_name": quest_name,
		"title_key": title_key,
		"category": category,
		"prerequisites": prerequisites.duplicate(true),
		"requirements": requirements.duplicate(true),
		"variants": variants.duplicate(true),
		"time_limit": time_limit.duplicate(true),
		"rewards": rewards.duplicate(true),
		"failure": failure.duplicate(true)
	}
