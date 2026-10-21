# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 2（机械 / 货物 / 码头 10 件）的预览渲染（Lead 在人工验收前
# 执行，不进游戏）。逐件 3/4 + 侧视、三组 lineup，以及一张「码头 + 栈桥 + 系缆 +
# 货箱」拼装演示；渲染后删除临时对象并恢复场景状态。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# 输出：.design/kits/preview/*.png 与 docs/design/screenshots/kits/*.png
# @end-static-doc

import math
import os

import bpy
from mathutils import Vector

import render_kit_preview as base

WORKDIR = base.WORKDIR
LOCAL_DIR = os.path.join(WORKDIR, ".design", "kits", "preview")
DOCS_DIR = os.path.join(WORKDIR, "docs", "design", "screenshots", "kits")
base.LOCAL_DIR = LOCAL_DIR
base.DOCS_DIR = DOCS_DIR

# (资产, 集合, 根空物体, slug, 组, 基准 zmin)
ASSETS = [
    ("SN_Machinery_GearSet", "SN_Machinery_GearSet_Prototype",
     "SN_Machinery_GearSet_Root", "gearset", "machinery", 0.0),
    ("SN_Machinery_Winch", "SN_Machinery_Winch_Prototype",
     "SN_Machinery_Winch_Root", "winch", "machinery", 0.0),
    ("SN_Machinery_PowerUnit", "SN_Machinery_PowerUnit_Prototype",
     "SN_Machinery_PowerUnit_Root", "power_unit", "machinery", 0.0),
    ("SN_Cargo_Crate", "SN_Cargo_Crate_Prototype",
     "SN_Cargo_Crate_Root", "crate", "cargo", 0.0),
    ("SN_Cargo_CoalScuttle", "SN_Cargo_CoalScuttle_Prototype",
     "SN_Cargo_CoalScuttle_Root", "coal_scuttle", "cargo", 0.0),
    ("SN_Cargo_Tank", "SN_Cargo_Tank_Prototype",
     "SN_Cargo_Tank_Root", "tank", "cargo", 0.0),
    ("SN_Cargo_Pallet", "SN_Cargo_Pallet_Prototype",
     "SN_Cargo_Pallet_Root", "pallet", "cargo", 0.0),
    ("SN_Dock_Structure", "SN_Dock_Structure_Prototype",
     "SN_Dock_Structure_Root", "dock_structure", "dock", 0.0),
    ("SN_Dock_Jetty", "SN_Dock_Jetty_Prototype",
     "SN_Dock_Jetty_Root", "jetty", "dock", -1.30),
    ("SN_Dock_Mooring", "SN_Dock_Mooring_Prototype",
     "SN_Dock_Mooring_Root", "mooring", "dock", 0.0),
]


def render_assets():
    cam, _sun, _fill, _floor = base._make_stage()
    for asset, collection_name, root_name, slug, _group, _zmin in ASSETS:
        states = base._hide_others({collection_name})
        try:
            mn, mx = base._collections_bbox([collection_name])
            for view in ("three_quarter", "side"):
                base._frame(cam, mn, mx, view)
                base._render_both("kit_%s_%s.png" % (slug, view), (900, 700))
        finally:
            base._restore_hidden(states)


def _lineup(group, slug, resolution, gap=1.8):
    cam, _sun, _fill, _floor = base._make_stage()
    cam.data.type = "ORTHO"
    items = [a for a in ASSETS if a[4] == group]
    saved = {}
    widths = []
    max_height = 0.0
    for asset, collection_name, root_name, _slug, _group, zmin in items:
        root = bpy.data.objects[root_name]
        saved[asset] = (tuple(root.location), tuple(root.rotation_euler))
        mn, mx = base._collections_bbox([collection_name])
        widths.append(mx.x - mn.x)
        max_height = max(max_height, mx.z - mn.z)
    hidden = base._hide_others({a[1] for a in items})
    try:
        total = sum(widths) + gap * max(0, len(widths) - 1)
        cursor = -total * 0.5
        base_y = 610.0
        for index, (asset, _c, root_name, _s, _g, zmin) in enumerate(items):
            root = bpy.data.objects[root_name]
            root.location = (cursor + widths[index] * 0.5, base_y, -zmin)
            root.rotation_euler = (0.0, 0.0, 0.0)
            cursor += widths[index] + gap
        bpy.context.view_layer.update()
        target = (0.0, base_y, max_height * 0.5)
        cam.data.ortho_scale = max(total + 4.0,
                                   (max_height + 2.0) * resolution[0] / resolution[1])
        base._look_at(cam, target, (0.0, base_y + 7.0,
                                    max_height * 0.5 + total * 0.02))
        base._render_both("kit_%s_lineup.png" % slug, resolution)
    finally:
        base._restore_hidden(hidden)
        for asset, _c, root_name, _s, _g, _z in items:
            root = bpy.data.objects[root_name]
            root.location = saved[asset][0]
            root.rotation_euler = saved[asset][1]
        cam.data.type = "PERSP"
        cam.data.ortho_scale = 1.0
        bpy.context.view_layer.update()


def _save_roots(names):
    return {name: (tuple(bpy.data.objects[name].location),
                   tuple(bpy.data.objects[name].rotation_euler))
            for name in names if bpy.data.objects.get(name)}


def _restore_roots(saved):
    for name, (loc, rot) in saved.items():
        root = bpy.data.objects.get(name)
        if root is not None:
            root.location = loc
            root.rotation_euler = rot
    bpy.context.view_layer.update()


def render_dock_assembly():
    """码头结构 + 栈桥 + 2 个系缆设施 + 托盘/货箱。"""
    cam, _sun, _fill, _floor = base._make_stage()
    names = ["SN_Dock_Structure_Root", "SN_Dock_Jetty_Root",
             "SN_Dock_Mooring_Root.001", "SN_Dock_Mooring_Root.002",
             "SN_Cargo_Pallet_Root", "SN_Cargo_Crate_Root"]
    # 系缆设施只有一件资产，拼装演示里临时复制两份
    mooring = bpy.data.objects["SN_Dock_Mooring_Root"]
    dup = []
    for suffix in (".001", ".002"):
        copy = mooring.copy()
        copy.data = None
        copy.name = "SN_Dock_Mooring_Root" + suffix
        for child in mooring.children:
            child_copy = child.copy()
            child_copy.data = child.data
            child_copy.parent = copy
            base.bpy.context.scene.collection.objects.link(child_copy)
        base.bpy.context.scene.collection.objects.link(copy)
        dup.append(copy)
    saved = _save_roots([n for n in names if bpy.data.objects.get(n)])
    hidden = base._hide_others({
        "SN_Dock_Structure_Prototype", "SN_Dock_Jetty_Prototype",
        "SN_Dock_Mooring_Prototype", "SN_Cargo_Pallet_Prototype",
        "SN_Cargo_Crate_Prototype"})
    for copy in dup:
        copy.hide_render = False
        for child in copy.children_recursive:
            child.hide_render = False
    try:
        dock = bpy.data.objects["SN_Dock_Structure_Root"]
        dock.location = (0.0, 600.0, 0.0)
        jetty = bpy.data.objects["SN_Dock_Jetty_Root"]
        jetty.location = (0.0, 602.1, 0.0)
        jetty.rotation_euler = (0.0, 0.0, math.radians(90.0))
        for index, copy in enumerate(dup):
            copy.location = (2.4 if index == 0 else -2.4, 600.0, 3.02)
            copy.rotation_euler = (0.0, 0.0, 0.0)
        pallet = bpy.data.objects["SN_Cargo_Pallet_Root"]
        pallet.location = (1.20, 598.4, 3.02)
        pallet.rotation_euler = (0.0, 0.0, 0.0)
        crate = bpy.data.objects["SN_Cargo_Crate_Root"]
        crate.location = (1.20, 598.4, 3.20)
        crate.rotation_euler = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        collections = ["SN_Dock_Structure_Prototype", "SN_Dock_Jetty_Prototype",
                       "SN_Dock_Mooring_Prototype", "SN_Cargo_Pallet_Prototype",
                       "SN_Cargo_Crate_Prototype"]
        mn, mx = base._collections_bbox(collections)
        target = Vector((0.0, 601.6, 1.7))
        direction = Vector((0.30, 1.0, 0.52)).normalized()
        cam.location = target + direction * 27.0
        base._look_at(cam, target, cam.location)
        base._render_both("kit_assembly_dock.png", (1400, 900))
        detail = Vector((0.2, 600.2, 3.05))
        cam.location = detail + Vector((0.45, 1.0, 0.50)).normalized() * 14.0
        base._look_at(cam, detail, cam.location)
        base._render_both("kit_assembly_dock_detail.png", (1200, 820))
    finally:
        base._restore_hidden(hidden)
        _restore_roots(saved)
        for copy in dup:
            for child in list(copy.children):
                bpy.data.objects.remove(child, do_unlink=True)
            bpy.data.objects.remove(copy, do_unlink=True)


def main():
    os.makedirs(LOCAL_DIR, exist_ok=True)
    os.makedirs(DOCS_DIR, exist_ok=True)
    try:
        render_assets()
        _lineup("machinery", "machinery", (1500, 700))
        _lineup("cargo", "cargo", (1500, 700))
        _lineup("dock", "dock", (1600, 820))
        render_dock_assembly()
        print("KIT_BATCH2_PREVIEW_DONE %r" % {
            "per_asset": len(ASSETS) * 2,
            "lineups": 3,
            "assemblies": 2,
            "docs_dir": os.path.relpath(DOCS_DIR, WORKDIR),
        })
    finally:
        base._clean_temps()
        base._restore_stage_state()


if __name__ == "__main__":
    main()
