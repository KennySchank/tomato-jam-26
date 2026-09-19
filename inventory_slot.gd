extends Button

var inventory_name := ""
var slot_index := -1
var item: Dictionary = {}
var drop_handler: Callable

func setup(source_inventory: String, source_index: int, slot_item: Dictionary, handler: Callable) -> void:
	inventory_name = source_inventory
	slot_index = source_index
	item = slot_item
	drop_handler = handler

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item.is_empty():
		return null

	var preview := Button.new()
	preview.custom_minimum_size = custom_minimum_size
	preview.text = text
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	return {"inventory_name": inventory_name, "index": slot_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("inventory_name") and data.has("index")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if drop_handler.is_valid():
		drop_handler.call(data["inventory_name"], int(data["index"]), inventory_name, slot_index)
