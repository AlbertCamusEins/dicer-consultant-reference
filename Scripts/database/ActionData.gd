extends Node

class_name ActionData

var action_name: String
var texture_path: String
var effect: String
var is_special: bool = false
var owner_character: String = "" # 如果是特殊行动，记录所属角色
	
func init(data: Dictionary) -> ActionData:
	action_name = data.get("action_name", "")
	texture_path = data.get("texture_path", "")
	effect = data.get("effect", "")
	is_special = data.get("is_special", false)
	owner_character = data.get("owner_character", "")
	return self

static func new_common_action() -> ActionData:
	var action = ActionData.new()
	action.is_special = false
	return action
	
static func new_uncommon_action() -> ActionData:
	var action = ActionData.new()
	action.is_special = true
	return action
