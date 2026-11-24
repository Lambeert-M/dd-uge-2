extends Dialogue
@onready var name_label: Label = %NameLabel

func _refresh() -> void:
	super()                      # sets the text
	name_label.text = speaker
	
