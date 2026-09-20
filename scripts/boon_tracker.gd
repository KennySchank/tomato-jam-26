extends CanvasLayer

## Displays every boon the player has picked this run as a row of icons in the
## upper-left corner. The icon is the boon card's "Item Image" texture; hover
## a slot to see a tooltip built from the card's "Item Name" + "Item Description"
## labels. New boons are appended when `GameState.boon_activated` fires.

const ICON_SIZE := Vector2(40, 40)
## Padding around the Slots rect used to size the translucent backdrop panel.
const BACKDROP_PADDING := Vector2(8, 6)
## Semi-transparent dark fill so the boon icons pop against the game world.
const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.45)

@onready var slots: HBoxContainer = $Slots
@onready var game_state: Node = get_node("/root/GameState")

var _backdrop: ColorRect

func _ready() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = BACKDROP_COLOR
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Insert before Slots so it draws behind the icons but still inside the
	# CanvasLayer's coordinate space.
	add_child(_backdrop)
	move_child(_backdrop, slots.get_index())
	# `sort_children` fires after HBoxContainer lays out its children, which is
	# when we can trust their `position`/`size` values. `resized` alone won't
	# fire because the container has a fixed authored size.
	slots.sort_children.connect(_sync_backdrop)
	slots.resized.connect(_sync_backdrop)
	game_state.boon_activated.connect(_on_boon_activated)
	game_state.boon_deactivated.connect(_on_boon_deactivated)
	# Rebuild in case boons were granted before this node entered the tree
	# (e.g. debug starting boons are applied via call_deferred in main.gd, so
	# in practice we'll receive their signals — but rebuild anyway to be safe
	# after a scene reload).
	_rebuild()
	_sync_backdrop()

## Position and size the translucent backdrop so it hugs only the actual icon
## row \u2014 not the full Slots container, which is a wide right-aligned
## HBoxContainer that always reports the full canvas width. Called whenever
## the row's size changes (icons added / removed) and once during `_ready`.
func _sync_backdrop() -> void:
	if _backdrop == null or slots == null:
		return
	var slot_count: int = slots.get_child_count()
	# Hide the backdrop entirely when no boons have been picked yet so we
	# don't paint a floating rectangle over the game world.
	_backdrop.visible = slot_count > 0
	if slot_count == 0:
		return
	# Union every visible child's rect to find the actual icons' bounding box
	# inside the container, then convert to the CanvasLayer's coordinate
	# space by adding the container's position.
	var union: Rect2 = Rect2()
	var have_any := false
	for child in slots.get_children():
		if child is Control and (child as Control).visible:
			var child_rect := Rect2((child as Control).position, (child as Control).size)
			if have_any:
				union = union.merge(child_rect)
			else:
				union = child_rect
				have_any = true
	if not have_any:
		_backdrop.visible = false
		return
	union.position += slots.position
	_backdrop.position = union.position - BACKDROP_PADDING
	_backdrop.size = union.size + BACKDROP_PADDING * 2.0

func _rebuild() -> void:
	for child in slots.get_children():
		child.queue_free()
	for boon_id in game_state.active_boons.keys():
		_add_icon(boon_id)
	call_deferred("_sync_backdrop")

func _on_boon_activated(boon_id: String) -> void:
	_add_icon(boon_id)
	call_deferred("_sync_backdrop")

## Remove the tracker icon for a boon that just got exhausted / consumed.
## Icons store their boon id in metadata (node names strip `:` and `/`, so
## the id can't be a NodePath key).
func _on_boon_deactivated(boon_id: String) -> void:
	for child in slots.get_children():
		if child.has_meta("boon_id") and String(child.get_meta("boon_id")) == boon_id:
			child.queue_free()
			break
	call_deferred("_sync_backdrop")

func _add_icon(boon_id: String) -> void:
	var info := _extract_card_info(boon_id)
	if info.is_empty():
		return
	var icon := TextureRect.new()
	# Tag the icon with its boon id so `_on_boon_deactivated` can find and
	# remove it. We can't use `name` because Godot strips `:` and `/`.
	icon.set_meta("boon_id", boon_id)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# STRETCH_SCALE forces every icon to fill the exact 40x40 box regardless
	# of the source sprite's native dimensions, so a tiny 16x16 sprite and a
	# large 128x128 sprite render at identical visible sizes in the tracker.
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture = info.get("texture")
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.tooltip_text = "%s\n%s" % [info.get("title", ""), info.get("description", "")]
	slots.add_child(icon)

## Instantiates the boon's scene off-tree just long enough to read the card's
## authored title / description / icon texture, then frees it. Returns an
## empty dictionary if anything is missing so the caller can bail cleanly.
func _extract_card_info(boon_id: String) -> Dictionary:
	var packed: PackedScene = load(boon_id)
	if packed == null:
		push_warning("BoonTracker: could not load boon scene %s" % boon_id)
		return {}
	var instance: Node = packed.instantiate()
	var info: Dictionary = {}
	var name_label: Label = instance.find_child("Item Name", true, false) as Label
	var desc_label: Label = instance.find_child("Item Description", true, false) as Label
	var image_sprite: Sprite2D = instance.find_child("Item Image", true, false) as Sprite2D
	if name_label != null:
		info["title"] = name_label.text
	if desc_label != null:
		info["description"] = desc_label.text
	if image_sprite != null:
		info["texture"] = _texture_from_sprite(image_sprite)
	# The scene was never added to the tree, so `_ready` didn't fire; `free`
	# is safe and immediate.
	instance.free()
	return info

## Boon card `Item Image` nodes are `Sprite2D`s that often use `region_enabled`
## + `region_rect` to pull one icon out of a shared spritesheet. `TextureRect`
## has no equivalent property, so wrap the source in an `AtlasTexture` that
## crops to the same region.
func _texture_from_sprite(sprite: Sprite2D) -> Texture2D:
	if sprite.texture == null:
		return null
	if not sprite.region_enabled or sprite.region_rect.size == Vector2.ZERO:
		return sprite.texture
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite.texture
	atlas.region = sprite.region_rect
	atlas.filter_clip = true
	return atlas
