# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 5（M1-2 `base_kit` 生产建筑 5 件）的预览渲染（Lead 在人工
# 验收前执行，不进游戏）。逐件 3/4 + 侧视、一张 5 件 lineup，以及一张「生产链基地」
# 拼装（锯木厂 → 冶炼炉 → 铸造车间 → 堆场 → 防御塔）+ 一张冶炼/铸造近景；渲染后删除
# 临时对象并恢复场景状态（不保存、不导出）。
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

# (资产, 集合, 根空物体, slug, zmin)
ASSETS = [
    ("SN_Base_Sawmill", "SN_Base_Sawmill_Prototype",
     "SN_Base_Sawmill_Root", "sawmill", 0.0),
    ("SN_Base_Smelter", "SN_Base_Smelter_Prototype",
     "SN_Base_Smelter_Root", "smelter", 0.0),
    ("SN_Base_Foundry", "SN_Base_Foundry_Prototype",
     "SN_Base_Foundry_Root", "foundry", 0.0),
    ("SN_Base_Stockyard", "SN_Base_Stockyard_Prototype",
     "SN_Base_Stockyard_Root", "stockyard", 0.0),
    ("SN_Base_Defense_Tower", "SN_Base_Defense_Tower_Prototype",
     "SN_Base_Defense_Tower_Root", "defense_tower", 0.0),
]


def _save_roots(names):
    saved = {}
    for name in names:
        ob = bpy.data.objects.get(name)
        if ob is not None:
            saved[name] = (tuple(ob.location), tuple(ob.rotation_euler))
    return saved


def _restore_roots(saved):
    for name, (loc, rot) in saved.items():
        ob = bpy.data.objects.get(name)
        if ob is not None:
            ob.location = loc
            ob.rotation_euler = rot
    bpy.context.view_layer.update()


def render_assets():
    cam, _sun, _fill, _floor = base._make_stage()
    for asset, collection_name, root_name, slug, zmin in ASSETS:
        states = base._hide_others({collection_name})
        saved = _save_roots([root_name])
        try:
            root = bpy.data.objects[root_name]
            root.location.z = -zmin
            bpy.context.view_layer.update()
            mn, mx = base._collections_bbox([collection_name])
            for view in ("three_quarter", "side"):
                base._frame(cam, mn, mx, view)
                base._render_both("kit_%s_%s.png" % (slug, view), (900, 700))
        finally:
            _restore_roots(saved)
            base._restore_hidden(states)


def _lineup(resolution, base_y, gap=2.6):
    cam, _sun, _fill, _floor = base._make_stage()
    cam.data.type = "ORTHO"
    saved = _save_roots([a[2] for a in ASSETS])
    hidden = base._hide_others({a[1] for a in ASSETS})
    try:
        widths = []
        max_height = 0.0
        # 资产 +X 是正立面：统一绕 Z 旋转 90° 让正立面朝向 lineup 相机（+Y）。
        for _asset, collection_name, root_name, _slug, zmin in ASSETS:
            root = bpy.data.objects[root_name]
            root.location.z = -zmin
            root.rotation_euler = (0.0, 0.0, math.radians(90.0))
        bpy.context.view_layer.update()
        for _asset, collection_name, root_name, _slug, zmin in ASSETS:
            mn, mx = base._collections_bbox([collection_name])
            widths.append(mx.x - mn.x)
            max_height = max(max_height, mx.z - mn.z)
        total = sum(widths) + gap * (len(widths) - 1)
        cursor = -total * 0.5
        for index, (_asset, _c, root_name, _s, zmin) in enumerate(ASSETS):
            root = bpy.data.objects[root_name]
            root.location = (cursor + widths[index] * 0.5, base_y, -zmin)
            root.rotation_euler = (0.0, 0.0, math.radians(90.0))
            cursor += widths[index] + gap
        bpy.context.view_layer.update()
        target = (0.0, base_y, max_height * 0.55)
        cam.data.ortho_scale = max(total + 4.0,
                                   (max_height + 2.0) * resolution[0] / resolution[1])
        base._look_at(cam, target, (0.0, base_y + 8.0,
                                    max_height * 0.55 + total * 0.012))
        base._render_both("kit_base_lineup.png", resolution)
    finally:
        base._restore_hidden(hidden)
        _restore_roots(saved)
        cam.data.type = "PERSP"
        cam.data.ortho_scale = 1.0
        bpy.context.view_layer.update()


def render_production_line():
    """生产链基地：锯木厂 → 冶炼炉 → 铸造车间 沿 X 排开，堆场与防御塔在后方。"""
    cam, _sun, _fill, _floor = base._make_stage()
    placements = [
        ("SN_Base_Sawmill_Root", (-21.0, 612.0, 0.0), 0.0),
        ("SN_Base_Smelter_Root", (-5.0, 612.0, 0.0), 0.0),
        ("SN_Base_Foundry_Root", (13.0, 612.0, 0.0), 0.0),
        ("SN_Base_Stockyard_Root", (1.0, 630.0, 0.0), 0.0),
        ("SN_Base_Defense_Tower_Root", (26.0, 628.0, 0.0), 0.0),
    ]
    collections = {a[1] for a in ASSETS}
    saved = _save_roots([p[0] for p in placements])
    hidden = base._hide_others(collections)
    try:
        for name, loc, rot_deg in placements:
            root = bpy.data.objects[name]
            root.location = loc
            root.rotation_euler = (0.0, 0.0, math.radians(rot_deg))
        bpy.context.view_layer.update()
        mn, mx = base._collections_bbox(sorted(collections))
        target = (mn + mx) * 0.5
        size = mx - mn
        max_dim = max(size.x, size.y, size.z, 1.0)
        cam.location = target + Vector((0.50, 1.0, 0.26)).normalized() * (
            max_dim * 1.35 + 6.0)
        base._look_at(cam, target, cam.location)
        base._render_both("kit_base_assembly.png", (1800, 980))
        detail = Vector((4.0, 612.0, 4.0))
        cam.location = detail + Vector((0.35, 1.0, 0.24)).normalized() * 34.0
        base._look_at(cam, detail, cam.location)
        base._render_both("kit_base_assembly_detail.png", (1300, 860))
    finally:
        base._restore_hidden(hidden)
        _restore_roots(saved)


def main():
    os.makedirs(LOCAL_DIR, exist_ok=True)
    os.makedirs(DOCS_DIR, exist_ok=True)
    try:
        render_assets()
        _lineup((2100, 920), 660.0, gap=2.6)
        render_production_line()
        print("KIT_BATCH5_PREVIEW_DONE %r" % {
            "per_asset": len(ASSETS) * 2,
            "lineups": 1,
            "assemblies": 2,
            "docs_dir": os.path.relpath(DOCS_DIR, WORKDIR),
        })
    finally:
        base._clean_temps()
        base._restore_stage_state()


if __name__ == "__main__":
    main()
