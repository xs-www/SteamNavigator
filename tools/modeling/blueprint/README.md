# Blender 工业蓝图线稿生成器

独立 Blender Python 工具：把 `.blend` / `.glb` 模型批量转换为透明背景的工业工程蓝图线稿。它不修改或保存输入模型，不依赖 Godot，也不使用 AI 图像生成。

## 环境

- Blender 4.4+；仓库验证版本为 Blender 4.4。
- Python 外层批处理仅使用标准库。
- 模型坐标默认 `+X` 为船首、`+Z` 为上方；可通过参数覆盖。

## 单模型：直接使用 Blender

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" -b `
  -P tools/modeling/blueprint/blueprint_generator.py -- `
  --input assets/models/ships/SN_Paddle_Freighter.glb `
  --output .design/blueprint/paddle_freighter `
  --views side,top,iso `
  --detail normal
```

输出：

```text
blueprint/
├── side.png
├── top.png
├── iso.png
└── metadata.json
```

Blender 默认先渲染 2048×2048 RGBA 画布，随后根据 Alpha 内容框自动裁掉透明边缘，并在内容长边四周保留 4% 留白。因此最终 PNG 是适配模型长宽比的非固定尺寸，可直接放入 Godot UI。`metadata.json` 记录源文件哈希、模型世界边界/尺寸、方向、相机方向/位置/正交尺度、原始画布、裁切框、最终尺寸、线条配置和相对输出路径；不包含运行时间戳。

默认裁切参数：

```text
--crop-padding 0.04          留白 = 内容长边的 4%
--crop-alpha-threshold 8     alpha > 8 的像素计入内容框
--no-crop                    可选：保留原始正方形画布
```

裁切依据 Alpha 而不是 RGB，因此不会漏掉半透明的次要结构线。实现仅使用 Python 标准库，不要求 Blender 安装 Pillow。

## 批处理与故障隔离

外层 CLI 为每个模型启动独立 Blender 进程。某个模型失败后仍继续处理其余文件，每件输出目录写 `blueprint.log`，批次根目录写 `batch_summary.json`。若存在失败，处理完成后返回退出码 1。

```powershell
python tools/modeling/blueprint/blueprint_batch.py `
  --blender "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" `
  --input assets/models/ships `
  --output .design/blueprint/ships `
  --recursive `
  --views side,top,iso `
  --detail normal
```

目录输入按源文件相对路径和完整文件名（含扩展名）建立子目录，因此递归扫描中的同名文件，以及同目录的 `ship.blend` / `ship.glb`，不会互相覆盖。也可设置 `BLENDER_BIN` 或把 `blender` 加入 PATH。

## 细节档位

- `simple`：外轮廓、可见边界和外部轮廓。
- `normal`：在 `simple` 基础上增加大于 `crease_angle_degrees` 的结构折线，默认推荐。
- `detailed`：再增加材质边界和显式 Freestyle edge mark；次要线使用更低透明度。默认不启用 ridge/valley，避免复杂低模的细小构件在低分辨率下糊成白块。

共面三角化边不会被选为 crease，因此不会形成密集三角杂线。Freestyle 只输出可见线；隐藏线、剖面和尺寸标注属于预留能力，MVP 不实现。

### 为什么部分小构件不是闭合轮廓

线稿把实体材质替换为透明表面，但模型几何仍参与 Freestyle 的深度遮挡。嵌入船壳的铆钉只会画出露在船壳外的弧线；严格侧视下相互重叠的烟囱、栏杆或索具，也会在被前景几何遮挡的位置截断。这是 `VISIBLE` 可见线模式的预期结果，不是 Alpha 裁切丢线。

全局开启隐藏线会同时暴露船体内部和背面网格，通常比局部断线更杂。若 UI 需要“每个部件都闭合”的示意图，应在后续以 Collection/对象分类为基础，对指定小构件单独输出隐藏线或分层合成，而不是对整船开启透视线。

## 配置

复制 [config.example.json](config.example.json)，通过 `--config <path>` 使用。CLI 的 `--resolution` / `--margin` 会覆盖配置文件同名值。配置接受的键固定为示例中的键，拼错会直接失败，避免批次悄悄使用错误样式。

常用参数：

```text
--forward-axis +X        +X/-X/+Y/-Y/+Z/-Z
--up-axis +Z             必须与 forward 垂直
--resolution 2048        256..8192
--margin 1.10            1.0..2.0
--detail normal          simple/normal/detailed
--crop-padding 0.04      0.0..0.5，默认启用自动裁切
--crop-alpha-threshold 8 0..254
--no-crop                保留原始正方形画布
```

## 可复现测试

测试会在临时目录创建一个低面数蒸汽船 GLB，再通过真实批处理链生成三视图，校验 Alpha 自动裁切、PNG 最终尺寸、RGBA/透明通道、模型尺寸、裁切元数据及 `--no-crop` 兼容路径。

```powershell
python tools/modeling/blueprint/tests/test_smoke.py `
  --blender "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe"
```

添加 `--keep-output` 可保留临时结果供人工查看。

## MVP 边界与扩展点

当前按整个场景的可渲染 Mesh 合并取景。后续可在 `_mesh_objects()` 前增加 Collection/对象过滤，在 `view_metadata` 中增加 2D 投影框与部件蒙版，在 Freestyle LineSet 中扩展隐藏线，并以源文件哈希 + 配置摘要实现增量缓存；这些功能目前没有进入 CLI 契约。
