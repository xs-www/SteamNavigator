# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 4（M1-1 architecture_kit 扩展 6 件）的预览渲染（Lead 在人工
# 验收前执行，不进游戏）。逐件 3/4 + 侧视、一张 6 件 lineup，以及一张「围墙 + 大门 +
# 道路 + 装卸平台 + 仓库变体 + 工坊扩建」的可围合基地拼装街景 + 近景；渲染后删除临时
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

# (资产, 集合, 根空物体, slug, zmin)
ASSETS = [
    ("SN_Arch_Perimeter_Wall", "SN_Arch_Perimeter_Wall_Prototype",
     "SN_Arch_Perimeter_Wall_Root", "perimeter_wall", 0.0),
    ("SN_Arch_Gate", "SN_Arch_Gate_Prototype",
     "SN_Arch_Gate_Root", "gate", 0.0),
    ("SN_Arch_Road", "SN_Arch_Road_Prototype",
     "SN_Arch_Road_Root", "road", 0.0),
    ("SN_Arch_Loading_Platform", "SN_Arch_Loading_Platform_Prototype",
     "SN_Arch_Loading_Platform_Root", "loading_platform", 0.0),
    ("SN_Arch_Warehouse_Variant", "SN_Arch_Warehouse_Variant_Prototype",
     "SN_Arch_Warehouse_Variant_Root", "warehouse_variant", 0.0),
    ("SN_Arch_Workshop_Annex", "SN_Arch_Workshop_Annex_Prototype",
     "SN_Arch_Workshop_Annex_Root", "workshop_annex", 0.0),
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


def _lineup(resolution, base_y, gap=2.4):
    cam, _sun, _fill, _floor = base._make_stage()
    cam.data.type = "ORTHO"
    saved = _save_roots([a[2] for a in ASSETS])
    hidden = base._hide_others({a[1] for a in ASSETS})
    try:
        widths = []
        max_height = 0.0
        for _asset, collection_name, root_name, _slug, zmin in ASSETS:
            root = bpy.data.objects[root_name]
            root.location.z = -zmin
            mn, mx = base._collections_bbox([collection_name])
            widths.append(mx.x - mn.x)
            max_height = max(max_height, mx.z - mn.z)
        total = sum(widths) + gap * (len(widths) - 1)
        cursor = -total * 0.5
        for index, (_asset, _c, root_name, _s, zmin) in enumerate(ASSETS):
            root = bpy.data.objects[root_name]
            root.location = (cursor + widths[index] * 0.5, base_y, -zmin)
            cursor += widths[index] + gap
        bpy.context.view_layer.update()
        target = (0.0, base_y, max_height * 0.55)
        cam.data.ortho_scale = max(total + 4.0,
                                   (max_height + 2.0) * resolution[0] / resolution[1])
        base._look_at(cam, target, (0.0, base_y + 8.0,
                                    max_height * 0.55 + total * 0.012))
        base._render_both("kit_architecture_extension_lineup.png", resolution)
    finally:
        base._restore_hidden(hidden)
        _restore_roots(saved)
        cam.data.type = "PERSP"
        cam.data.ortho_scale = 1.0
        bpy.context.view_layer.update()


def _dup_collection(source_name, suffix):
    """复制一个资产集合（含 Root / socket / mesh），给拼装图里的第二段围墙用。

    副本名统一带 base.TEMP_PREFIX，渲染结束由 base._clean_temps() 清掉；
    网格数据共享（不改几何，只摆位）。
    """
    source = bpy.data.collections[source_name]
    dup = bpy.data.collections.new(base.TEMP_PREFIX + source_name + suffix)
    bpy.context.scene.collection.children.link(dup)
    copies = {}
    for ob in source.objects:
        new = ob.copy()
        new.name = base.TEMP_PREFIX + ob.name + suffix
        dup.objects.link(new)
        copies[ob.name] = new
    for ob, new in ((o, copies[o.name]) for o in source.objects):
        if ob.parent is not None:
            new.parent = copies[ob.parent.name]
            new.matrix_parent_inverse = ob.matrix_parent_inverse.copy()
        new.matrix_basis = ob.matrix_basis.copy()
    return dup


def render_base_compound():
    """可围合基地：石板路 + 左右围墙 + 中央大门 + 后方仓库变体/工坊扩建 + 右侧装卸平台。"""
    cam, _sun, _fill, _floor = base._make_stage()
    wall_dup = _dup_collection("SN_Arch_Perimeter_Wall_Prototype", "_Right")
    wall_dup_root = base.TEMP_PREFIX + "SN_Arch_Perimeter_Wall_Root_Right"
    placements = [
        ("SN_Arch_Road_Root", (0.0, 608.0, 0.0), 0.0),
        ("SN_Arch_Perimeter_Wall_Root", (-12.0, 616.0, 0.0), 0.0),
        ("SN_Arch_Gate_Root", (0.0, 616.0, 0.0), 0.0),
        (wall_dup_root, (12.0, 616.0, 0.0), 0.0),
        ("SN_Arch_Warehouse_Variant_Root", (-8.0, 628.0, 0.0), 90.0),
        ("SN_Arch_Workshop_Annex_Root", (10.0, 628.0, 0.0), 90.0),
        ("SN_Arch_Loading_Platform_Root", (26.0, 616.0, 0.0), -90.0),
    ]
    collections = {a[1] for a in ASSETS} | {wall_dup.name}
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
        cam.location = target + Vector((0.45, 1.0, 0.24)).normalized() * (
            max_dim * 1.45 + 6.0)
        base._look_at(cam, target, cam.location)
        base._render_both("kit_architecture_extension_assembly.png", (1800, 980))
        detail = Vector((0.0, 616.0, 3.0))
        cam.location = detail + Vector((0.40, 1.0, 0.20)).normalized() * 20.0
        base._look_at(cam, detail, cam.location)
        base._render_both("kit_architecture_extension_assembly_detail.png",
                          (1300, 860))
    finally:
        base._restore_hidden(hidden)
        _restore_roots(saved)
        bpy.data.collections.remove(wall_dup)


def main():
    os.makedirs(LOCAL_DIR, exist_ok=True)
    os.makedirs(DOCS_DIR, exist_ok=True)
    try:
        render_assets()
        _lineup((2100, 900), 640.0, gap=2.4)
        render_base_compound()
        print("KIT_BATCH4_PREVIEW_DONE %r" % {
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
