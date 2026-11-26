extends Control

# Onready Variables
@onready var btnContainer = get_node("Screen/Button_container/OperationBtn_container")
@onready var memScrollContainer = get_node("memory_pnl/memScrollContainer/VBoxContainer")
@onready var workArea = get_node("Screen/HBoxContainer/WorkArea_container/work_lbl")
@onready var prevWorkArea = get_node("Screen/HBoxContainer/WorkArea_container/prevWork_lbl")
@onready var history_pnl = get_node("history_pnl")
@onready var memory_pnl = get_node("memory_pnl")
@onready var overlay = get_node("overlay")
@onready var copyBtn = get_node("copy_btn")

# Variables
var has_been_used = false
var operator = "" #stores the current working operator
var first_num : float #stores the first number
var second_num : float #stores the second number
var memory : Array = [] #stores number to Memory
var history : Array = [] #stores calculation history
var animation_type = Tween.TRANS_CIRC #sets global tweening style
var animation_speed : float = 0.25 #sets global tween speed

# Resource Variables
var memoryCell_res : Resource = preload("res://Addons/Calculator/Resources/scenes/memory_cell.tscn")


func _ready():
	# Connect number buttons to _numButtons()
	for btn in btnContainer.get_children():
		if btn.name.is_valid_int():
			btn.pressed.connect(Callable(self, "_numButtons").bind(btn))
	
	copyBtn.pressed.connect(_on_copy_btn_pressed)
	await get_tree().process_frame
	_place_copy_button()

func _place_copy_button() -> void:
	var rect: Rect2 = workArea.get_global_rect()
	var parent := copyBtn.get_parent() as Control
	copyBtn.position = parent.get_global_transform().affine_inverse() * Vector2(rect.position.x, rect.end.y)
	copyBtn.expand_icon = true
	copyBtn.custom_minimum_size = Vector2(40, 30)
	copyBtn.size = Vector2(40, 30)
	copyBtn.position += Vector2(0, -50)

#----------------------------------------------------------------
# All number buttons are connected to this function via a signal.
# When pressed, the button gets the number string it has and 
# sends it to the "work area" / screen.
# This is to reduce code complexity. 
#----------------------------------------------------------------
func _numButtons(btn):
	# to replace zero if no calculation has been done
	if has_been_used == false:
		workArea.text = btn.name
		has_been_used = true
	else:
		workArea.text += btn.name


# Clears both screens
func _on_clear_btn_pressed():
	workArea.text = "0"
	prevWorkArea.text = ""
	has_been_used = false


# Clears the base work area if a final answer is not given
func _on_clear_eq_btn_pressed():
	if has_been_used == true:
		workArea.text = "0"
		has_been_used = false
	else:
		# Called the clear button function to reduce code repitition
		_on_clear_btn_pressed()


#----------------------------------------------------------------
# If the work area has not been used, clear the previous work area
# else, delete singular characters until the last
# then replace with "0"
#----------------------------------------------------------------
func _on_delete_btn_pressed():
	if has_been_used == true:
		if workArea.text.length() >= 2:
			workArea.text = workArea.text.left(-1)
		else:
			# if the last number is removed, restore the screen to a cleared state
			workArea.text = "0"
			has_been_used = false


#----------------------------------------------------------------
# Sets has been  used to false after solving a problem
# this is to clear the screen with new numbers.
#----------------------------------------------------------------
func _on_equals_btn_pressed():
	has_been_used = false
	# Stores the result of the equation
	var result : float
	# Stores the second number
	second_num = workArea.text.to_float()
	# Add error Protection later
	
	if operator == "+":
		result = first_num + second_num
	elif operator == "-":
		result = first_num - second_num
	elif operator == "*":
		result = first_num * second_num
	elif operator == "/":
		result = first_num / second_num
	
	# Shows operation on the previous work area
	prevWorkArea.text = str(first_num) + " " + operator + " " + str(second_num) + " ="
	# Show the final output
	workArea.text = str(result)
	
	# Store the result in the history dictionary if there are no errors
	history.append([prevWorkArea.text, workArea.text])


#----------------------------------------------------------------
# Sets has been used to false after solving a problem
# this is to clear the screen with new numbers.
#----------------------------------------------------------------
func _on_plus_btn_pressed():
	has_been_used = false
	# Stores first number
	first_num = workArea.text.to_float()
	# Stores the operator
	operator = "+"
	# Shows the output on the previous 
	prevWorkArea.text = str(first_num) + " " + operator


func _on_minus_btn_pressed():
	has_been_used = false
	# Stores first number
	first_num = workArea.text.to_float()
	# Stores the operator
	operator = "-"
	# Shows the output on the previous 
	prevWorkArea.text = str(first_num) + " " + operator


func _on_multiply_btn_pressed():
	has_been_used = false
	# Stores first number
	first_num = workArea.text.to_float()
	# Stores the operator
	operator = "*"
	# Shows the output on the previous 
	prevWorkArea.text = str(first_num) + " " + operator


func _on_divide_btn_pressed():
	has_been_used = false
	# Stores first number
	first_num = workArea.text.to_float()
	# Stores the operator
	operator = "/"
	# Shows the output on the previous 
	prevWorkArea.text = str(first_num) + " " + operator


func _on_square_btn_pressed():
	has_been_used = false
	# Stores the result of the equation
	var result : float
	# Stores first number
	first_num = workArea.text.to_float()
	# Square the number
	result = first_num ** 2
	# Show the equation on the previous work area
	# Does not work exactly like the default app
	# May be changed later with history
	prevWorkArea.text = "sqr(" + workArea.text + ")"
	# Show the final result
	workArea.text = str(result)


func _on_square_root_btn_pressed():
	has_been_used = false
	# Stores the result of the equation
	var result : float
	# Stores first number
	first_num = workArea.text.to_float()
	# Root the number
	result = sqrt(first_num)
	# Show the equation on the previous work area
	# Does not work exactly like the default app
	# May be changed later
	prevWorkArea.text = "√(" + workArea.text + ")"
	# Show the final result
	workArea.text = str(result)


func _on_fraction_btn_pressed():
	has_been_used = false
	# Stores the result of the equation
	var result : float
	# Stores first number
	first_num = workArea.text.to_float()
	# Fraction the number
	result = 1 / first_num
	# Show the equation on the previous work area
	# Does not work exactly like the default app
	# May be changed later
	prevWorkArea.text = "1/(" + workArea.text + ")"
	# Show the final result
	workArea.text = str(result)


func _on_negate_btn_pressed():
	has_been_used = false
	# Stores the result of the equation
	var result : float
	# Stores first number
	first_num = workArea.text.to_float()
	# Fraction the number
	result = - first_num
	# Show the equation on the previous work area
	# Does not work exactly like the default app
	# May be changed later
	prevWorkArea.text = "negate(" + workArea.text + ")"
	# Show the final result
	workArea.text = str(result)


func _on_period_btn_pressed():
	# It just works like this in the official app
	if has_been_used == true:
		workArea.text = workArea.text + "."
	else:
		workArea.text = "0."
		has_been_used = true


func _on_copy_btn_pressed():
	var value: float = workArea.text.to_float()
	DisplayServer.clipboard_set("%.2f" % value)

#----------------------------------------------------------------
# Make the memory panel visible
# Animate the panel size to the size of the numpad
# this is done to work with different monitor heights
#----------------------------------------------------------------



#----------------------------------------------------------------
# Appears with custom popups
# Causes popups to close once clicked
#----------------------------------------------------------------
func _on_overlay_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1:
			# Wait for hide animation to finish
			await reset_popups()
			overlay.visible = false


# resets all popups
func reset_popups():
	for popup in get_tree().get_nodes_in_group("popup"):
		var tween = get_tree().create_tween() #tween to animate GUI
		tween.tween_property(popup, "custom_minimum_size", Vector2(0,0), animation_speed / 2).set_trans(animation_type)
		# Wait for hide animation to finish
		await  tween.finished
		popup.visible = false


#----------------------------------------------------------------
# Memory cell functions
# The instanced signals are connected to these functions
#----------------------------------------------------------------
