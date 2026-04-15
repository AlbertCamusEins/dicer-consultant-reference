extends Node

class_name ItemData

enum ItemType {
	PASSIVE,    # 被动道具：获得即生效，或在特定时机自动触发
	ACTIVE,     # 主动道具：需要点击使用
	CONSUMABLE  # 消耗品：使用一次后消失
}

enum ChargeType {
	NONE,
	RALLY,
	TICK
}

var item_id: String
var item_name: String
var display_name_key: String = ""
var description_key: String = ""
var type: ItemType
var description: String
var texture_path: String
var price: int

# 功能数据
var effect_id: String        # 效果ID
var effect_params: Dictionary # 效果参数
var max_uses: int = -1       # 使用次数限制（-1代表无限）
var current_uses: int        # 当前剩余次数

# 充能数据
var charge_type: ChargeType = ChargeType.NONE
var max_charge: int = 0
var current_charge: int = 0

static func _coerce_int(value, default_value: int = 0) -> int:
	if typeof(value) == TYPE_NIL:
		return default_value
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		var text = value.strip_edges()
		if text == "":
			return default_value
		if text.is_valid_int():
			return int(text)
		if text.is_valid_float():
			return int(float(text))
	return default_value

func init(data: Dictionary) -> ItemData:
	item_id = data.get("item_id", "")
	display_name_key = str(data.get("display_name_key", ""))
	description_key = str(data.get("description_key", ""))
	item_name = data.get("item_name", "")
	type = _coerce_int(data.get("type", ItemType.CONSUMABLE), ItemType.CONSUMABLE)
	description = data.get("description", "")
	texture_path = data.get("texture_path", "")
	price = _coerce_int(data.get("price", 0), 0)
	
	effect_id = data.get("effect_id", "")
	effect_params = data.get("effect_params", {})
	max_uses = _coerce_int(data.get("max_uses", -1), -1)
	current_uses = _coerce_int(data.get("current_uses", max_uses), max_uses)
	
	charge_type = _coerce_int(data.get("charge_type", ChargeType.NONE), ChargeType.NONE)
	max_charge = _coerce_int(data.get("max_charge", 0), 0)
	current_charge = _coerce_int(data.get("current_charge", 0), 0)
	
	return self

func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"display_name_key": display_name_key,
		"description_key": description_key,
		"item_name": item_name,
		"type": type,
		"description": description,
		"texture_path": texture_path,
		"price": price,
		"effect_id": effect_id,
		"effect_params": effect_params,
		"max_uses": max_uses,
		"current_uses": current_uses,
		"charge_type": charge_type,
		"max_charge": max_charge,
		"current_charge": current_charge
	}

func from_dict(data: Dictionary) -> void:
	init(data)
