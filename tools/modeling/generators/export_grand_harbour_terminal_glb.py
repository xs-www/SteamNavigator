# -*- coding: utf-8 -*-
# @static-doc
# 作用：`SN_Grand_Harbour_Terminal` 大型航站楼（architecture 类别）的 GLB 归档导出：
# 把工作台集合 `SN_GHT_Grand_Harbour_Terminal_Prototype` 导出为
# `assets/models/architecture/SN_Grand_Harbour_Terminal.glb`，同步
# `dev_mods/core/assets/models/architecture/` 运行时副本，并用
# `glb_shared_textures.externalize_glb(..., prefer_authored=True)` 把内嵌贴图
# 外部化为 `shared_materials/<texture>.png`；最后写入 `.design/terminal/build_report.json`
# （从 Blender 集合**只读**统计的实际 tri / 节点 / bbox / 材质 / sign tri，供
# `verify_grand_harbour_terminal_glb.py` 验收读取）并保存工作台。
#
# 约定（见 MODELING_WORKFLOW §8 / §12）：
# - 数据源：`sn_grand_harbour_terminal_generator` 的 `ASSET` / `COLLECTION` /
#   `ROOT_NAME` / `TARGET_SIZE` / `TRI_BUDGET` / `TRI_FLOOR` / `WORKBENCH_POS`；
#   导出前**不**重建（先由 Lead / Builder 执行 `build_all()`）；
# - 导出前把根空物体 location 临时归零、只选集合内对象，导出后还原（轴心即 root
#   datum；glTF +Y up，进入 Godot 后尺寸 = Blender (X, Z, Y)）；
# - 覆盖前把旧 GLB 备份到 `.design/architecture/backup_glb/`（旧文件不存在则跳过）；
# - 共享贴图：`sn_shared_materials.texture_report()` 的全部授权 tile 复制到两处
#   `architecture/shared_materials/`（条数不写死，随 spec 增长）；
# - 全部完成后 `bpy.ops.wm.save_mainfile()` 保存工作台。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
#     report = export_all()
# @end-static-doc

import json
import os
import shutil
import sys
import time

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import glb_shared_textures  # noqa: E402
import sn_grand_harbour_terminal_generator as gen  # noqa: E402
import sn_shared_materials as smat  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
CATEGORY = "architecture"
BACKUP_DIR = os.path.join(WORKDIR, ".design", "architecture", "backup_glb")
REPORT_PATH = os.path.join(WORKDIR, ".design", "terminal", "build_report.json")
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures",
                         "shared_materials", "tiles")
URI_PREFIX = "shared_materials"

# 资产契约：全部从生成器读取，避免脚本里再抄一份数字。
ASSET = gen.ASSET
COLLECTION = gen.COLLECTION
ROOT_NAME = gen.ROOT_NAME
SIGN_NODE = "SN_GHT_Sign"
TARGET_SIZE = tuple(float(v) for v in gen.TARGET_SIZE)
TRI_BUDGET = int(gen.TRI_BUDGET)
TRI_FLOOR = int(gen.TRI_FLOOR)
WORKBENCH_POS = tuple(float(v) for v in gen.WORKBENCH_POS)

# 参与 bbox / tri 统计的对象类型（文字铭牌可能以 FONT / CURVE 形式存在）。
GEOMETRY_TYPES = frozenset({"MESH", "CURVE", "FONT", "SURFACE", "META"})


# ---------------------------------------------------------------- 路径 / 报告

def _rel(path):
    return os.path.relpath(path, WORKDIR).replace("\\", "/")


def _out_dirs():
    dev = os.path.join(WORKDIR, "assets", "models", CATEGORY)
    core = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models",
                        CATEGORY)
    return dev, core


def _backup(path):
    """覆盖前把旧 GLB 备份到 `.design/architecture/backup_glb/`。"""
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(BACKUP_DIR, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, dst)
    return dst


# ---------------------------------------------------------------- Blender 只读统计

def _is_sign_object(name):
    """文字铭牌可能被 Blender 改名成 `SN_GHT_Sign.001`。"""
    return name == SIGN_NODE or name.startswith(SIGN_NODE + ".")


def _evaluated_tris(ob, depsgraph):
    """按导出实际几何（含 modifier / 文字转网格）算三角数（n 边形按 n-2）。"""
    evaluated = ob.evaluated_get(depsgraph)
    try:
        mesh = evaluated.to_mesh()
    except RuntimeError:
        return 0
    if mesh is None:
        return 0
    try:
        return sum(max(0, len(poly.vertices) - 2) for poly in mesh.polygons)
    finally:
        evaluated.to_mesh_clear()


def _bbox_entry(lo, hi):
    return {
        "min": [round(v, 4) for v in lo],
        "max": [round(v, 4) for v in hi],
        "size": [round(hi[i] - lo[i], 4) for i in range(3)],
    }


def _collection_stats(collection, root):
    """集合的只读事实：节点 / 网格 / tri / 铭牌 tri / root 局部与世界 bbox / 材质。"""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    root_inv = root.matrix_world.inverted()
    lo_w = [1e18] * 3
    hi_w = [-1e18] * 3
    lo_r = [1e18] * 3
    hi_r = [-1e18] * 3
    stats = {
        "nodes": 0,
        "meshes": 0,
        "tris": 0,
        "sign_tris": 0,
        "sign_found": False,
        "materials": set(),
    }
    for ob in collection.all_objects:
        stats["nodes"] += 1
        if ob.type not in GEOMETRY_TYPES:
            continue
        stats["meshes"] += 1
        tris = _evaluated_tris(ob, depsgraph)
        stats["tris"] += tris
        if _is_sign_object(ob.name):
            stats["sign_found"] = True
            stats["sign_tris"] += tris
        for material in getattr(ob.data, "materials", None) or []:
            if material is not None:
                stats["materials"].add(material.name)
        for corner in ob.bound_box:
            world = ob.matrix_world @ Vector(corner)
            local = root_inv @ world
            for axis in range(3):
                lo_w[axis] = min(lo_w[axis], world[axis])
                hi_w[axis] = max(hi_w[axis], world[axis])
                lo_r[axis] = min(lo_r[axis], local[axis])
                hi_r[axis] = max(hi_r[axis], local[axis])
    if stats["meshes"] == 0:
        raise RuntimeError("collection %s has no geometry objects"
                           % collection.name)
    stats["materials"] = sorted(stats["materials"])
    stats["bbox_world"] = _bbox_entry(lo_w, hi_w)
    stats["bbox_root"] = _bbox_entry(lo_r, hi_r)
    return stats


# ---------------------------------------------------------------- 导出

def _export_glb(collection, root_name, out_dir):
    """单资产导出：根归零、只选集合内对象、+Y up、extras。"""
    col = bpy.data.collections.get(collection)
    if col is None:
        raise RuntimeError("missing collection %s" % collection)
    root = bpy.data.objects.get(root_name)
    if root is None:
        raise RuntimeError("missing root empty %s" % root_name)

    path = os.path.join(out_dir, "%s.glb" % ASSET)
    os.makedirs(out_dir, exist_ok=True)
    backup = _backup(path)

    saved_loc = tuple(root.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        root.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        for ob in bpy.context.selected_objects:
            ob.select_set(False)
        for ob in col.all_objects:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
            export_extras=True,
        )
    finally:
        root.location = saved_loc
        for ob in bpy.context.selected_objects:
            ob.select_set(False)
        for ob in saved_selection:
            ob.select_set(True)
        bpy.context.view_layer.update()
    return path, backup


def _externalize(path, dev_dir):
    """内嵌贴图 -> shared_materials/<texture>.png（优先授权 tile 字节）。"""
    external = glb_shared_textures.externalize_glb(
        path, path,
        shared_dir=os.path.join(dev_dir, "shared_materials"),
        uri_prefix=URI_PREFIX,
        tiles_dir=TILES_DIR,
        write_pngs=True,
        prefer_authored=True,
    )
    images = external.get("images") or []
    if not images:
        raise RuntimeError("%s: no externalized images (shared textures "
                           "missing / materials not textured)" % ASSET)
    unmapped = [entry.get("name") for entry in images
                if not entry.get("authored")
                and not entry.get("already_external")]
    if unmapped:
        raise RuntimeError("%s: images not mapped to authored tiles: %r"
                           % (ASSET, unmapped))
    return external


def _sync_shared_textures():
    """把授权 tile 复制到两处 architecture/shared_materials/。"""
    dev, core = _out_dirs()
    report = smat.texture_report()
    copied = []
    for dst_dir in (os.path.join(dev, "shared_materials"),
                    os.path.join(core, "shared_materials")):
        os.makedirs(dst_dir, exist_ok=True)
        for material in sorted(report):
            entry = report[material]
            src = os.path.join(WORKDIR, entry["file"])
            if not os.path.isfile(src):
                raise RuntimeError("missing authored tile for %s: %s"
                                   % (material, src))
            dst = os.path.join(dst_dir, entry["texture"] + ".png")
            shutil.copy2(src, dst)
            copied.append(_rel(dst))
    return copied


# ---------------------------------------------------------------- 构建报告

def _write_build_report(report):
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    return REPORT_PATH


# ---------------------------------------------------------------- 主流程

def export_all():
    # 活体 Blender 会缓存纯 Python 生成器模块；重建后 TARGET_SIZE 可能已变，
    # 导出前强制 reload，避免 build_report 写入旧尺寸。
    import importlib
    importlib.reload(gen)
    dev_dir, core_dir = _out_dirs()
    os.makedirs(dev_dir, exist_ok=True)
    os.makedirs(core_dir, exist_ok=True)

    collection = bpy.data.collections.get(COLLECTION)
    if collection is None:
        raise RuntimeError(
            "missing collection %s：先执行生成器 build_all()" % COLLECTION)
    root = bpy.data.objects.get(ROOT_NAME)
    if root is None:
        raise RuntimeError("missing root empty %s：先执行生成器 build_all()"
                           % ROOT_NAME)
    if root.type != "EMPTY":
        print("WARN root %s is %s, expected EMPTY" % (root.name, root.type))

    stats = _collection_stats(collection, root)
    if stats["tris"] > TRI_BUDGET:
        raise RuntimeError("%s over tri budget: %d > %d"
                           % (ASSET, stats["tris"], TRI_BUDGET))
    if stats["tris"] < TRI_FLOOR:
        print("WARN %s tris %d below floor %d"
              % (ASSET, stats["tris"], TRI_FLOOR))
    if not stats["sign_found"]:
        print("WARN sign mesh %s not found in %s" % (SIGN_NODE, COLLECTION))

    saved_pos = tuple(root.location)
    if any(abs(saved_pos[i] - WORKBENCH_POS[i]) > 1e-3 for i in range(3)):
        print("WARN root at %r != WORKBENCH_POS %r"
              % (saved_pos, WORKBENCH_POS))

    path, backup = _export_glb(COLLECTION, ROOT_NAME, dev_dir)
    external = _externalize(path, dev_dir)
    core_glb = os.path.join(core_dir, "%s.glb" % ASSET)
    shutil.copy2(path, core_glb)
    shared = _sync_shared_textures()
    bpy.ops.wm.save_mainfile()

    report = {
        "asset": ASSET,
        "category": CATEGORY,
        "collection": COLLECTION,
        "root": ROOT_NAME,
        "workbench": bpy.data.filepath,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "sign_node": SIGN_NODE,
        "sign_found": stats["sign_found"],
        "sign_tris": stats["sign_tris"],
        "nodes": stats["nodes"],
        "meshes": stats["meshes"],
        "tris": stats["tris"],
        "tri_floor": TRI_FLOOR,
        "tri_budget": TRI_BUDGET,
        "target_size": list(gen.TARGET_SIZE),
        "workbench_pos": list(WORKBENCH_POS),
        "bbox_root": stats["bbox_root"],
        "bbox_world": stats["bbox_world"],
        "materials": stats["materials"],
        "glb": _rel(path),
        "core_glb": _rel(core_glb),
        "bytes": os.path.getsize(path),
        "backup": _rel(backup) if backup else None,
        "images": len(external.get("images", [])),
        "authored_pngs": sum(1 for png in external.get("pngs", [])
                             if png.get("authored")),
        "bytes_saved": external.get("bytes_saved", 0),
        "shared_textures": shared,
    }
    _write_build_report(report)
    print("GHT_EXPORT_DONE %r" % {
        "asset": ASSET,
        "tris": stats["tris"],
        "tri_budget": TRI_BUDGET,
        "sign_tris": stats["sign_tris"],
        "nodes": stats["nodes"],
        "meshes": stats["meshes"],
        "bytes": report["bytes"],
        "images": report["images"],
        "shared_pngs": len(shared),
        "report": _rel(REPORT_PATH),
        "workbench": report["workbench"],
    })
    return report


if __name__ == "__main__":
    export_all()
