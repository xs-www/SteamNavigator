# -*- coding: utf-8 -*-
# @static-doc
# 作用：旧资产 UV 迁移（A/B 两批）的核心模块 —— 把旧纯色 `SN_*` 材质按固定映射换成
# `SN_Tex_*` 共享贴图材质，并用盒式投影补 `UVMap`（几何、轴心、对象变换一律不动），
# 同时提供几何签名对比与只读验收。
#
# 范围（见 docs/design/MODELING_BACKLOG.md）：
# - 批次 A（M0-1）：`SN_IronHarbor_Props` 31 件道具 + `SN_Port_Facilities` 6 件设施；
# - 批次 B（M0-2）：11 件船模块 + modules/SN_Boiler_Unit 占位副本 + 4 艘船 + 旧小镇
#   剩余 5 件（Fence_Row / Dock_Worker_A/B / Rowboat / Cargo_Lighter；另 5 栋旧小镇
#   建筑已在建筑套件批次用 `SN_Town_*` 图集完成，不重复迁移）。
#
# 关键契约：
# - 材质映射覆盖两批旧资产实际用到的旧名；`SN_Ore` → `SN_Tex_Iron_Red`（锈红铁矿色），
#   `SN_Canvas` / `SN_Canvas_Shade` → 唯一 `SN_Tex_Canvas_Shade`；
#   船体旧名：`SN_Iron_Hull` / `SN_Hull_Black` → `SN_Tex_Iron`（黑船身保留深色读感）、
#   `SN_Ochre` → `SN_Tex_Wood_Deck`、`SN_White` / `SN_PS_UpperWhite` → `SN_Tex_Canvas_Shade`、
#   `SN_Flag_Red` → `SN_Tex_Iron_Red`、`SN_Flag_White` → `SN_Tex_Canvas_Shade`、
#   `SN_Flag_Blue` → `SN_Tex_Glass_Dark`。
# - UV 空间：单 mesh 道具 / 模块 / 小镇用 `space="local"`；多节点船体用 `space="root"`
#   （根节点局部坐标，跨子件连续且不烘入工作台摆位）。
# - 迁移前记录几何签名（顶点坐标 + 面顶点索引 + 三角面数 + 对象变换），迁移后必须完全一致；
#   任何几何变化都是失败，不允许用"重新生成"掩盖。
# - 只改材质槽与 UV 层；材质 datablock 由 `sn_shared_materials.build_materials()` 统一创建，
#   贴图真源仍是 `docs/design/textures/shared_materials/shared_materials.spec.json`。
#
# 用法（Blender 内，由 Lead 执行）：
#   import runpy; ns = runpy.run_path(<本文件>, run_name="__main__")   # 默认批次 A
#   ns["migrate_all_b"]()                                              # 批次 B
# 纯 Python 预检：dryrun_legacy_uv.py（A）/ dryrun_legacy_uv_b.py（B）
# @end-static-doc

import hashlib
import json
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
REPORT_PATH = os.path.join(REPO_ROOT, ".design", "legacy_uv", "migration_report.json")
REPORT_PATH_B = os.path.join(REPO_ROOT, ".design", "legacy_uv_b", "migration_report.json")
UV_SPACE = "local"

# 类别 -> 工作台集合名
COLLECTIONS = {
    "props": "SN_IronHarbor_Props",
    "port": "SN_Port_Facilities",
}

# 类别 -> 本次迁移的 37 件对象名（props 31 + port 6）
TARGETS = {
    "props": [
        "SN_Barrel", "SN_Bell", "SN_Boiler_Unit", "SN_Buoy", "SN_Capstan",
        "SN_Cargo_Net", "SN_Chain_Coil", "SN_Coal_Chute", "SN_Coal_Pile",
        "SN_Crate", "SN_Dock_Fender", "SN_Dock_Ladder", "SN_Dock_Stairs",
        "SN_Dock_Wall", "SN_Fender_Ball", "SN_Flag_Pole", "SN_Gangway",
        "SN_Gas_Lamp", "SN_Gear_Crate", "SN_Grab_Bucket", "SN_Handcart",
        "SN_Keel_Block", "SN_Mooring_Bollard", "SN_Mooring_Rope", "SN_Ore_Pile",
        "SN_Pallet", "SN_Plate_Stack", "SN_Port_Sign", "SN_Sack_Pile",
        "SN_Steam_Pipe", "SN_Timber_Stack",
    ],
    "port": [
        "SN_Dry_Dock", "SN_Market_Stall", "SN_Notice_Board",
        "SN_Shipyard_Gantry", "SN_Signal_Tower", "SN_Water_Tank",
    ],
}

# 旧纯色材质 -> 共享贴图材质（A + B 两批实际使用的旧名 + 同类常见旧名）。
LEGACY_TO_SHARED = {
    "SN_Wood": "SN_Tex_Wood",
    "SN_Wood_Dark": "SN_Tex_Wood_Dark",
    "SN_Wood_Deck": "SN_Tex_Wood_Deck",
    "SN_Metal": "SN_Tex_Metal",
    "SN_Iron": "SN_Tex_Iron",
    "SN_Iron_Red": "SN_Tex_Iron_Red",
    "SN_Stone": "SN_Tex_Stone",
    "SN_Brass": "SN_Tex_Brass",
    "SN_Canvas": "SN_Tex_Canvas_Shade",
    "SN_Canvas_Shade": "SN_Tex_Canvas_Shade",
    "SN_Coal": "SN_Tex_Coal",
    "SN_Ore": "SN_Tex_Iron_Red",
    "SN_Glass_Dark": "SN_Tex_Glass_Dark",
    # 批次 B：船体 / 帆布 / 旗帜旧材质
    "SN_Iron_Hull": "SN_Tex_Iron",
    "SN_Hull_Black": "SN_Tex_Iron",
    "SN_Ochre": "SN_Tex_Wood_Deck",
    "SN_White": "SN_Tex_Canvas_Shade",
    "SN_PS_UpperWhite": "SN_Tex_Canvas_Shade",
    "SN_Flag_Red": "SN_Tex_Iron_Red",
    "SN_Flag_White": "SN_Tex_Canvas_Shade",
    "SN_Flag_Blue": "SN_Tex_Glass_Dark",
}

# ---------------------------------------------------------------------------
# 批次 B（M0-2）目标：11 件船模块 + modules 占位副本 + 4 艘船 + 旧小镇剩余 5 件
# ---------------------------------------------------------------------------

# 单 mesh、局部空间 UV 的对象（模块 / 旧小镇 / 单 mesh 铁甲舰）
BATCH_B_SINGLE = {
    "modules": [
        "SN_Boiler_Efficient", "SN_Boiler_Performance", "SN_Boiler_Standard",
        "SN_Boiler_Unit", "SN_Cabin_Passenger", "SN_Cargo_Large_Hold",
        "SN_Cargo_Medium_Hold", "SN_Cargo_Small_Hold", "SN_Nav_Chart_Room",
        "SN_Nav_Spyglass", "SN_Safety_Lifeboat", "SN_Safety_Valve",
    ],
    "town": [
        "SN_HT_Cargo_Lighter", "SN_HT_Dock_Worker_A", "SN_HT_Dock_Worker_B",
        "SN_HT_Fence_Row", "SN_HT_Rowboat",
    ],
    "ships": ["SN_Ironclad"],
}

# 多节点船体：集合 + 根节点；UV 用根节点局部空间（跨子件连续）
BATCH_B_SHIPS = [
    ("SN_Paddle_Freighter", "SN_Paddle_Freighter_Prototype", "SN_PF_Root"),
    ("SN_Paddle_Steamer", "SN_Paddle_Steamer_Prototype", "SN_PS_Root"),
    ("SN_Schooner_Fame", "SN_Schooner_Fame_Prototype", "SN_SF_Root"),
]

# 预置集合名（单 mesh 对象所在集合），用于迁移后校验对象归属
BATCH_B_COLLECTIONS = {
    "modules": "SN_Ship_Modules",
    "town": "SN_Harbor_Town",
    "ships": "SN_Ironclad_Prototype",
}

# modules/SN_Boiler_Unit 是 props 锅炉在模块目录的占位副本，工作台对象仍住在道具集合
BATCH_B_OBJECT_COLLECTIONS = {
    "SN_Boiler_Unit": "SN_IronHarbor_Props",
}


# --------------------------------------------------------------------------- #
# 纯 Python：契约检查（dryrun 用，不需要 bpy）
# --------------------------------------------------------------------------- #

def all_target_names():
    return [name for names in TARGETS.values() for name in names]


def check_static_contract():
    """静态契约：目标清单、材质映射与共享材质 spec 是否自洽。"""
    import sn_shared_materials as sm

    specs = sm.material_specs()
    names = all_target_names()
    checks = {
        "target_count_37": len(names) == 37,
        "props_31_port_6": (len(TARGETS["props"]) == 31
                            and len(TARGETS["port"]) == 6),
        "targets_unique": len(names) == len(set(names)),
        "no_overlap_between_categories": not (set(TARGETS["props"])
                                              & set(TARGETS["port"])),
        "mapping_targets_in_spec": all(v in specs for v in LEGACY_TO_SHARED.values()),
        "uv_space_local": UV_SPACE == "local",
    }
    failures = [key for key, ok in checks.items() if not ok]
    return {
        "ok": not failures,
        "checks": checks,
        "failures": failures,
        "mapped_materials": sorted(set(LEGACY_TO_SHARED.values())),
        "legacy_materials": sorted(LEGACY_TO_SHARED.keys()),
        "tiles": {name: sm.texture_report()[name]["exists"]
                  for name in sorted(set(LEGACY_TO_SHARED.values()))},
    }


# --------------------------------------------------------------------------- #
# Blender 侧：几何签名 / 迁移 / 验收
# --------------------------------------------------------------------------- #

def _geometry_signature(obj):
    """顶点坐标（1e-6 量化）+ 面顶点索引 + 三角面数 + 对象变换的 SHA-256。"""
    mesh = obj.data
    digest = hashlib.sha256()
    for vert in mesh.vertices:
        digest.update(struct.pack("<3d",
                                  round(vert.co.x, 6),
                                  round(vert.co.y, 6),
                                  round(vert.co.z, 6)))
    for poly in mesh.polygons:
        digest.update(struct.pack("<ii", poly.loop_start, poly.loop_total))
        for li in range(poly.loop_start, poly.loop_start + poly.loop_total):
            digest.update(struct.pack("<i", mesh.loops[li].vertex_index))
    mesh.calc_loop_triangles()
    transform = (tuple(round(v, 9) for v in obj.location)
                 + tuple(round(v, 9) for v in obj.rotation_euler)
                 + tuple(round(v, 9) for v in obj.scale))
    return {
        "sha256": digest.hexdigest(),
        "verts": len(mesh.vertices),
        "polys": len(mesh.polygons),
        "loops": len(mesh.loops),
        "tris": len(mesh.loop_triangles),
        "transform": transform,
    }


def object_stats(obj):
    """迁移前后的可对比事实：几何签名 + 材质面数 + UV / 包围盒。"""
    signature = _geometry_signature(obj)
    mesh = obj.data
    usage = {}
    slot_names = [m.name if m else None for m in mesh.materials]
    for poly in mesh.polygons:
        name = slot_names[poly.material_index] if slot_names else None
        usage[name] = usage.get(name, 0) + 1
    uv_layer = mesh.uv_layers.get("UVMap")
    return {
        "object": obj.name,
        "geometry": signature,
        "slots": slot_names,
        "material_usage": usage,
        "uv_layer": uv_layer.name if uv_layer else None,
        "uv_loops": len(uv_layer.data) if uv_layer else 0,
    }


def _target_material(name, specs):
    """旧材质名 -> SN_Tex_* 目标；已经是共享材质则原样返回，未知返回 None。"""
    if name in LEGACY_TO_SHARED:
        return LEGACY_TO_SHARED[name]
    if name in specs:
        return name
    return None


def migrate_object(obj, specs=None, space=UV_SPACE, root=None):
    """把单个 mesh 对象的旧材质换成 SN_Tex_* 并补 UV；返回迁移报告。

    幂等：已经切换过的对象再跑一次只会重写 UV，不会报"未映射"。
    ``space`` / ``root`` 透传给 ``sn_shared_materials.apply_to_object``（见其文档）。
    """
    import bpy
    import sn_shared_materials as sm

    specs = specs or sm.material_specs()
    mesh = obj.data
    before = object_stats(obj)
    if len(mesh.materials) == 0:
        return {"ok": False, "object": obj.name, "error": "no material slots"}

    # 1) 旧材质 -> SN_Tex_*，保持槽位顺序；面索引不变。
    remap = {}
    unknown = []
    targets = []
    for slot in mesh.materials:
        name = slot.name if slot else None
        target = _target_material(name, specs)
        if target is None:
            unknown.append(name)
            targets.append(None)
            continue
        if name in LEGACY_TO_SHARED:
            remap[name] = target
        targets.append(target)
    if unknown:
        return {"ok": False, "object": obj.name,
                "error": "unmapped legacy materials: %s" % unknown}
    for i, target in enumerate(targets):
        mat = bpy.data.materials.get(target)
        if mat is None:
            sm.build_materials()
            mat = bpy.data.materials.get(target)
        if mat is None:
            return {"ok": False, "object": obj.name,
                    "error": "missing shared material %s" % target}
        mesh.materials[i] = mat

    # 2) 重建材质槽（去重）+ 写盒式 UV（local / root 空间）。
    uv_report = sm.apply_to_object(obj, specs=specs, space=space, root=root)
    if not uv_report.get("ok"):
        return {"ok": False, "object": obj.name, "error": uv_report.get("error"),
                "uv_report": uv_report}

    after = object_stats(obj)

    # 3) 几何必须逐位一致；面材质计数按映射后名称对比。
    expected_usage = {}
    for name, count in before["material_usage"].items():
        target = _target_material(name, specs)
        expected_usage[target] = expected_usage.get(target, 0) + count
    checks = {
        "geometry_signature_unchanged":
            before["geometry"]["sha256"] == after["geometry"]["sha256"],
        "geometry_counts_unchanged":
            (before["geometry"]["verts"], before["geometry"]["polys"],
             before["geometry"]["loops"], before["geometry"]["tris"])
            == (after["geometry"]["verts"], after["geometry"]["polys"],
                after["geometry"]["loops"], after["geometry"]["tris"]),
        "transform_unchanged":
            before["geometry"]["transform"] == after["geometry"]["transform"],
        "material_slots_shared":
            all(name in specs for name in after["slots"]),
        "material_usage_preserved": after["material_usage"] == expected_usage,
        "uv_layer_complete":
            after["uv_layer"] == "UVMap"
            and after["uv_loops"] == after["geometry"]["loops"],
        "images_bound_512": _images_bound_512(mesh, specs),
    }
    failures = [key for key, ok in checks.items() if not ok]
    return {
        "ok": not failures,
        "object": obj.name,
        "checks": checks,
        "failures": failures,
        "before": before,
        "after": after,
        "remap": remap,
        "uv_report": uv_report,
    }


def _images_bound_512(mesh, specs):
    import bpy
    for mat in mesh.materials:
        if mat is None or mat.name not in specs:
            return False
        tex = None
        if mat.use_nodes and mat.node_tree:
            tex = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"), None)
        if tex is None or tex.image is None or tuple(tex.image.size) != (512, 512):
            return False
    return True


def _collection(category):
    import bpy
    collection = bpy.data.collections.get(COLLECTIONS[category])
    if collection is None:
        raise RuntimeError("找不到集合 %s" % COLLECTIONS[category])
    return collection


def migrate_all(categories=("props", "port")):
    """迁移 37 件；不保存 .blend、不导出 GLB（由 export_legacy_uv_glb.py 负责）。"""
    import importlib

    import bpy
    import sn_shared_materials as sm

    # 活体 Blender 会缓存纯 Python 模块：本文件与 sn_shared_materials 都可能在
    # 之前的会话里被加载过，先 reload 再跑，避免用到旧签名（见 MODELING_WORKFLOW §11.13）。
    importlib.reload(sm)
    sm.build_materials()
    specs = sm.material_specs()
    items = []
    failures = []
    for category in categories:
        collection = _collection(category)
        for name in TARGETS[category]:
            obj = bpy.data.objects.get(name)
            if obj is None or obj.type != "MESH":
                failures.append({"object": name, "error": "missing mesh object"})
                continue
            if obj.name not in collection.objects:
                failures.append({"object": name,
                                 "error": "not in collection %s" % collection.name})
                continue
            report = migrate_object(obj, specs=specs)
            report["category"] = category
            items.append(report)
            if not report.get("ok"):
                failures.append({"object": name, "error": report.get("error")
                                 or report.get("failures")})
            print("[%s] %-22s slots=%s uv_loops=%d %s" % (
                "OK" if report.get("ok") else "FAIL", name,
                ",".join(report.get("after", {}).get("slots", [])),
                report.get("after", {}).get("uv_loops", 0),
                "" if report.get("ok") else report.get("failures")))
    report = {
        "ok": not failures,
        "uv_space": UV_SPACE,
        "categories": list(categories),
        "objects": len(items),
        "failures": failures,
        "items": items,
        "summary": {
            "props": sum(1 for i in items if i.get("category") == "props"),
            "port": sum(1 for i in items if i.get("category") == "port"),
            "tris": sum(i["after"]["geometry"]["tris"] for i in items
                        if i.get("after")),
            "uv_loops": sum(i["after"]["uv_loops"] for i in items
                            if i.get("after")),
            "materials": sorted({m for i in items if i.get("after")
                                 for m in i["after"]["slots"]}),
        },
    }
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=1)
    print("LEGACY_UV_REPORT %r" % report["summary"])
    print("LEGACY_UV_OK", report["ok"], "failures", len(failures))
    return report


def verify_scene(categories=("props", "port")):
    """只读验收：集合内 37 件都已切 SN_Tex_*、UV 完整、贴图绑定 512。"""
    import bpy
    import sn_shared_materials as sm

    specs = sm.material_specs()
    failures = []
    items = []
    for category in categories:
        collection = _collection(category)
        present = {o.name for o in collection.objects if o.type == "MESH"}
        for name in TARGETS[category]:
            obj = bpy.data.objects.get(name)
            if obj is None or obj.name not in present:
                failures.append("%s: missing" % name)
                continue
            mesh = obj.data
            uv_layer = mesh.uv_layers.get("UVMap")
            slots = [m.name if m else None for m in mesh.materials]
            checks = {
                "uv_complete": uv_layer is not None
                and len(uv_layer.data) == len(mesh.loops),
                "slots_shared": bool(slots) and all(s in specs for s in slots),
                "no_legacy_slots": not any(s in LEGACY_TO_SHARED for s in slots),
                "images_bound_512": _images_bound_512(mesh, specs),
            }
            if not all(checks.values()):
                failures.append("%s: %s" % (name, [k for k, v in checks.items()
                                                   if not v]))
            items.append({"object": name, "category": category, "checks": checks,
                          "slots": slots})
    return {"ok": not failures, "failures": failures, "items": items,
            "objects": len(items)}


# ---------------------------------------------------------------------------
# 批次 B：迁移 / 只读验收
# ---------------------------------------------------------------------------

BATCH_B_ASSETS = {
    "modules": list(BATCH_B_SINGLE["modules"]),
    "ships": list(BATCH_B_SINGLE["ships"]) + [asset for asset, _c, _r in BATCH_B_SHIPS],
    "town": list(BATCH_B_SINGLE["town"]),
}


def b_asset_names():
    return [name for names in BATCH_B_ASSETS.values() for name in names]


def _is_descendant(obj, root):
    node = obj
    while node is not None:
        if node == root:
            return True
        node = node.parent
    return False


def _ship_meshes(collection_name):
    import bpy
    collection = bpy.data.collections.get(collection_name)
    if collection is None:
        raise RuntimeError("找不到集合 %s" % collection_name)
    return sorted([o for o in collection.all_objects if o.type == "MESH"],
                  key=lambda o: o.name)


def migrate_ship(asset, collection_name, root_name, specs):
    """迁移一条多节点船体：集合内全部 mesh 用根节点局部空间 UV。"""
    import bpy
    import sn_shared_materials as sm

    collection = bpy.data.collections.get(collection_name)
    root = bpy.data.objects.get(root_name)
    if collection is None:
        return {"ok": False, "asset": asset, "category": "ships",
                "error": "missing collection %s" % collection_name}
    if root is None:
        return {"ok": False, "asset": asset, "category": "ships",
                "error": "missing root %s" % root_name}

    entries = []
    failures = []
    for obj in _ship_meshes(collection_name):
        report = migrate_object(obj, specs=specs, space="root", root=root)
        report["descendant_of_root"] = _is_descendant(obj, root)
        entries.append(report)
        if not report.get("ok"):
            failures.append({"object": obj.name, "error": report.get("error")
                             or report.get("failures")})
        print("[%s] %-26s slots=%s uv_loops=%d %s" % (
            "OK" if report.get("ok") else "FAIL", obj.name,
            ",".join(report.get("after", {}).get("slots", [])),
            report.get("after", {}).get("uv_loops", 0),
            "" if report.get("ok") else report.get("failures")))
    checks = {
        "all_meshes_migrated": not failures,
        "all_meshes_under_root": all(e["descendant_of_root"] for e in entries),
        "uv_complete": all(e.get("after", {}).get("uv_layer") == "UVMap"
                           and e["after"]["uv_loops"] == e["after"]["geometry"]["loops"]
                           for e in entries),
        "slots_shared": all(all(m in specs for m in e.get("after", {}).get("slots", []))
                            for e in entries),
    }
    failed_checks = [k for k, v in checks.items() if not v]
    return {
        "ok": not failed_checks,
        "category": "ships",
        "asset": asset,
        "collection": collection_name,
        "root": root_name,
        "objects": len(entries),
        "tris": sum(e["after"]["geometry"]["tris"] for e in entries if e.get("after")),
        "uv_loops": sum(e["after"]["uv_loops"] for e in entries if e.get("after")),
        "materials": sorted({m for e in entries if e.get("after")
                             for m in e["after"]["slots"]}),
        "checks": checks,
        "failures": failed_checks + failures,
        "entries": entries,
    }


def migrate_all_b(categories=("modules", "town", "ships")):
    """迁移批次 B（21 个 GLB 对应的对象 / 集合）；不保存 .blend、不导出 GLB。"""
    import importlib

    import bpy
    import sn_shared_materials as sm

    importlib.reload(sm)
    sm.build_materials()
    specs = sm.material_specs()
    items = []
    failures = []

    for category in ("modules", "town", "ships"):
        if category not in categories:
            continue
        for name in BATCH_B_SINGLE[category]:
            obj = bpy.data.objects.get(name)
            expected_collection = BATCH_B_OBJECT_COLLECTIONS.get(
                name, BATCH_B_COLLECTIONS[category])
            if obj is None or obj.type != "MESH":
                failures.append({"asset": name, "category": category,
                                 "error": "missing mesh object"})
                continue
            collection = bpy.data.collections.get(expected_collection)
            if collection is None or obj.name not in collection.objects:
                failures.append({"asset": name, "category": category,
                                 "error": "not in collection %s" % expected_collection})
                continue
            report = migrate_object(obj, specs=specs, space="local")
            report["category"] = category
            report["asset"] = name
            items.append(report)
            if not report.get("ok"):
                failures.append({"asset": name, "category": category,
                                 "error": report.get("error") or report.get("failures")})
            print("[%s] %-24s slots=%s uv_loops=%d %s" % (
                "OK" if report.get("ok") else "FAIL", name,
                ",".join(report.get("after", {}).get("slots", [])),
                report.get("after", {}).get("uv_loops", 0),
                "" if report.get("ok") else report.get("failures")))

    if "ships" in categories:
        for asset, collection_name, root_name in BATCH_B_SHIPS:
            report = migrate_ship(asset, collection_name, root_name, specs)
            report["asset"] = asset
            items.append(report)
            if not report.get("ok"):
                failures.append({"asset": asset, "category": "ships",
                                 "error": report.get("failures")})

    report = {
        "ok": not failures,
        "batch": "B",
        "categories": list(categories),
        "assets": len(BATCH_B_ASSETS["modules"]) + len(BATCH_B_ASSETS["ships"])
        + len(BATCH_B_ASSETS["town"]),
        "failures": failures,
        "items": items,
        "summary": {
            "modules": len(BATCH_B_ASSETS["modules"]),
            "ships": len(BATCH_B_ASSETS["ships"]),
            "town": len(BATCH_B_ASSETS["town"]),
            "mesh_objects": sum(i.get("objects", 1) for i in items),
            "tris": sum(i["tris"] if "tris" in i else
                        i["after"]["geometry"]["tris"] for i in items if i.get("ok")),
            "uv_loops": sum(i["uv_loops"] if "uv_loops" in i else
                            i["after"]["uv_loops"] for i in items if i.get("ok")),
            "materials": sorted({m for i in items if i.get("ok")
                                 for m in (i["materials"] if "materials" in i
                                           else i["after"]["slots"])}),
        },
    }
    os.makedirs(os.path.dirname(REPORT_PATH_B), exist_ok=True)
    with open(REPORT_PATH_B, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=1)
    print("LEGACY_UV_B_REPORT %r" % report["summary"])
    print("LEGACY_UV_B_OK", report["ok"], "failures", len(failures))
    return report


def _mesh_checks(mesh, specs):
    uv_layer = mesh.uv_layers.get("UVMap")
    slots = [m.name if m else None for m in mesh.materials]
    return {
        "uv_complete": uv_layer is not None and len(uv_layer.data) == len(mesh.loops),
        "slots_shared": bool(slots) and all(s in specs for s in slots),
        "no_legacy_slots": not any(s in LEGACY_TO_SHARED for s in slots),
        "images_bound_512": _images_bound_512(mesh, specs),
    }


def verify_scene_b(categories=("modules", "town", "ships")):
    """只读验收批次 B：单 mesh 对象 + 多节点船体全部切 SN_Tex_* / UV 完整。"""
    import bpy
    import sn_shared_materials as sm

    specs = sm.material_specs()
    failures = []
    items = []
    if "modules" in categories or "town" in categories:
        for category in ("modules", "town"):
            if category not in categories:
                continue
            for name in BATCH_B_SINGLE[category]:
                obj = bpy.data.objects.get(name)
                expected_collection = BATCH_B_OBJECT_COLLECTIONS.get(
                    name, BATCH_B_COLLECTIONS[category])
                collection = bpy.data.collections.get(expected_collection)
                present = {o.name for o in collection.objects if o.type == "MESH"} \
                    if collection else set()
                if obj is None or obj.name not in present:
                    failures.append("%s: missing" % name)
                    continue
                checks = _mesh_checks(obj.data, specs)
                if not all(checks.values()):
                    failures.append("%s: %s" % (name, [k for k, v in checks.items()
                                                       if not v]))
                items.append({"asset": name, "category": category,
                              "checks": checks, "objects": 1})
    if "ships" in categories:
        for asset, collection_name, root_name in BATCH_B_SHIPS:
            try:
                meshes = _ship_meshes(collection_name)
            except RuntimeError as exc:
                failures.append(str(exc))
                continue
            for obj in meshes:
                checks = _mesh_checks(obj.data, specs)
                if not all(checks.values()):
                    failures.append("%s/%s: %s" % (
                        asset, obj.name, [k for k, v in checks.items() if not v]))
            items.append({"asset": asset, "category": "ships",
                          "checks": {"meshes": len(meshes)},
                          "objects": len(meshes)})
        # 单 mesh 铁甲舰
        for name in BATCH_B_SINGLE["ships"]:
            obj = bpy.data.objects.get(name)
            if obj is None:
                failures.append("%s: missing" % name)
                continue
            checks = _mesh_checks(obj.data, specs)
            if not all(checks.values()):
                failures.append("%s: %s" % (name, [k for k, v in checks.items()
                                                   if not v]))
            items = [i for i in items if i["asset"] != name]
            items.append({"asset": name, "category": "ships",
                          "checks": checks, "objects": 1})
    return {"ok": not failures, "failures": failures, "items": items,
            "assets": len(items),
            "mesh_objects": sum(i["objects"] for i in items)}


if __name__ == "__main__":
    result = migrate_all()
    print(json.dumps(result["summary"], ensure_ascii=False))
