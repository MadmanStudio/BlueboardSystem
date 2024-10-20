@tool
extends Control
class_name ElementComponent


signal detached(element: Node2D)
signal core_filled(type: Electricity.Type)
signal rotated


var id: String
var detachable: bool = false
var current_deg: int = 0
var fixed_deg: int = 0
var installed_coords: Vector2i

enum Direction
{
	UP, RIGHT, DOWN, LEFT
}

# 每个电路允许输入的电力类型
# 如果电路不支持该电力类型，则无法在该电路上输入或输出电力
# 对于一个电路，只有二种情况：允许全部类型（ALL），允许单一类型
# 这个枚举的类型定义位置十分关键，前面的类型顺序必须时刻与 Electricity.Type 保持同步
enum AllowInputType
{
	RED, BLUE, YELLOW, PURPLE, ORANGE, GREEN, WHITE, ALL
}

@export var surface_texture: Texture2D:
	set(new_texture):
		surface_texture = new_texture
		$Control/Surface.texture = new_texture

# 当前元件的四个电路的数据，在元件被顺时针旋转后进行滚动
# 按照下标依次为：上，右，下，左
@export var line_inputable_array: Array[bool] = [true, true, true, true]
@export var line_outputable_array: Array[bool] = [true, true, true, true]
@export var line_allow_input_type_array: Array[AllowInputType] = [
	AllowInputType.ALL, AllowInputType.ALL,
	AllowInputType.ALL, AllowInputType.ALL
]
@export var line_output_type_array: Array[Electricity.Type] = [
	Electricity.Type.RED, Electricity.Type.RED,
	Electricity.Type.RED, Electricity.Type.RED
]
@export var rotatable: bool = false

@onready var e1: Electricity = $Electricity1
@onready var e2: Electricity = $Electricity2
@onready var e3: Electricity = $Electricity3
@onready var e4: Electricity = $Electricity4
@onready var electricity_array: Array[Electricity] = [e1, e2, e3, e4]
var line_outputting_array: Array[bool] = [false, false, false, false]
var line_inputting_array: Array[bool] = [false, false, false, false]
	
	
func fill_core(from_dir: Direction, electricity_type: Electricity.Type) -> void:
	core_filled.emit(electricity_type)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property($Control/Core, "color", Tables.ElectricityColorTable.get(electricity_type), 0.1).set_ease(Tween.EASE_IN)
	for dir: Direction in Direction.values():
		if dir == from_dir:
			continue
		output_electricity(dir)


func clear_core() -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_property($Control/Core, "color", Tables.ElectricityColorTable.get(Electricity.Type.WHITE), 0.1).set_ease(Tween.EASE_IN)


func output_electricity(dir: Direction, switch_flowing_color: bool = false) -> void:
	if line_outputable_array[dir] == false:
		return
	line_outputting_array[dir] = true
	electricity_array[dir].output(line_output_type_array[dir], switch_flowing_color)
	line_outputting_array[dir] = true
	
	
func output_electricity_with_type(type: Electricity.Type, dir: Direction, switch_flowing_color: bool = false) -> void:
	if line_outputable_array[dir] == false:
		return
	line_outputting_array[dir] = true
	electricity_array[dir].output(type, switch_flowing_color)
	line_outputting_array[dir] = true
	
	
func input_electricity(type: Electricity.Type, dir: Direction, switch_flowing_color: bool = false) -> void:
	if line_inputable_array[dir] == false:
		return
	if check_line_allow_input_type(type, dir) == false:
		return
	line_inputting_array[dir] = true
	electricity_array[dir].input(type, switch_flowing_color)
	await get_tree().create_timer(0.4).timeout
	fill_core(dir, type)
	
	
func vanish_electricity() -> void:
	clear_core()
	for electricity: Electricity in electricity_array:
		electricity.vanish()
	for dir: Direction in Direction.values():
		line_inputting_array[dir] = false
		line_outputting_array[dir] = false
	
	
func check_line_allow_input_type(type: Electricity.Type, dir: Direction) -> bool:
	if line_allow_input_type_array[dir] == AllowInputType.ALL:
		return true
	if line_allow_input_type_array[dir] == type:
		return true
	else:
		return false
		
		
func rotate(deg: int, with_anim: bool = false) -> void:
	if with_anim:
		z_index = 100
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(self, "scale", Vector2.ONE * 1.2, 0.1).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(self, "rotation", deg_to_rad(deg), 0.1)
		tween.chain().tween_property(self, "scale", Vector2.ONE * 1.0, 0.1).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void: z_index = 0)
	else:
		rotation = deg_to_rad(deg)
	$Control/Disdetachabled.rotation -= rotation
	var step = 0
	if fixed_deg == 90:
		step = 1
	elif fixed_deg == 180:
		step = 2
	elif fixed_deg == 270:
		step = 3
	roll_array(line_inputable_array, step)
	roll_array(line_outputable_array, step)
	roll_array(line_allow_input_type_array, step)
	roll_array(line_output_type_array, step)
	roll_array(electricity_array, step)
	roll_array(line_outputting_array, step)
	roll_array(line_inputting_array, step)
	rotated.emit()
	
	
func roll_array(in_array: Array, step: int) -> void:
	var length: int = in_array.size()
	var temp_arr: Array = in_array.duplicate()
	for i in range(length):
		var idx: int = (i + step) % length
		temp_arr[i] = in_array[idx]
	for i in range(length):
		in_array[i] = temp_arr[i]


func detach() -> void:
	detached.emit(owner)


func hint_disdetachabled() -> void:
	$Control/Disdetachabled/AnimationPlayer.play("Disdetachabled")


func rotate_90deg() -> void:
	current_deg += 90
	fixed_deg += 90
	if fixed_deg == 360:
		fixed_deg = 0
	rotate(current_deg, true)


func _on_button_gui_input(event: InputEvent) -> void:
	var local_mouse_position: Vector2 = $Control/Button.get_local_mouse_position()
	var button_size: Vector2 = $Control/Button.size
	if local_mouse_position.x >= 0 and local_mouse_position.x <= button_size.x and \
	local_mouse_position.y >= 0 and local_mouse_position.y <= button_size.y:
		pass
	else:
		return
		
	if event is InputEventMouseButton and event.is_released():
		if event.button_index == MOUSE_BUTTON_LEFT:
			if rotatable:
				rotate_90deg()
			else:
				hint_disdetachabled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if detachable:
				detach()
			else:
				hint_disdetachabled()
				
				
func is_inputting(dir: Direction) -> bool:
	return line_inputting_array[dir]
	
	
func is_outputting(dir: Direction) -> bool:
	return line_outputting_array[dir]
	
	
func is_inputable(dir: Direction) -> bool:
	return line_inputable_array[dir]
	
	
func is_outputable(dir: Direction) -> bool:
	return line_outputable_array[dir]


func get_allow_input_type(dir: Direction) -> AllowInputType:
	return line_allow_input_type_array[dir]
	
	
func get_output_type(dir: Direction) -> Electricity.Type:
	return line_output_type_array[dir]
