class_name SNSparkline
extends Control
## @static-doc
## 作用：市场价格历史迷你折线；只有两个以上真实样本才绘制。
##
## Small price-history sparkline. Shows "样本不足" until at least two samples exist.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 折线 / 端点颜色由调用页面按趋势传入；未传色时默认取
##   `SNSkin.color("brass.highlight")`，占位文案取 `SNSkin.color("text.muted")`。
##   文件内不写十六进制颜色，`Color.TRANSPARENT` 只作为「未指定颜色」的哨兵。
## - 尺寸约束：`custom_minimum_size = (64, 24)`、线宽 1.8、端点 2.2、占位字号 9
##   与 `set_values(prices: Array, color: Color)` 调用签名保持不变（调用方可继续传色）。
## @end-static-doc

var values: Array = []
## Transparent = "caller did not pass a colour"; resolved from the skin token on use.
var line_color: Color = Color.TRANSPARENT


func _ready() -> void:
	custom_minimum_size = Vector2(64, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(prices: Array, color: Color = Color.TRANSPARENT) -> void:
	values = prices
	line_color = SNSkin.color("brass.highlight") if color.a <= 0.0 else color
	queue_redraw()


func _draw() -> void:
	if values.size() < 2:
		var font := get_theme_default_font()
		draw_string(
			font, Vector2(0, 16), "样本不足", HORIZONTAL_ALIGNMENT_LEFT, 64.0, 9,
			SNSkin.color("text.muted")
		)
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
