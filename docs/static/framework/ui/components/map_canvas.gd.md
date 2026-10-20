# `framework/ui/components/map_canvas.gd`

> 作用：海图绘制与港口点击组件：显示航路、经纬网、洋流、罗盘、图例及港口状态。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNMapCanvas` | L1 |
| `port_clicked (signal)` | L4 |
| `WATER` | L6 |
| `GRID_MINOR` | L7 |
| `GRID_MAJOR` | L8 |
| `INK` | L9 |
| `MUTED` | L10 |
| `BRASS` | L11 |
| `VISITED` | L12 |
| `DISCOVERED` | L13 |

## 契约与约束

- 输入仅为 ports/routes/labels；点击已访问港口时发出 port_clicked(port_id)，不执行导航或查询。
- 航路使用三次贝塞尔曲线；每港以邻接港口位置平均方向作为唯一出港方向，并沿目的港出港切线入港。
- 当前港显示脉冲光晕，已访问/可航行/未知港使用不同但带文字图例的状态，不只依赖颜色。
- 布局按输入坐标缩放到控件尺寸；重绘和 hover 不修改世界或地图 ViewModel。

模块索引：[framework/ui](../README.md)
