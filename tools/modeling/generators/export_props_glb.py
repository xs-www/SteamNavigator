# -*- coding: utf-8 -*-
"""Steam Navigator — 道具 GLB 导出脚本（人工验收后由 Lead 执行）。

约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节与 docs/design/ASSET_MAP.md）：
- 逐件导出：每件导出前把 object.location 临时归零，导出后还原；
- 只导出选中的那一个网格对象，不导相机/灯光/其他道具；
- glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
- 每个 .glb 只含一个网格节点，轴心在底面中心。

用法：
    blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_props_glb.py -- NAME...
或在已连 Blender 的会话里 exec 本文件后调用 export_many([...])。

默认导出 TARGETS（只导 P0 改动过的两件，避免无谓地改字节）。
"""

import bpy
import os

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT_DIR = os.path.join(WORKDIR, "assets", "models", "props")

# 按批次分组，避免每次重新导出未改动的资产（字节会变、无意义 diff）
GROUPS = {
    "p0": ["SN_Mooring_Bollard", "SN_Ore_Pile"],
    "batch2": [
        "SN_Gas_Lamp", "SN_Gangway", "SN_Grab_Bucket",
        "SN_Coal_Pile", "SN_Dock_Ladder", "SN_Plate_Stack",
    ],
    "batch3": [
        "SN_Timber_Stack", "SN_Sack_Pile", "SN_Steam_Pipe",
        "SN_Mooring_Rope", "SN_Cargo_Net", "SN_Pallet",
    ],
    "batch4": [
        "SN_Buoy", "SN_Chain_Coil", "SN_Capstan",
        "SN_Handcart", "SN_Fender_Ball", "SN_Gear_Crate",
    ],
    "batch5": [
        "SN_Dock_Stairs", "SN_Port_Sign", "SN_Bell", "SN_Flag_Pole",
        "SN_Coal_Chute", "SN_Boiler_Unit", "SN_Keel_Block",
    ],
}

# 默认导出 P0 那两件；其它批次显式传参
TARGETS = GROUPS["p0"]


def export_one(name, out_dir=OUT_DIR):
    ob = bpy.data.objects.get(name)
    if ob is None or ob.type != "MESH":
        raise RuntimeError("找不到网格对象 %s" % name)

    saved_loc = tuple(ob.location)
    saved_selection = [o for o in bpy.context.selected_objects]
    path = os.path.join(out_dir, "%s.glb" % name)
    try:
        # 轴心在底面中心 -> 导出时把摆放位置归零，几何即局部坐标
        ob.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        for other in bpy.context.selected_objects:
            other.select_set(False)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
            export_extras=False,
        )
    finally:
        ob.location = saved_loc
        for other in bpy.context.selected_objects:
            other.select_set(False)
        for other in saved_selection:
            other.select_set(True)
        bpy.context.view_layer.update()

    size = os.path.getsize(path)
    print("EXPORTED %s -> %s (%d bytes)" % (name, path, size))
    return path


def export_many(names=None):
    names = names or TARGETS
    out = [export_one(n) for n in names]
    print("EXPORT_SUMMARY " + repr({"count": len(out), "files": out}))
    return out


if __name__ == "__main__":
    export_many()
