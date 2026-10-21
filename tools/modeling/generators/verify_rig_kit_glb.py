# -*- coding: utf-8 -*-
# @static-doc
# 作用：`rig_kit` 独立套件（12 件 `SN_Rig_*`）的 **GLB 独立验收**（纯 Python，
# 不进 Blender）——期望值从 `rig_kit_batch1_generator.build_geometry()` 的纯几何推导：
# 节点 / 网格 / 三角面 / 世界尺寸（Y-up）/ 贴地基准 / 材质集合 / 每图元 UV /
# 外部共享贴图 URI 与授权字节 / Core 副本一致，以及接口契约：
# `SN_Mount` + `SN_Socket_Mast|Yard|Sail_*` 节点存在且无 mesh、Root extras 含
# `rig_sockets` / `rig_socket_count` / `rig_socket_spec` 与套件字段。
#
# 通过标准：12/12 `ALL OK`；否则返回非 0 退出码。
# 用法：`python tools/modeling/generators/verify_rig_kit_glb.py`
# @end-static-doc

import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import rig_kit_batch1_generator as gen  # noqa: E402
import verify_cranes_glb as base  # noqa: E402

WORKDIR = base.WORKDIR
CATEGORY = "rig"
DEV_DIR = os.path.join(WORKDIR, "assets", "models", CATEGORY)
CORE_DIR = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", CATEGORY)
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures",
                         "shared_materials", "tiles")
SIZE_TOL = 0.02
Z_TOL = 0.03
TEX_PREFIX = "shared_materials/"
REQUIRED_EXTRAS = {
    "asset", "version", "units", "kit_family", "part_role", "forward", "up",
    "datum", "mount_frame", "base_footprint_x", "base_footprint_y",
    "footprint_kind", "envelope_x", "envelope_y", "height", "tri_budget",
    "bbox_target", "socket_spec", "socket_count", "rig_spec",
}


def _sha(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _tri(part):
    return sum(max(0, len(f) - 2) for f, _m in part.faces)


def _expected(asset):
    parts = gen.build_geometry(asset)
    lo = [1e18] * 3
    hi = [-1e18] * 3
    mats = set()
    tris = 0
    for _name, (part, _parent) in parts.items():
        tris += _tri(part)
        for _f, mat in part.faces:
            mats.add(mat)
        for v in part.verts:
            for axis in range(3):
                lo[axis] = min(lo[axis], v[axis])
                hi[axis] = max(hi[axis], v[axis])
    size = [hi[i] - lo[i] for i in range(3)]
    sockets = gen.socket_roles(asset)
    return {
        "nodes": 1 + len(parts) + len(sockets),
        "meshes": len(parts),
        "tris": tris,
        "size": size,
        "bbox_min": lo,
        "mats": mats,
        "sockets": sockets,
        "root": gen.SPECS[asset]["prefix"] + "Root",
    }


def check_asset(asset):
    path = os.path.join(DEV_DIR, "%s.glb" % asset)
    flags = []
    if not os.path.isfile(path):
        return {"asset": asset, "passed": False, "flags": ["GLB 不存在"]}
    stats = base.gltf_stats(path)
    gltf = base.load_glb(path)
    expected = _expected(asset)
    nodes = gltf.get("nodes", [])
    extras_by_name = {node.get("name", ""): node.get("extras", {})
                      for node in nodes}

    if stats["nodes"] != expected["nodes"]:
        flags.append("节点数 %d != %d" % (stats["nodes"], expected["nodes"]))
    if stats["meshes"] != expected["meshes"]:
        flags.append("网格数 %d != %d" % (stats["meshes"], expected["meshes"]))
    if stats["tris"] != expected["tris"]:
        flags.append("三角面 %d != %d" % (stats["tris"], expected["tris"]))
    expect_yup = (expected["size"][0], expected["size"][2], expected["size"][1])
    for axis in range(3):
        if abs(stats["size_yup"][axis] - expect_yup[axis]) > SIZE_TOL:
            flags.append("世界尺寸[%s] %.3f != %.3f"
                         % ("xyz"[axis], stats["size_yup"][axis], expect_yup[axis]))
    if abs(stats["bbox_min"][1] - expected["bbox_min"][2]) > Z_TOL:
        flags.append("基准高度 %.3f != %.3f"
                     % (stats["bbox_min"][1], expected["bbox_min"][2]))
    if set(stats["materials"]) != expected["mats"]:
        flags.append("材质集合不符 %s" % sorted(set(stats["materials"]) ^ expected["mats"]))
    if not stats["double_sided"]:
        flags.append("存在非 doubleSided 材质")
    if stats["prims_without_uv"]:
        flags.append("图元缺 UV %d" % stats["prims_without_uv"])
    if stats["has_cameras"]:
        flags.append("GLB 含相机")

    # 外部共享贴图
    for image in stats["images"]:
        if image.get("embedded"):
            flags.append("存在内嵌贴图")
            continue
        uri = image.get("uri") or ""
        if not uri.startswith(TEX_PREFIX):
            flags.append("贴图 URI 非 shared_materials：%s" % uri)
            continue
        texture = os.path.basename(uri)[:-len(".png")]
        authored = os.path.join(TILES_DIR, texture + ".png")
        resolved = os.path.join(DEV_DIR, uri)
        core = os.path.join(CORE_DIR, uri)
        if not os.path.isfile(resolved):
            flags.append("缺少贴图 %s" % uri)
        elif not os.path.isfile(authored) or _sha(resolved) != _sha(authored):
            flags.append("贴图 %s 与授权 tile 不一致" % uri)
        if not os.path.isfile(core) or _sha(core) != _sha(resolved if os.path.isfile(resolved) else authored):
            flags.append("Core 贴图副本不一致 %s" % uri)

    core_glb = os.path.join(CORE_DIR, "%s.glb" % asset)
    if not os.path.isfile(core_glb) or _sha(core_glb) != _sha(path):
        flags.append("Core GLB 副本不一致")

    # 节点名唯一 / 无 .001
    seen = set()
    for node in nodes:
        name = node.get("name", "")
        if name in seen:
            flags.append("节点名重复 %s" % name)
        seen.add(name)
        if ".001" in name:
            flags.append("出现 .001：%s" % name)

    # 接口节点
    root_extras = extras_by_name.get(expected["root"], {})
    missing_extras = REQUIRED_EXTRAS - set(root_extras)
    if missing_extras:
        flags.append("Root extras 缺 %s" % ",".join(sorted(missing_extras)))
    if root_extras.get("rig_sockets") != expected["sockets"]:
        flags.append("Root rig_sockets 不符：%s" % root_extras.get("rig_sockets"))
    if int(root_extras.get("rig_socket_count", -1)) != len(expected["sockets"]):
        flags.append("Root rig_socket_count 不符")
    if root_extras.get("rig_socket_spec") != "rig-sockets@1":
        flags.append("Root rig_socket_spec 不符")
    for name in expected["sockets"]:
        if name not in extras_by_name:
            flags.append("缺少接口节点 %s" % name)
            continue
        node = next(n for n in nodes if n.get("name", "") == name)
        if "mesh" in node:
            flags.append("%s 带 mesh（应为空节点）" % name)
        if node.get("extras", {}).get("socket_spec") != "rig-sockets@1":
            flags.append("%s socket_spec 不符" % name)
    for name in extras_by_name:
        if name.startswith(("SN_Socket_", "SN_Mount")) and name not in expected["sockets"]:
            flags.append("规格外接口节点 %s" % name)

    return {
        "asset": asset,
        "passed": not flags,
        "nodes": stats["nodes"],
        "meshes": stats["meshes"],
        "tris": stats["tris"],
        "size": stats["size_yup"],
        "sockets": expected["sockets"],
        "flags": flags,
    }


def main():
    failures = 0
    total_tris = 0
    print("%-22s %5s %5s %6s %-22s %-9s %s"
          % ("glb", "nodes", "mesh", "tris", "size(Y-up x,y,z)", "sockets", "flags"))
    print("-" * 122)
    for asset in gen.ASSETS:
        report = check_asset(asset)
        total_tris += report.get("tris", 0)
        if report["passed"]:
            print("%-22s %5d %5d %6d %-22s %-9d ok" % (
                asset, report["nodes"], report["meshes"], report["tris"],
                "%.2f,%.2f,%.2f" % tuple(report["size"]),
                len(report["sockets"])))
        else:
            failures += 1
            print("%-22s FAIL %s" % (asset, report["flags"]))
    print("-" * 122)
    print("total_tris=%d failures=%d" % (total_tris, failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
