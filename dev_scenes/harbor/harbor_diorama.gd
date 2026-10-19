extends Node3D
## 港口样片场景：统一把码头石墙压暗，配合黄昏逆光调色。
##
## 道具和码头都直接复用 assets/models 下的 GLB，导入材质是共享资源，不能在
## 场景里逐个改内部节点；这里在运行时给石墙表面套一层更暗的复制材质，
## 只影响本场景，不改动 GLB 与其它场景。

const STONE_ALBEDO := Color(0.22, 0.21, 0.19)
const STONE_ROUGHNESS := 0.92
## SN_Dock_Wall 的第 0 个表面是 SN_Stone。
const STONE_SURFACE := 0

var _stone_material: StandardMaterial3D


func _ready() -> void:
	_stone_material = StandardMaterial3D.new()
	_stone_material.albedo_color = STONE_ALBEDO
	_stone_material.roughness = STONE_ROUGHNESS
	_stone_material.metallic = 0.0
	_darken_wall_row(get_node("World/Quay"))
	_darken_wall_row(get_node("World/BackWall"))


func _darken_wall_row(row: Node) -> void:
	for item in row.get_children():
		for child in item.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).set_surface_override_material(STONE_SURFACE, _stone_material)
