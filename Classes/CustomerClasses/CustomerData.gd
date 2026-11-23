class_name CustomerData
extends RefCounted

var string_data: PackedStringArray
var view_index: int = 0

func _init(raw_lines: PackedStringArray) -> void:
	# Clean once: strip whitespace/\r and drop empty lines
	for l in raw_lines:
		var clean := l.strip_edges()
		if clean != "":
			string_data.append(clean)

func is_key(line: String) -> bool:
	return line.begins_with("[") and line.ends_with("]") and not is_sub_key(line)

func is_sub_key(line: String) -> bool:
	return line.begins_with("[") and line.ends_with("]") \
		and line.substr(1, line.length() - 2).is_valid_int()

func find_key_index(key: String) -> int:
	for i in string_data.size():
		if string_data[i] == key:
			return i
	return -1

func read_section(key: String) -> PackedStringArray:
	var result := PackedStringArray()
	var start := find_key_index(key)
	if start == -1:
		push_error("Key not found: " + key)
		return result
	for i in range(start + 1, string_data.size()):
		if is_key(string_data[i]):   # næste sektion
			break
		if is_sub_key(string_data[i]):
			continue
		result.append(string_data[i])
	return result

func read_line(key: String, line_number: int) -> String:
	var start := find_key_index(key)
	if start == -1:
		push_error("Key not found: " + key)
		return ""
	if line_number < 0:
		return ""
	for i in range(start + 1, string_data.size()):
		if is_key(string_data[i]):      # reached the next section
			return ""
		if i - start - 1 == line_number:
			return string_data[i]
	return ""    

func read_variants(key: String) -> Array[PackedStringArray]:
	var variants: Array[PackedStringArray] = []
	var start := find_key_index(key)
	if start == -1:
		push_error("Key not found: " + key)
		return variants
	var current := PackedStringArray()
	for i in range(start + 1, string_data.size()):
		var line := string_data[i]
		if is_key(line):
			break
		if is_sub_key(line):
			if not current.is_empty():
				variants.append(current)
			current = PackedStringArray()
		else:
			current.append(line)
	if not current.is_empty():
		variants.append(current)      # tomme varianter (fx en tom [2]) tæller ikke med
	return variants
