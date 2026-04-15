extends Node

class_name StatusData

enum StatusType { BUFF, DEBUFF, SPECIAL }
enum Category { DoT, DAMAGE_MOD, CROWD_CONTROL, AGGRO }
enum StatusTarget { CHARACTER, DICE, DICE_FACE }

var id: String = ""
var status_name: String = ""
var display_name_key: String = ""
var description_key: String = ""
var texture_path: String = ""
var status_type: StatusType = StatusType.BUFF
var category: Category = Category.DoT
var status_target: StatusTarget = StatusTarget.CHARACTER
var duration: int = 0              # default duration (turns) when applied, -1 represents infinitive
var stack_count: int = 1           # stacks granted on application
var max_stacks: int = -1           # -1 means unlimited
var effects: Dictionary = {}       # custom effect parameters
var description: String = ""
var hover_description: String = ""

func init(data: Dictionary) -> StatusData:
	id = data.get("id", "")
	display_name_key = str(data.get("display_name_key", ""))
	description_key = str(data.get("description_key", ""))
	status_name = data.get("status_name", "")
	texture_path = data.get("texture_path", "")
	status_type = _parse_status_type(data.get("status_type", StatusType.BUFF))
	category = _parse_category(data.get("category", Category.DoT))
	status_target = _parse_status_target(data.get("status_target", StatusTarget.CHARACTER))
	duration = data.get("duration", 0)
	stack_count = data.get("stack_count", 1)
	max_stacks = data.get("max_stacks", -1)
	description = data.get("description", "")
	hover_description = data.get("hover_description", "")
	effects = data.get("effects", {})
	return self

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name_key": display_name_key,
		"description_key": description_key,
		"status_name": status_name,
		"texture_path": texture_path,
		"status_type": int(status_type),
		"category": int(category),
		"status_target": int(status_target),
		"duration": duration,
		"stack_count": stack_count,
		"max_stacks": max_stacks,
		"description": description,
		"hover_description": hover_description,
		"effects": effects
	}

func from_dict(data: Dictionary) -> void:
	init({
		"id": data.get("id", id),
		"status_name": data.get("status_name", status_name),
		"texture_path": data.get("texture_path", texture_path),
		"status_type": data.get("status_type", status_type),
		"category": data.get("category", category),
		"status_target": data.get("status_target", status_target),
		"duration": data.get("duration", duration),
		"stack_count": data.get("stack_count", stack_count),
		"max_stacks": data.get("max_stacks", max_stacks),
		"description": data.get("description", description),
		"hover_description": data.get("hover_description", hover_description),
		"effects": data.get("effects", effects)
	})

func to_status_info() -> Dictionary:
	# Match HexData.effect_template.status_info structure for direct use in hex effects
	return {
		"status_type": status_type,
		"status_name": status_name,
		"category": category,
		"status_target": status_target,
		"duration": duration,
		"stack_count": stack_count,
		"max_stacks": max_stacks,
		"hover_description": hover_description,
		"effects": effects
	}

func _parse_status_type(value) -> StatusType:
	if typeof(value) == TYPE_INT:
		return StatusType.values()[int(value)]
	if typeof(value) == TYPE_STRING:
		match value.to_lower():
			"buff": return StatusType.BUFF
			"debuff": return StatusType.DEBUFF
			"special": return StatusType.SPECIAL
	return value

func _parse_category(value) -> Category:
	if typeof(value) == TYPE_INT:
		return Category.values()[int(value)]
	if typeof(value) == TYPE_STRING:
		match value.to_lower():
			"dot": return Category.DoT
			"damage_mod": return Category.DAMAGE_MOD
			"crowd_control": return Category.CROWD_CONTROL
			"aggro": return Category.AGGRO
	return value

func _parse_status_target(value) -> StatusTarget:
	if typeof(value) == TYPE_INT:
		return StatusTarget.values()[int(value)]
	if typeof(value) == TYPE_STRING:
		match value.to_lower():
			"character": return StatusTarget.CHARACTER
			"dice": return StatusTarget.DICE
			"dice_face": return StatusTarget.DICE_FACE
	return value
