extends Node3D
class_name CargoCrate

signal pickup_ready(crate: CargoCrate)
signal pickup_exit(crate: CargoCrate)

@export var crate_id: int = 0
var is_collected: bool = false
var initial_position: Vector3 = Vector3.ZERO

@onready var mesh_root: Node3D = $MeshRoot
@onready var highlight_mesh: MeshInstance3D = $MeshRoot/HighlightMesh
@onready var area_3d: Area3D = $Area3D

var is_highlighted: bool = false
var pulse_time: float = 0.0

func _ready() -> void:
	initial_position = global_position
	if highlight_mesh:
		highlight_mesh.visible = false

func _process(delta: float) -> void:
	if is_collected:
		return
	if is_highlighted and highlight_mesh:
		pulse_time += delta * 4.0
		var s = 1.0 + sin(pulse_time) * 0.05
		highlight_mesh.scale = Vector3(s, s, s)

func set_highlight(active: bool) -> void:
	is_highlighted = active
	if highlight_mesh:
		highlight_mesh.visible = active
		if not active:
			highlight_mesh.scale = Vector3.ONE

func collect() -> void:
	is_collected = true
	visible = false
	if area_3d:
		area_3d.monitoring = false
		area_3d.monitorable = false

func reset_crate(pos: Vector3) -> void:
	is_collected = false
	visible = true
	global_position = pos
	initial_position = pos
	set_highlight(false)
	if area_3d:
		area_3d.monitoring = true
		area_3d.monitorable = true
