# -*- coding: utf-8 -*-
# @static-doc
# 作用：`rig_kit` 套件（12 件 `SN_Rig_*`）的**纯 Python 干跑**——不进入 Blender，
# 直接从 `rig_kit_batch1_generator.build_geometry()` 校验：
# 命名 / 集合前缀 / tri 预算 / bbox 与 z 基准 / 材质白名单 / 网格健康（闭合件
# 边界边与非流形边 = 0，单层帆面允许边界边）/ Mount + Socket 契约 / 坐标落在包围盒内 /
# mesh 名与 socket 名不重名。任何一项失败返回非 0 退出码。
#
# 用法：`python tools/modeling/generators/dryrun_rig_kit.py`
# @end-static-doc

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import rig_kit_batch1_generator as gen  # noqa: E402
from sn_rig_materials import ASSET_MATERIALS  # noqa: E402

SIZE_TOL = 0.06
Z_TOL = 0.06
POS_TOL = 0.02


def tri_count(part):
    return sum(max(0, len(f) - 2) for f, _m in part.faces)


def mesh_health(part):
    """返回 (boundary_edges, non_manifold_edges, loose_verts)。"""
    edge_faces = {}
    used = set()
    for face, _m in part.faces:
        for i in range(len(face)):
            a, b = face[i], face[(i + 1) % len(face)]
            key = (a, b) if a < b else (b, a)
            edge_faces[key] = edge_faces.get(key, 0) + 1
            used.add(a)
            used.add(b)
    boundary = sum(1 for count in edge_faces.values() if count == 1)
    non_manifold = sum(1 for count in edge_faces.values() if count > 2)
    loose = len(part.verts) - len(used)
    return boundary, non_manifold, loose


def bbox(parts):
    lo = [1e18] * 3
    hi = [-1e18] * 3
    for _name, (part, _parent) in parts.items():
        for v in part.verts:
            for i in range(3):
                lo[i] = min(lo[i], v[i])
                hi[i] = max(hi[i], v[i])
    return lo, hi


def check_asset(asset):
    failures = []
    spec = gen.SPECS[asset]
    prefix = spec["prefix"]
    parts = gen.build_geometry(asset)
    names = set(parts)
    sockets = gen.socket_entries(asset)
    tris = sum(tri_count(part) for part, _parent in parts.values())
    lo, hi = bbox(parts)
    size = [hi[i] - lo[i] for i in range(3)]
    mats = {m for part, _p in parts.values() for _f, m in part.faces}
    allowed = ASSET_MATERIALS[asset]

    if not names:
        failures.append("没有任何几何对象")
    for name in names:
        if not name.startswith(prefix):
            failures.append("对象 %s 未以 %s 开头" % (name, prefix))
        if name in {s["name"] for s in sockets}:
            failures.append("mesh 名与 socket 名重复：%s" % name)
    if len(names) != len(set(names)):
        failures.append("对象重名")
    if tris > spec["tri_budget"]:
        failures.append("tri %d > 预算 %d" % (tris, spec["tri_budget"]))
    for axis in range(3):
        if abs(size[axis] - spec["bbox"][axis]) > SIZE_TOL:
            failures.append("bbox[%s] %.3f != %.3f（±%.2f）"
                            % ("xyz"[axis], size[axis], spec["bbox"][axis], SIZE_TOL))
    z_lo, z_hi = spec["z_range"]
    if abs(lo[2] - z_lo) > Z_TOL or abs(hi[2] - z_hi) > Z_TOL:
        failures.append("z 范围 %.3f..%.3f != %.3f..%.3f"
                        % (lo[2], hi[2], z_lo, z_hi))
    for mat in mats:
        if mat not in allowed:
            failures.append("材质越界：%s" % mat)
    for part_name, (part, _parent) in parts.items():
        boundary, nonman, loose = mesh_health(part)
        if loose:
            failures.append("%s 有 %d 个孤立点" % (part_name, loose))
        if nonman:
            failures.append("%s 有 %d 条非流形边" % (part_name, nonman))
        if spec["closed"] and boundary:
            failures.append("%s 是闭合件但有 %d 条边界边" % (part_name, boundary))
        if not spec["closed"] and not boundary:
            failures.append("%s 是单层帆面但没有边界边（应为开放曲面）" % part_name)
        for face, _m in part.faces:
            if len(set(face)) != len(face):
                failures.append("%s 有退化面（重复顶点）" % part_name)
    # socket 契约
    prefix_roles = [s["name"] for s in sockets]
    if len(prefix_roles) != len(set(prefix_roles)):
        failures.append("socket 重名")
    mounts = [s for s in sockets if s["glb"] == "SN_Mount"]
    if len(mounts) != 1:
        failures.append("SN_Mount 数量 %d != 1" % len(mounts))
    if not any(s["glb"].startswith(("SN_Socket_Mast", "SN_Socket_Yard",
                                    "SN_Socket_Sail", "SN_Socket_"))
               for s in sockets if s["glb"] != "SN_Mount"):
        failures.append("缺少 SN_Socket_* 接口")
    for entry in sockets:
        x, y, z = entry["location"]
        for axis, value in enumerate((x, y, z)):
            # 甲板类资产的 Mount 在 z=0，几何可能从甲板上方开始（艏斜桁 / 支索），
            # 因此允许 socket 比包围盒外扩 1.0 m（仍不允许离几何太远）。
            low = lo[axis] - POS_TOL - 1.0
            high = hi[axis] + POS_TOL + 1.0
            if not (low <= value <= high):
                failures.append("socket %s 的 %s=%.2f 在包围盒外"
                                % (entry["glb"], "xyz"[axis], value))
    glb_names = gen.socket_roles(asset)
    if len(glb_names) != len(set(glb_names)):
        failures.append("GLB socket 名重复")
    return {
        "asset": asset,
        "tris": tris,
        "budget": spec["tri_budget"],
        "size": [round(v, 3) for v in size],
        "materials": sorted(mats),
        "sockets": glb_names,
        "failures": failures,
    }


def main():
    failures = 0
    total_tris = 0
    print("%-22s %5s %6s %-24s %-46s %s"
          % ("asset", "tris", "budget", "size(X,Y,Z)", "sockets", "flags"))
    print("-" * 128)
    for asset in gen.ASSETS:
        report = check_asset(asset)
        total_tris += report["tris"]
        flags = report["failures"]
        failures += len(flags)
        print("%-22s %5d %6d %-24s %-46s %s" % (
            asset, report["tris"], report["budget"],
            "%.2f,%.2f,%.2f" % tuple(report["size"]),
            ",".join(s.replace("SN_", "") for s in report["sockets"]),
            "OK" if not flags else "FAIL"))
        for flag in flags:
            print("   - " + flag)
    print("-" * 128)
    print("assets=%d total_tris=%d failures=%d"
          % (len(gen.ASSETS), total_tris, failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
