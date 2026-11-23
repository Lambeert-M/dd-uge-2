extends Area2D

signal board_placed(board: Board)   # emitted when a board is dropped on the desk

@onready var sprite := $Sprite2D
@onready var shape_node: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("desks")

# Desk rectangle in global space (assumes no rotation)
func get_global_rect() -> Rect2:
	var rect_shape := shape_node.shape as RectangleShape2D
	var s := rect_shape.size * shape_node.global_scale
	return Rect2(shape_node.global_position - s / 2.0, s)

# Called by Board._drop()
func board_dropped(board: Board) -> void:
	var over := get_global_rect().has_point(board.get_global_rect().get_center())
	if over:
		board_placed.emit(board)
	board.on_desk = over

# offset is measured from the desk's center to the new board's center
func spawn_board(board_texture_path: String, offset: Vector2, board_scale := 1.0,
		icon_path := "", icon_scale := 0.25) -> Board:
	return place_board(Board.new(board_texture_path, board_scale, icon_path, icon_scale), offset)

func place_board(new_board: Board, offset := Vector2.ZERO) -> Board:
	get_parent().add_child(new_board)          # same parent as other boards, so stacking works
	if new_board.icon_sprite:                  # only boards with an icon start as one
		new_board.set_icon_mode(true)
	var center := get_global_rect().get_center() + offset
	new_board.global_position = center - new_board.size / 2.0
	new_board.on_desk = get_global_rect().has_point(center)
	return new_board

func fit_area_to_sprite() -> void:
	if sprite.texture == null:
		return
	var rect_shape := RectangleShape2D.new()     # ny shape, så den ikke deles mellem instanser
	rect_shape.size = sprite.texture.get_size() * sprite.scale
	shape_node.shape = rect_shape
	# Placér formens midte i spritens midte
	var sprite_center: Vector2 = sprite.position
	if not sprite.centered:
		sprite_center += rect_shape.size / 2.0
	shape_node.position = sprite_center + sprite.offset * sprite.scale

# Placér og dimensionér skrivebordet. top_left og target_size er i pixels.
func set_rect(top_left: Vector2, target_size: Vector2) -> void:
	# Spriten strækkes til målstørrelsen og lægges i hjørnet
	sprite.centered = false
	sprite.scale = target_size / sprite.texture.get_size()
	sprite.position = Vector2.ZERO
	global_position = top_left

	# Collision-formen dækker præcis samme rektangel
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = target_size
	shape_node.shape = rect_shape
	shape_node.position = target_size / 2.0   # formens midte = rektanglets midte
	print("desk global_pos:", global_position, " sprite scale:", sprite.scale,
	" tex:", sprite.texture.get_size(), " target:", target_size)
