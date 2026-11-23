class_name Board
extends Node2D

# Skriftstørrelser til tekst på papirer (blanketter, regelbogens sider osv.)
const FONT_SIZE := 12
const TITLE_FONT_SIZE := 16
const DRAG_THRESHOLD := 6.0

@export var size := Vector2.ZERO

var clipped: Array[Board] = []
var dragging := false
var last_mouse := Vector2.ZERO
var sprite: Sprite2D
var on_desk := false

var pressed_on_me := false           # museknap er trykket ned over boardet, men trækket er ikke startet
var press_start := Vector2.ZERO

# For icon handling (small sprite when on desk)
var icon_sprite: Sprite2D
var full_size := Vector2.ZERO
var icon_size := Vector2.ZERO
var is_icon := false

# Constructor
func _init(sprite_path := "", sprite_scale := 1.0, icon_path := "", icon_scale := 0.25) -> void:
	if sprite_path != "":
		var tex := load(sprite_path) as Texture2D
		if tex == null:
			push_error("Board: could not load sprite: " + sprite_path)
			return
		sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		add_child(sprite)
		full_size = tex.get_size() * sprite_scale
		sprite.scale *= sprite_scale
		size = full_size
	else:
		print("Sprite path not found")
	if icon_path != "":
		icon_sprite = Sprite2D.new()
		icon_sprite.texture = load(icon_path)
		icon_sprite.centered = false
		icon_sprite.scale *= icon_scale
		icon_size = icon_sprite.texture.get_size() * icon_scale
		icon_sprite.hide()
		add_child(icon_sprite)

func _ready() -> void:
	add_to_group("boards")
	# Hides VBox if it exists, index 2 is VBox
	if get_children().size() == 3:
		get_child(2).hide()

func _input(event: InputEvent) -> void:
	if Global.game_over: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse := get_global_mouse_position()
			if _contains_point(mouse) and _is_topmost_at(mouse):
				pressed_on_me = true
				press_start = mouse
				last_mouse = mouse
			else:
				pressed_on_me = false
				dragging = false
		else:
			pressed_on_me = false
			if dragging:
				_drop()

	elif event is InputEventMouseMotion:
		if pressed_on_me and not dragging:
			var mouse := get_global_mouse_position()
			if mouse.distance_to(press_start) >= DRAG_THRESHOLD:
				dragging = true
				pressed_on_me = false
				last_mouse = mouse
				lift()
				bring_to_front()
				_cancel_gui_press()
		if dragging:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_drop()
				return
			var mouse := get_global_mouse_position()
			var delta := mouse - last_mouse
			last_mouse = mouse
			for b in get_group():
				b.global_position += delta
			_update_icon_mode(mouse)
		if dragging:
			get_viewport().set_input_as_handled()

# Stopper at en knap under musen "trykkes", når vi har besluttet, at det var et træk
func _cancel_gui_press() -> void:
	get_viewport().gui_release_focus()

func _is_topmost_at(point: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("boards"):
		var other := node as Board
		if other == null or other == self:
			continue
		if other._contains_point(point) and other.get_index() > get_index():
			return false
	return true

func _drop() -> void:
	dragging = false
	var target := get_board_under()
	if target and not is_icon:
		clip(target)
	for desk in get_tree().get_nodes_in_group("desks"):
		desk.board_dropped(self)
	var mouse = get_global_mouse_position()
	for customer in get_tree().get_nodes_in_group("customers"):
		customer.board_dropped(self, mouse)

# Musens position i verdens-koordinater, læst fra selve eventet.
# get_global_mouse_position() læser den rigtige cursor, så falske events
# (fx fra TestBot i !DEBUG) ville ellers ikke kunne trække boards.
func _event_position(event: InputEventMouse) -> Vector2:
	return get_canvas_transform().affine_inverse() * event.position

func bring_to_front() -> void:
	var members := get_group()
	members.sort_custom(func(a: Board, b: Board): return a.get_index() < b.get_index())
	for b in members:
		b.get_parent().move_child(b, -1)

func _contains_point(global_point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(to_local(global_point))

# Er punktet over en Control (fx et input-felt), der selv skal have musen?
func _is_over_control(global_point: Vector2) -> bool:
	for node in find_children("*", "Control", true, false):
		var c := node as Control
		if c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and c.get_global_rect().has_point(global_point):
			return true
	return false

# Ligger der et andet board oven på dette punkt? Så er klikket ikke til os.
# Det øverste board markerer ikke klikket som håndteret, når det rammer en
# Control (ellers får Control'en det aldrig), så boards nedenunder skal selv
# lade være med at reagere.
func _is_covered_at(global_point: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("boards"):
		var other := node as Board
		if other != null and other != self and other.is_visible_in_tree() 				and other.is_greater_than(self) and other._contains_point(global_point):
			return true
	return false

# Lav en tekst-label til et papir. Den ignorerer musen, så man stadig kan
# trække papiret ved at tage fat i teksten.
func _make_label(text: String, font_size: int = FONT_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", font_size)
	return label

# Slå et board helt til eller fra. Et slukket board er usynligt, kan ikke
# klikkes eller trækkes og clipper ikke til andre boards.
# Kald den først, når boardet er i scenetræet (_ready slår det til igen).
func set_enabled(enabled: bool) -> void:
	visible = enabled
	set_process_input(enabled)
	if enabled:
		add_to_group("boards")
	else:
		dragging = false
		pressed_on_me = false
		for other in clipped.duplicate():
			unclip(other)
		remove_from_group("boards")

# Byt dette board ud med et andet (samme parent): det andet overtager plads,
# lag og clips, og dette board slås fra.
# Bruges fx når regelbogen bladrer til en side og tilbage igen.
func replace_with(other: Board) -> void:
	var neighbours := clipped.duplicate()
	other.global_position = global_position
	set_enabled(false)
	other.set_enabled(true)
	if other.get_parent() == get_parent():
		# Læg det andet board lige oven på dette i tegne-rækkefølgen
		var target := get_index() if other.get_index() < get_index() else get_index() + 1
		get_parent().move_child(other, target)
	for neighbour in neighbours:
		other.clip(neighbour)

func clip(other: Board) -> void:
	if other == self or other in clipped:
		return
	clipped.append(other)
	other.clipped.append(self)

func unclip(other: Board) -> void:
	clipped.erase(other)
	other.clipped.erase(self)

func lift() -> void:
	var my_index := get_index()
	var group := get_group()

	# Boards above (or equal to) me, reachable from me through overlapping rects.
	var carried: Array[Board] = [self]
	var stack: Array[Board] = [self]
	while not stack.is_empty():
		var current: Board = stack.pop_back()
		for b in group:
			if b in carried or b.get_index() < my_index:
				continue
			if current.get_global_rect().intersects(b.get_global_rect()):
				carried.append(b)
				stack.append(b)

	# Cut every link between carried boards and everything else.
	for a in carried:
		for other in a.clipped.duplicate():
			if other not in carried:
				a.unclip(other)

	# Link carried boards that really touch each other.
	for a in carried:
		for b in carried:
			if a != b and a.get_global_rect().intersects(b.get_global_rect()):
				a.clip(b)

func get_group() -> Array[Board]:
	var seen: Array[Board] = [self]
	var stack: Array[Board] = [self]
	while not stack.is_empty():
		var current: Board = stack.pop_back()
		for neighbor in current.clipped:
			if neighbor not in seen:
				seen.append(neighbor)
				stack.append(neighbor)
	return seen

func get_global_rect() -> Rect2:
	return Rect2(global_position, size)

func get_board_under() -> Board:
	var my_rect := get_global_rect()
	var my_center := my_rect.get_center()
	var best: Board = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("boards"):
		var other := node as Board
		if other == null or other == self or other in get_group():
			continue
		var other_rect := other.get_global_rect()
		if my_rect.intersects(other_rect):
			var d := my_center.distance_squared_to(other_rect.get_center())
			if d < best_dist:
				best_dist = d
				best = other
	return best

func set_icon_mode(on: bool) -> void:
	if on and icon_sprite == null:
		return
	var center := global_position + size / 2.0
	is_icon = on
	sprite.visible = not on
	if icon_sprite:
		icon_sprite.visible = on
	# Som ikon vises kun ikonet: skjul alt andet indhold (tekst, felter, knapper)
	for child in get_children():
		if child != sprite and child != icon_sprite and child is CanvasItem:
			child.visible = not on
	size = icon_size if on else full_size
	global_position = center - size / 2.0

func _update_icon_mode(mouse: Vector2) -> void:
	if icon_sprite == null:
		return
	var over_desk := _is_point_over_desk(mouse)
	if over_desk and not is_icon:
		set_icon_mode(true)
		global_position = mouse - size / 2.0     # icon centered on the cursor
	elif not over_desk and is_icon:
		set_icon_mode(false)
		global_position = mouse - size / 2.0     # full board centered on the cursor
	else:
		return
	last_mouse = mouse

func _is_point_over_desk(point: Vector2) -> bool:
	for desk in get_tree().get_nodes_in_group("desks"):
		if desk.get_global_rect().has_point(point):
			return true
	return false

func _on_placed_off_screen() -> void:
	var off_side: Vector2i
	off_side = get_viewport().size - position
	var closest_point: Vector2
	
	
	position = lerp(position, closest_point, 1)
	pass
