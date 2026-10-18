class_name SNSparkline
extends Control
## Small price-history sparkline. Shows "样本不足" until at least two samples exist.

var values: Array = []
var line_color: Color = Color("e1c487")


func _ready() -> void:
	custom_minimum_size = Vector2(64, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(prices: Array, color: Color = Color("e1c487")) -> void:
	values = prices
	line_color = color
	queue_redraw()


func _draw() -> void:
	if values.size() < 2:
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, 16), "样本不足", HORIZONTAL_ALIGNMENT_LEFT, 64.0, 9, Color("6f8079"))
		return
	var minimum := float(values[0])
	var maximum := float(values[0])
	for value in values:
		minimum = minf(minimum, float(value))
		maximum = maxf(maximum, float(value))
	var span := maxf(1.0, maximum - minimum)
	var points := PackedVector2Array()
	for index in values.size():
		var x := size.x * float(index) / float(values.size() - 1)
		var y := size.y - ((float(values[index]) - minimum) / span) * (size.y - 3.0) - 1.5
		points.append(Vector2(x, y))
	draw_polyline(points, line_color, 1.8, true)
	draw_circle(points[points.size() - 1], 2.2, line_color)
