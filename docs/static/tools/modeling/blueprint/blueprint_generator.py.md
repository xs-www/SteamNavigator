# `tools/modeling/blueprint/blueprint_generator.py`

> 作用：Blender 后台工业蓝图线稿生成内核；只读加载 `.blend` / `.glb`，自动计算模型边界、

- 类型：项目配置/数据文件

创建正交侧视/俯视/轴测相机，用 Freestyle 输出透明 PNG，默认按 Alpha 自动裁切后写
确定性 `metadata.json`。

## 契约与约束
- 原始模型只在内存中打开或导入，脚本不保存 `.blend`、不导出模型、不覆盖输入文件。
- `simple / normal / detailed` 只逐级增加结构线类型；三角化产生的共面内部边不会被选择。
- 元数据不写时间戳，路径使用输出目录相对路径；同一模型与配置的相机计算可重复。
- 直接入口：`blender -b -P blueprint_generator.py -- --input model.glb --output out`。

## 重点逻辑
### `generate(args)`
清理默认场景、载入一个模型、把表面替换为透明材质、逐视图渲染并原子写元数据。

模块索引：[tools](../../README.md)
