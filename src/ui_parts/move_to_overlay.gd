extends Control

# Runs every time the mouse moves. Returning true means you can drop the XIDs.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Array[PackedInt32Array]:
		return false
	get_parent().update_proposed_xid()
	for xid in data:
		if XIDUtils.is_parent(xid, Indications.proposed_drop_xid):
			return false
	if Indications.proposed_drop_xid.is_empty():
		return false
	return true

# Runs when you drop the XIDs.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Array[PackedInt32Array]:
		SVG.root_element.move_xnodes_to(data, Indications.proposed_drop_xid)
		SVG.queue_save()
