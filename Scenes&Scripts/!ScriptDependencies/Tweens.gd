extends Node
# Autoload

func wobble(node: CanvasItem) -> void:
	_kill(node, "_rot_tween")
	_kill(node, "_size_tween")

	if not node.has_meta("_base_scale"):
		node.set_meta("_base_scale", node.scale)
	var base: Vector2 = node.get_meta("_base_scale")

	node.scale = base
	node.rotation_degrees = 0.0
	if node is Control:
		node.pivot_offset = node.size / 2.0
	# Node2D roterer/skalerer om sin origin, så der er ingen pivot at sætte

	var rot := rotation_wobble(node)
	var siz := size_wobble(node, base)
	node.set_meta("_rot_tween", rot)
	node.set_meta("_size_tween", siz)

	await rot.finished
	await siz.finished
func bob(node: CanvasItem) -> Tween:
	var tween := node.create_tween()
	var base_pos: Vector2 = node.position
	tween.tween_property(node, "position", base_pos + Vector2(0,10), 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", base_pos, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween
func slow_bob(node: CanvasItem) -> Tween:
	var tween := node.create_tween()
	tween.set_loops(0) # Sets loops to infty
	var base_pos: Vector2 = node.position
	var slow := 2.0
	tween.tween_property(node, "position", base_pos + Vector2(0,10), 0.06 * slow).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", base_pos, 0.45 * slow) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween
func fade(node: CanvasItem, period: float, to_alpha := 0.0) -> Tween:
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", to_alpha, period)
	return tween


func _kill(node: CanvasItem, key: String) -> void:
	if node.has_meta(key):
		var t: Tween = node.get_meta(key)
		if t and t.is_valid():
			t.kill()

func rotation_wobble(node: CanvasItem) -> Tween:
	var tween := node.create_tween()
	tween.tween_property(node, "rotation_degrees", 15.0, 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation_degrees", -12.0, 0.08).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "rotation_degrees", 0.0, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween

func size_wobble(node: CanvasItem, base_scale := Vector2.ONE) -> Tween:
	var tween := node.create_tween()
	tween.tween_property(node, "scale", base_scale * 1.25, 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base_scale * 0.9, 0.08).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", base_scale, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween
