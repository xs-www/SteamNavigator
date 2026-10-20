class_name Landmass
extends RefCounted
## @static-doc
## 作用：表示世界地图中的陆地多边形，支持大陆、大岛、小岛、环礁四种原型。
##
## ## 契约与约束
## - 多边形顶点顺序必须一致（全顺时针或全逆时针）。
## - 海岸线采样假设多边形闭合，首尾顶点相连。
## - 面积计算使用绝对值，结果始终为正数。
## @end-static-doc

enum Archetype {
	CONTINENT,
	LARGE_ISLAND,
	SMALL_ISLAND,
	ATOLL,
}

var id: String
var polygon: PackedVector2Array
var archetype: Archetype
var region_id: String


func _init(p_id: String = "", p_polygon: PackedVector2Array = PackedVector2Array(), p_archetype: Archetype = Archetype.SMALL_ISLAND, p_region_id: String = "") -> void:
	id = p_id
	polygon = p_polygon
	archetype = p_archetype
	region_id = p_region_id


func is_empty() -> bool:
	return id.is_empty() or polygon.is_empty()


func area() -> float:
	if polygon.size() < 3:
		return 0.0
	var total := 0.0
	for i in polygon.size():
		var j := (i + 1) % polygon.size()
		total += polygon[i].x * polygon[j].y
		total -= polygon[j].x * polygon[i].y
	return absf(total) * 0.5


func centroid() -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for point in polygon:
		sum += point
	return sum / float(polygon.size())


func bounding_box() -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_pt := polygon[0]
	var max_pt := polygon[0]
	for point in polygon:
		min_pt.x = minf(min_pt.x, point.x)
		min_pt.y = minf(min_pt.y, point.y)
		max_pt.x = maxf(max_pt.x, point.x)
		max_pt.y = maxf(max_pt.y, point.y)
	return Rect2(min_pt, max_pt - min_pt)


func contains_point(point: Vector2) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	var j := polygon.size() - 1
	for i in polygon.size():
		var xi := polygon[i].x
		var yi := polygon[i].y
		var xj := polygon[j].x
		var yj := polygon[j].y
		if ((yi > point.y) != (yj > point.y)) and (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi):
			inside = not inside
		j = i
	return inside


func coastline_length() -> float:
	if polygon.size() < 2:
		return 0.0
	var length := 0.0
	for i in polygon.size():
		var j := (i + 1) % polygon.size()
		length += polygon[i].distance_to(polygon[j])
	return length


func sample_coastline(t: float) -> Vector2:
	if polygon.size() < 2:
		return Vector2.ZERO
	t = clampf(t, 0.0, 1.0)
	var total_length := coastline_length()
	var target_length := t * total_length
	var accumulated := 0.0
	for i in polygon.size():
		var j := (i + 1) % polygon.size()
		var segment_length := polygon[i].distance_to(polygon[j])
		if accumulated + segment_length >= target_length:
			var segment_t := (target_length - accumulated) / segment_length if segment_length > 0.0 else 0.0
			return polygon[i].lerp(polygon[j], segment_t)
		accumulated += segment_length
	return polygon[polygon.size() - 1]


func to_dict() -> Dictionary:
	var polygon_array := []
	for point in polygon:
		polygon_array.append({"x": point.x, "y": point.y})
	return {
		"id": id,
		"polygon": polygon_array,
		"archetype": Archetype.keys()[archetype],
		"region_id": region_id,
	}


static func from_dict(value: Dictionary) -> Landmass:
	var polygon := PackedVector2Array()
	for point_dict in value.get("polygon", []):
		if point_dict is Dictionary:
			polygon.append(Vector2(float(point_dict.get("x", 0.0)), float(point_dict.get("y", 0.0))))
	var archetype_name := String(value.get("archetype", "SMALL_ISLAND"))
	var archetype_index := Archetype.keys().find(archetype_name)
	var archetype: Archetype = Archetype.SMALL_ISLAND if archetype_index < 0 else archetype_index as Archetype
	return Landmass.new(
		String(value.get("id", "")),
		polygon,
		archetype,
		String(value.get("region_id", ""))
	)
