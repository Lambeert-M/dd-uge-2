extends Board


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	var bg := $BackgroundSprite as Sprite2D
	size = bg.texture.get_size() * bg.scale
	
	var shift := -(bg.position - size / 2.0) if bg.centered else -bg.position
	for child in get_children():
		if child is Node2D or child is Control:
			child.position += shift
