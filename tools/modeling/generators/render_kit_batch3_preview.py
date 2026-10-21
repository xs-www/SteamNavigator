# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 3（建筑 4 + 环境 4）的预览渲染（Lead 在人工验收前执行，
# 不进游戏）。逐件 3/4 + 侧视、建筑 / 环境两组 lineup，以及一张「仓库 + 工坊 +
# 酒馆 + 厂房」街区和一张「礁石 + 灯塔 + 残骸 + 浮标」海岸拼装；渲染后删除临时
# 对象并恢复场景状态（不保存、不导出）。
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

# (资产, 集合, 根空物体, slug, 组, zmin)
ASSETS = [
    ("SN_Arch_Warehouse", "SN_Arch_Warehouse_Prototype",
     "SN_Arch_Warehouse_Root", "warehouse", "architecture", 0.0),
    ("SN_Arch_Workshop", "SN_Arch_Workshop_Prototype",
     "SN_Arch_Workshop_Root", "workshop", "architecture", 0.0),
    ("SN_Arch_Tavern", "SN_Arch_Tavern_Prototype",
     "SN_Arch_Tavern_Root", "tavern", "architecture", 0.0),
    ("SN_Arch_Factory", "SN_Arch_Factory_Prototype",
     "SN_Arch_Factory_Root", "factory", "architecture", 0.0),
    ("SN_Env_Reef", "SN_Env_Reef_Prototype",
     "SN_Env_Reef_Root", "reef", "environment", -3.0),
    ("SN_Env_Wreck", "SN_Env_Wreck_Prototype",
     "SN_Env_Wreck_Root", "wreck", "environment", -1.5),
    ("SN_Env_Lighthouse", "SN_Env_Lighthouse_Prototype",
     "SN_Env_Lighthouse_Root", "lighthouse", "environment", 0.0),
    ("SN_Env_Buoy", "SN_Env_Buoy_Prototype",
     "SN_Env_Buoy_Root", "buoy", "environment", -0.74),
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
    for asset, collection_name, root_name, slug, _group, zmin in ASSETS:
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


def _lineup(group, slug, resolution, base_y, gap=2.2, face_camera=False):
    cam, _sun, _fill, _floor = base._make_stage()
    cam.data.type = "ORTHO"
    items = [a for a in ASSETS if a[4] == group]
    saved = _save_roots([a[2] for a in items])
    widths = []
    max_height = 0.0
    for _asset, collection_name, root_name, _slug, _group, zmin in items:
        root = bpy.data.objects[root_name]
        root.location.z = -zmin
        root.rotation_euler = (0.0, 0.0, math.radians(90.0) if face_camera
                               else 0.0)
    bpy.context.view_layer.update()
    hidden = base._hide_others({a[1] for a in items})
    try:
        for _asset, collection_name, _root_name, _slug, _group, zmin in items:
            mn, mx = base._collections_bbox([collection_name])
            widths.append(mx.x - mn.x)
            max_height = max(max_height, mx.z - mn.z)
        total = sum(widths) + gap * max(0, len(widths) - 1)
        cursor = -total * 0.5
        for index, (_asset, _c, root_name, _s, _g, zmin) in enumerate(items):
            root = bpy.data.objects[root_name]
            root.location = (cursor + widths[index] * 0.5, base_y, -zmin)
            root.rotation_euler = (0.0, 0.0,
                                   math.radians(90.0) if face_camera else 0.0)
            cursor += widths[index] + gap
        bpy.context.view_layer.update()
        target = (0.0, base_y, max_height * 0.55)
        cam.data.ortho_scale = max(total + 4.0,
                                   (max_height + 2.0) * resolution[0] / resolution[1])
        base._look_at(cam, target, (0.0, base_y + 8.0,
                                    max_height * 0.55 + total * 0.015))
        base._render_both("kit_%s_lineup.png" % slug, resolution)
    finally:
        base._restore_hidden(hidden)
        _restore_roots(saved)
        cam.data.type = "PERSP"
        cam.data.ortho_scale = 1.0
        bpy.context.view_layer.update()


def _tmp_water(size=90.0, y=610.0, name="Water"):
    mesh = bpy.data.meshes.new(base.TEMP_PREFIX + name + "Mesh")
    mesh.from_pydata(
        [(-size * 0.5, y - size * 0.5, 0.0), (size * 0.5, y - size * 0.5, 0.0),
         (size * 0.5, y + size * 0.5, 0.0), (-size * 0.5, y + size * 0.5, 0.0)],
        [], [(0, 1, 2, 3)])
    mesh.update()
    mesh.materials.append(base._make_material(
        base.TEMP_PREFIX + "WaterMat", (0.045, 0.085, 0.10), 0.35))
    ob = bpy.data.objects.new(base.TEMP_PREFIX + name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def render_town_assembly():
    """仓库 + 工坊 + 酒馆 + 厂房：正立面统一朝 +Y，沿 X 拼成街区。"""
    cam, _sun, _fill, _floor = base._make_stage()
    placements = [
        ("SN_Arch_Warehouse_Root", -16.0, 610.0),
        ("SN_Arch_Workshop_Root", -6.4, 610.0),
        ("SN_Arch_Tavern_Root", 1.6, 610.0),
        ("SN_Arch_Factory_Root", 11.8, 610.0),
    ]
    collections = {"SN_Arch_Warehouse_Prototype", "SN_Arch_Workshop_Prototype",
                   "SN_Arch_Tavern_Prototype", "SN_Arch_Factory_Prototype"}
    saved = _save_roots([p[0] for p in placements])
    hidden = base._hide_others(collections)
    try:
        for name, x, y in placements:
            root = bpy.data.objects[name]
            root.location = (x, y, 0.0)
            root.rotation_euler = (0.0, 0.0, math.radians(90.0))
        bpy.context.view_layer.update()
        mn, mx = base._collections_bbox(sorted(collections))
        target = (mn + mx) * 0.5
        size = mx - mn
        max_dim = max(size.x, size.y, size.z, 1.0)
        cam.location = target + Vector((0.55, 1.0, 0.34)).normalized() * (
            max_dim * 1.55 + 5.0)
        base._look_at(cam, target, cam.location)
        base._render_both("kit_assembly_town.png", (1700, 950))
        # 近景：仓库装卸雨棚 + 正立面
        detail = Vector((-9.5, 611.0, 2.6))
        cam.location = detail + Vector((0.60, 1.0, 0.30)).normalized() * 18.0
        base._look_at(cam, detail, cam.location)
        base._render_both("kit_assembly_town_detail.png", (1300, 860))
    finally:
        base._restore_hidden(hidden)
        _restore_roots(saved)


def render_coast_assembly():
    """礁石 + 灯塔（落座 Top）+ 残骸 + 浮标：海岸小景。"""
    cam, _sun, _fill, _floor = base._make_stage()
    water = _tmp_water()
    placements = [
        ("SN_Env_Reef_Root", (-4.0, 610.0, 0.0), (0.0, 0.0, 0.0)),
        ("SN_Env_Lighthouse_Root", (-3.40, 609.60, 2.48), (0.0, 0.0, 0.0)),
        ("SN_Env_Wreck_Root", (5.5, 613.0, 0.0), (0.0, 0.0, 28.0)),
        ("SN_Env_Buoy_Root", (-10.5, 616.0, 0.0), (0.0, 0.0, 18.0)),
    ]
    collections = {"SN_Env_Reef_Prototype", "SN_Env_Lighthouse_Prototype",
                   "SN_Env_Wreck_Prototype", "SN_Env_Buoy_Prototype"}
    saved = _save_roots([p[0] for p in placements])
    hidden = base._hide_others(collections)
    try:
        for name, loc, rot in placements:
            root = bpy.data.objects[name]
            root.location = loc
            root.rotation_euler = (math.radians(rot[0]) if rot[0] else 0.0,
                                   math.radians(rot[1]) if rot[1] else 0.0,
                                   math.radians(rot[2]))
        bpy.context.view_layer.update()
        mn, mx = base._collections_bbox(sorted(collections))
        target = (mn + mx) * 0.5
        size = mx - mn
        max_dim = max(size.x, size.y, size.z, 1.0)
        cam.location = target + Vector((0.62, 1.0, 0.26)).normalized() * (
            max_dim * 2.2 + 5.0)
        base._look_at(cam, target, cam.location)
        base._render_both("kit_assembly_coast.png", (1700, 950))
        detail = Vector((-3.2, 609.8, 10.6))
        cam.location = detail + Vector((0.72, 1.0, 0.18)).normalized() * 14.0
        base._look_at(cam, detail, cam.location)
        base._render_both("kit_assembly_coast_detail.png", (1200, 900))
    finally:
        base._restore_hidden(hidden)
        _restore_roots(saved)
        bpy.data.objects.remove(water, do_unlink=True)


def main():
    os.makedirs(LOCAL_DIR, exist_ok=True)
    os.makedirs(DOCS_DIR, exist_ok=True)
    try:
        render_assets()
        _lineup("architecture", "architecture", (2000, 900), 600.0, gap=2.4,
                face_camera=True)
        _lineup("environment", "environment", (1700, 820), 610.0, gap=2.6)
        render_town_assembly()
        render_coast_assembly()
        print("KIT_BATCH3_PREVIEW_DONE %r" % {
            "per_asset": len(ASSETS) * 2,
            "lineups": 2,
            "assemblies": 4,
            "docs_dir": os.path.relpath(DOCS_DIR, WORKDIR),
        })
    finally:
        base._clean_temps()
        base._restore_stage_state()


if __name__ == "__main__":
    main()
