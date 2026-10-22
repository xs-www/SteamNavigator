# -*- coding: utf-8 -*-
# @static-doc
# 作用：M0-4 船体帆索安装点 `SN_Socket_Mast / Yard / Sail` 的**规格 + Blender 应用/复核**
# （纯 Python 规格段不依赖 bpy；`apply_all()` / `verify_all()` 在 Blender 内运行）。
#
# 背景：3 艘有帆索的船（明轮货轮 / 纵帆船 / 铁甲舰）的桅杆 / 横桁 / 帆安装点由
# `rig_kit` 参数化几何定义后，**几何仍焊在船体 GLB 里**（本批不做运行时装配），
# 但要在场景与 GLB 里暴露标准空节点，供后续 `ShipVisualAssembler` / 战斗层接管：
# - `SN_Socket_Mast_<Key>`：甲板上的桅杆安装点（世界 z = 该点甲板实测高度）；
# - `SN_Socket_Yard_<Key>`：横桁 / 斜桁安装点（桅杆上的桁位）；
# - `SN_Socket_Sail_<Key>`：帆面挂点（帆前下角 tack / 收帆卷中心）。
#
# 约束：
# - **零几何**：apply 只增删空节点，逐集合 mesh 数 / tri / 对象名快照必须前后一致；
# - socket 是 Root 的直接子节点，局部坐标 = 船体坐标（Root 在工作台摆位不影响）；
# - BLEND 内名字带资产前缀（`SN_PF_Socket_Mast_Fore`）避免同工作台重名，
#   GLB 导出后由 `glb_ship_rig_sockets.standardize()` 归一化为 `SN_Socket_*`；
# - Blender IDProperty 不支持字符串数组，Root 侧只写 `rig_socket_count` /
#   `rig_socket_spec`，`rig_sockets` 名单在 GLB JSON 层写。
#
# 用法：
# - 纯 Python：`python tools/modeling/generators/sn_ship_rig_sockets.py --check`
# - Blender：`runpy.run_path(<本文件>, run_name="__main__")`
# @end-static-doc

import importlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

SOCKET_SPEC = "rig-sockets@1"
KINDS = ("mast", "yard", "sail")

SHIPS = [
    {
        "asset": "SN_Paddle_Freighter",
        "prefix": "SN_PF_",
        "collection": "SN_Paddle_Freighter_Prototype",
        "root": "SN_PF_Root",
        "root_type": "EMPTY",
        "mesh_baseline": (39, 12200),
    },
    {
        "asset": "SN_Schooner_Fame",
        "prefix": "SN_SF_",
        "collection": "SN_Schooner_Fame_Prototype",
        "root": "SN_SF_Root",
        "root_type": "EMPTY",
        "mesh_baseline": (29, 13174),
    },
    {
        "asset": "SN_Ironclad",
        "prefix": "SN_IC_",
        "collection": "SN_Ironclad_Prototype",
        "root": "SN_Ironclad",
        "root_type": "MESH",
        # 2026-10-22 casemate 模块化：船体炮管拆出为独立模块后 8158 tri（原 8830）
        "mesh_baseline": (1, 8158),
    },
]


def _modules():
    """按需加载 3 艘船的生成器（取其参数表作为 socket 坐标唯一真源）。"""
    names = ("sn_paddle_freighter_generator", "sn_schooner_fame_generator",
             "sn_ironclad_generator")
    mods = {}
    for name in names:
        if name in sys.modules:
            mods[name] = importlib.reload(sys.modules[name])
        else:
            mods[name] = importlib.import_module(name)
    return mods


def _socket(kind, mast_key, local, **extra):
    glb = "SN_Socket_%s_%s" % (kind.capitalize(), mast_key)
    item = {
        "kind": kind,
        "mast_key": mast_key,
        "glb_name": glb,
        "local": (round(local[0], 6), round(local[1], 6), round(local[2], 6)),
    }
    item.update(extra)
    return item


def build_specs():
    """返回 {asset: [socket dict, ...]}；坐标来自各船生成器的参数表。"""
    mods = _modules()
    pf = mods["sn_paddle_freighter_generator"]
    sf = mods["sn_schooner_fame_generator"]
    ic = mods["sn_ironclad_generator"]
    specs = {}

    pf_sockets = []
    for index, mast in enumerate(pf.MASTS):
        key = mast["key"]
        height = mast["z_top"] - mast["z0"]
        pf_sockets.append(_socket(
            "mast", key, (mast["x"], 0.0, mast["z0"]),
            socket_index=index, height=round(height, 3), deck_z=round(mast["z0"], 3)))
        pf_sockets.append(_socket(
            "yard", key, (mast["x"] + 0.30, 0.0, mast["yard_z"]),
            socket_index=index, yard_z=round(mast["yard_z"], 3),
            yard_length=round(mast["yard_w"], 3), stowed=True))
        pf_sockets.append(_socket(
            "sail", key, (mast["x"] + 0.30, 0.0, mast["yard_z"] - 0.09),
            socket_index=index, yard_z=round(mast["yard_z"] - 0.09, 3),
            sail_area_m2=0.0, stowed=True))
    specs["SN_Paddle_Freighter"] = pf_sockets

    sf_sockets = []
    for index, key in enumerate(("Fore", "Main")):
        cfg = sf.MASTS[key]
        pivot = sf.mast_pivot_world(key)
        sf_sockets.append(_socket(
            "mast", key, pivot, socket_index=index,
            height=round(cfg["gallant"], 3), deck_z=round(pivot[2], 3)))
    # SF 有后倾：`rig_yard_z` 统一取 socket 的**船体坐标 z**（与 local z 相同），
    # 与 PF/IC 语义一致；桅局部高度只出现在 `height`（桅高）里。
    yard_fore = sf.mast_world("Fore", sf.FORE_TOPSAIL["z_head"] + 0.16)
    yard_main = sf.mast_world("Main", sf.MAIN_SAIL["throat"][2])
    sail_fore = sf.mast_world("Fore", sf.FORE_SAIL["tack"][2])
    sail_main = sf.mast_world("Main", sf.MAIN_SAIL["tack"][2])
    sf_sockets.append(_socket(
        "yard", "Fore", yard_fore,
        socket_index=0, yard_z=round(yard_fore[2], 3),
        yard_length=round(2.0 * (sf.FORE_TOPSAIL["half_head"] + 0.30), 3),
        stowed=False))
    sf_sockets.append(_socket(
        "yard", "Main", yard_main,
        socket_index=1, yard_z=round(yard_main[2], 3),
        yard_length=round(abs(sf.MAIN_SAIL["peak"][0]), 3), stowed=False))
    sf_sockets.append(_socket(
        "sail", "Fore", sail_fore,
        socket_index=0, yard_z=round(sail_fore[2], 3),
        sail_area_m2=38.0, stowed=False))
    sf_sockets.append(_socket(
        "sail", "Main", sail_main,
        socket_index=1, yard_z=round(sail_main[2], 3),
        sail_area_m2=62.0, stowed=False))
    sf_sockets.append(_socket(
        "sail", "Jib", (5.55, 0.0, 4.20), socket_index=2,
        yard_z=4.20, sail_area_m2=20.0, stowed=False))
    specs["SN_Schooner_Fame"] = sf_sockets

    ic_sockets = []
    for index, mast in enumerate(ic.MASTS):
        key = ("Fore", "Main", "Mizzen")[index]
        ic_sockets.append(_socket(
            "mast", key, (mast["x"], 0.0, ic.DECK_Z),
            socket_index=index, height=round(mast["top_top"] - ic.DECK_Z, 3),
            deck_z=round(ic.DECK_Z, 3)))
        yard_z, half = mast["yards"][0]
        ic_sockets.append(_socket(
            "yard", key, (mast["x"], 0.0, yard_z),
            socket_index=index, yard_z=round(yard_z, 3),
            yard_length=round(2.0 * half, 3), stowed=True))
        ic_sockets.append(_socket(
            "sail", key, (mast["x"], 0.0, yard_z - 0.26),
            socket_index=index, yard_z=round(yard_z - 0.26, 3),
            sail_area_m2=0.0, stowed=True))
    specs["SN_Ironclad"] = ic_sockets
    return specs


def blend_name(ship, socket):
    return ship["prefix"] + socket["glb_name"][len("SN_"):]


def expected_sockets():
    return {ship["asset"]: [blend_name(ship, sock) for sock in build_specs()[ship["asset"]]]
            for ship in SHIPS}


def check_spec():
    """纯 Python 规格自检：命名 / 数量 / 镜像 / 坐标。"""
    failures = []
    specs = build_specs()
    for ship in SHIPS:
        asset = ship["asset"]
        sockets = specs[asset]
        names = [blend_name(ship, sock) for sock in sockets]
        if len(names) != len(set(names)):
            failures.append("%s: socket 重名" % asset)
        if not (2 <= len(sockets) <= 9):
            failures.append("%s: socket 数量 %d 不在 2..9" % (asset, len(sockets)))
        for kind in KINDS:
            if not any(sock["kind"] == kind for sock in sockets):
                failures.append("%s: 缺少 %s socket" % (asset, kind))
        for sock in sockets:
            if sock["local"][2] < -0.01:
                failures.append("%s: %s z=%.2f < 0"
                                % (asset, sock["glb_name"], sock["local"][2]))
        for sock in sockets:
            if not sock["glb_name"].startswith(("SN_Socket_Mast_", "SN_Socket_Yard_",
                                                "SN_Socket_Sail_")):
                failures.append("%s: 非法 socket 名 %s"
                                % (asset, sock["glb_name"]))
    # 规格坐标必须落在船体范围内（用生成器的 bbox 兜底）
    for ship in SHIPS:
        asset = ship["asset"]
        module_name = {
            "SN_Paddle_Freighter": "sn_paddle_freighter_generator",
            "SN_Schooner_Fame": "sn_schooner_fame_generator",
            "SN_Ironclad": "sn_ironclad_generator",
        }[asset]
        module = sys.modules.get(module_name) or importlib.import_module(module_name)
        parts = module.build_all_geometry()
        xs, ys = [], []
        for name, value in parts.items():
            part = value if hasattr(value, "verts") else value[0]
            xs.extend(v[0] for v in part.verts)
            ys.extend(v[1] for v in part.verts)
        x0, x1, y0, y1 = min(xs) - 1.0, max(xs) + 1.0, min(ys) - 1.0, max(ys) + 1.0
        for sock in build_specs()[asset]:
            x, y, _z = sock["local"]
            if not (x0 <= x <= x1 and y0 <= y <= y1):
                failures.append("%s: %s 的 (x,y) 在船体 bbox 外"
                                % (asset, sock["glb_name"]))
    return {"ok": not failures, "failures": failures,
            "sockets": {asset: len(items) for asset, items in specs.items()},
            "spec": SOCKET_SPEC}


# ============================================================
# Blender 侧
# ============================================================

def _geometry_snapshot(ship):
    """集合内 mesh 名称 / tri / 面数快照（socket 只允许改空节点）。"""
    import bpy
    collection = bpy.data.collections.get(ship["collection"])
    if collection is None:
        raise RuntimeError("找不到集合 %s" % ship["collection"])
    rows = []
    for obj in sorted(collection.all_objects, key=lambda o: o.name):
        if obj.type != "MESH":
            continue
        rows.append((obj.name, len(obj.data.polygons),
                     sum(max(1, len(p.vertices) - 2) for p in obj.data.polygons)))
    return rows


def _stale_rig_empties(ship):
    import bpy
    stale = []
    for obj in bpy.data.objects:
        if obj.type != "EMPTY" or not obj.name.startswith(ship["prefix"]):
            continue
        if any(marker in obj.name for marker in ("_Socket_Mast_", "_Socket_Yard_",
                                                 "_Socket_Sail_")):
            stale.append(obj)
    return stale


def apply_ship(ship, specs):
    import bpy
    collection = bpy.data.collections.get(ship["collection"])
    if collection is None:
        raise RuntimeError("找不到集合 %s（确认工作台已打开）" % ship["collection"])
    root = bpy.data.objects.get(ship["root"])
    if root is None:
        raise RuntimeError("找不到根 %s" % ship["root"])
    before = _geometry_snapshot(ship)
    removed = []
    for obj in _stale_rig_empties(ship):
        removed.append(obj.name)
        bpy.data.objects.remove(obj, do_unlink=True)
    created = []
    for index, sock in enumerate(specs):
        name = blend_name(ship, sock)
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_type = "PLAIN_AXES"
        empty.empty_display_size = 0.5
        empty.location = sock["local"]
        collection.objects.link(empty)
        empty.parent = root
        empty["socket"] = name
        empty["socket_spec"] = SOCKET_SPEC
        empty["socket_kind"] = sock["kind"]
        empty["mast_key"] = sock["mast_key"]
        empty["socket_index"] = index
        for key, value in sock.items():
            if key in ("kind", "mast_key", "glb_name", "local", "socket_index"):
                continue
            if isinstance(value, (int, float)):
                empty["rig_" + key] = value
            elif isinstance(value, bool):
                empty["rig_" + key] = value
        created.append(name)
    root["rig_socket_spec"] = SOCKET_SPEC
    root["rig_socket_count"] = len(created)
    bpy.context.view_layer.update()
    after = _geometry_snapshot(ship)
    return {
        "asset": ship["asset"],
        "root": root.name,
        "created": created,
        "removed": removed,
        "geometry_unchanged": before == after,
        "meshes": len(after),
        "tris": sum(row[2] for row in after),
    }


def verify_ship(ship, specs):
    import bpy
    failures = []
    collection = bpy.data.collections.get(ship["collection"])
    root = bpy.data.objects.get(ship["root"])
    if collection is None:
        return {"asset": ship["asset"], "passed": False,
                "failures": ["缺少集合 %s" % ship["collection"]]}
    if root is None:
        return {"asset": ship["asset"], "passed": False,
                "failures": ["缺少根 %s" % ship["root"]]}
    expected = {blend_name(ship, sock): sock for sock in specs}
    details = []
    for name, sock in expected.items():
        obj = bpy.data.objects.get(name)
        if obj is None:
            failures.append("缺少 socket %s" % name)
            continue
        if obj.type != "EMPTY":
            failures.append("%s 不是空节点" % name)
        if obj.parent != root:
            failures.append("%s 父级不是 %s" % (name, root.name))
        for axis in range(3):
            if abs(obj.location[axis] - sock["local"][axis]) > 1e-5:
                failures.append("%s 坐标[%d] %.4f != %.4f"
                                % (name, axis, obj.location[axis],
                                   sock["local"][axis]))
        if obj.get("socket_spec") != SOCKET_SPEC:
            failures.append("%s socket_spec 不符" % name)
        if obj.get("socket_kind") != sock["kind"]:
            failures.append("%s socket_kind 不符" % name)
        if obj.get("mast_key") != sock["mast_key"]:
            failures.append("%s mast_key 不符" % name)
        details.append({"name": name, "kind": sock["kind"],
                        "local": [round(v, 3) for v in obj.location]})
    stale = [obj.name for obj in _stale_rig_empties(ship)
             if obj.name not in expected]
    if stale:
        failures.append("存在规格外 socket：%s" % stale)
    if root.get("rig_socket_count") != len(expected):
        failures.append("Root rig_socket_count %r != %d"
                        % (root.get("rig_socket_count"), len(expected)))
    if root.get("rig_socket_spec") != SOCKET_SPEC:
        failures.append("Root rig_socket_spec 不符")
    meshes = len([o for o in collection.all_objects if o.type == "MESH"])
    tris = sum(sum(max(1, len(p.vertices) - 2) for p in o.data.polygons)
               for o in collection.all_objects if o.type == "MESH")
    if (meshes, tris) != ship["mesh_baseline"]:
        failures.append("几何基线 %r != %r"
                        % ((meshes, tris), ship["mesh_baseline"]))
    return {"asset": ship["asset"], "passed": not failures,
            "sockets": details, "failures": failures,
            "meshes": meshes, "tris": tris}


def apply_all():
    specs = build_specs()
    results = []
    for ship in SHIPS:
        report = apply_ship(ship, specs[ship["asset"]])
        if not report["geometry_unchanged"]:
            raise RuntimeError("%s 几何发生变化，拒绝继续" % ship["asset"])
        results.append(report)
        print("APPLIED %-22s sockets=%d removed=%d meshes=%d tris=%d"
              % (ship["asset"], len(report["created"]), len(report["removed"]),
                 report["meshes"], report["tris"]))
    summary = verify_all()
    if not summary["passed"]:
        raise RuntimeError("rig socket 复核失败：%r"
                           % [item["failures"] for item in summary["ships"]])
    return {"spec": check_spec(), "ships": results,
            "total_sockets": sum(len(r["created"]) for r in results)}


def verify_all():
    specs = build_specs()
    ships = [verify_ship(ship, specs[ship["asset"]]) for ship in SHIPS]
    return {"passed": all(item["passed"] for item in ships), "ships": ships,
            "total_sockets": sum(len(item["sockets"]) for item in ships)}


def main():
    report = check_spec()
    print(json.dumps(report, ensure_ascii=False, indent=1))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    if any(arg == "--apply" for arg in sys.argv[1:]):
        print(json.dumps(apply_all(), ensure_ascii=False, indent=1))
    else:
        sys.exit(main())
