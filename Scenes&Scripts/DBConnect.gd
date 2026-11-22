extends Node2D

func _ready() -> void:
	print("Ready")
	await select_users()


func select_users() -> void:
	print("1: Started")
	var query = SupabaseQuery.new().from("Users").select()
	print("2: Query created: ", query)

	var task = await Supabase.database.query(query).completed

	print("3: Task: ", task)
	print("4: Error: ", task.error)
	print("5: Data: ", task.data)

	if task.error != null:
		print("Query failed!")
		return

	print("Query succeeded!")
	if task.data is Array and not task.data.is_empty():
		print(task.data[0])
	else: 
		print("no rows")
	# Testing
	print(typeof(task.data[0]))
