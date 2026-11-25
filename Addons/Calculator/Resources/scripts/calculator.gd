extends Board

const CALC_ICON_PATH := "res://Addons/Calculator/Resources/images/calc_icon_placeholder.png"
const CALC_ICON_SCALE := 0.25

# En scene kalder _init() uden argumenter, så ikonet sættes her (ligesom rulebook.gd).
# Sprite-stien er tom, fordi baggrunden allerede ligger i scenen (BackgroundSprite).
func _init() -> void:
	super("", 1.0, CALC_ICON_PATH, CALC_ICON_SCALE)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	# Board.set_icon_mode() skjuler/viser `sprite` og bruger `full_size`
	sprite = $BackgroundSprite as Sprite2D
	size = sprite.texture.get_size() * sprite.scale
	full_size = size
	# Board._ready() skjuler barn nr. 2, når der er præcis 3 børn (ment til blanketternes VBox)
	$CalculatorControl.show()

	var shift := -(sprite.position - size / 2.0) if sprite.centered else -sprite.position
	for child in get_children():
		if child == icon_sprite:
			continue                    # ikonet ligger allerede i (0, 0)
		if child is Node2D or child is Control:
			child.position += shift

#extends Board
#
#const CALC_ICON_PATH := "res://Addons/Calculator/Resources/images/calc_icon_placeholder.png"
#const CALC_ICON_SCALE := 0.25
#
# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
#	super()
#	var bg := $BackgroundSprite as Sprite2D
#	size = bg.texture.get_size() * bg.scale
#	
#	var shift := -(bg.position - size / 2.0) if bg.centered else -bg.position
#	for child in get_children():	
#		if child is Node2D or child is Control:
#			child.position += shift
