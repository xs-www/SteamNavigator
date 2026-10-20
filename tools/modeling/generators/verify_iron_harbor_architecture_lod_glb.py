# @static-doc
# 作用：批次 A 运行时建筑资产的纯 Python 结构复检：逐件解析 `dev_mods/core/assets/models/props/SN_HT_*.glb`（5×LOD0 + 5×LOD1），核对 tri/单根节点/材质槽/共享外部贴图 URI/LOD0↔LOD1 包围盒与轴心，并汇总「模型+纹理」总量是否 ≤4.5 MB。不依赖 Blender/Godot，可在 CI 与验收脚本里复跑。
#
# ### 契约与约束
# - 期望 tri 与需求 §5.1 表一致：LOD0 7436/3788/10336/3356/5116，LOD1 1584/1060/1896/776/1248；LOD1 另校验 ≤ 对应 LOD0 的 35% 与 per-asset 上限。
# - 所有 image 必须是外部 URI（`iron_harbor_shared/<cell>.png`）且文件存在、与 `docs/design/textures/iron_harbor/tiles/` 源字节一致；5 栋 LOD0+LOD1 只允许 11 个唯一 PNG。
# - bbox 以 GLB accessor 的 glTF Y-up 包围盒换算 Godot Z-up：尺寸逐轴等于工单目标（±0.05），LOD0↔LOD1 逐轴差 ≤0.02，zmin=0、x/y 包围盒中心=0。
# - 读取 `export_iron_harbor_architecture_lod_glb.CELLS` 作为「每栋应使用的 trim cell」期望；材质名必须全部是 6 个 `SN_Town_*` 调色板成员。
# - 失败项逐条打印并以退出码 2 失败；输出 `[verify-iron-harbor-lod] JSON {...}` 供报告引用。
# @end-static-doc

# -*- coding: utf-8 -*-
"""Pure-Python structure verification for the batch-A building GLBs.

Usage:
    python tools/modeling/generators/verify_iron_harbor_architecture_lod_glb.py
    python tools/modeling/generators/verify_iron_harbor_architecture_lod_glb.py --report path.json
"""

import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PROPS_DIR = os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models", "props")
SHARED_DIR = os.path.join(PROPS_DIR, "iron_harbor_shared")
TILES_DIR = os.path.join(REPO_ROOT, "docs", "design", "textures", "iron_harbor", "tiles")
MAX_RUNTIME_BYTES = 4_500_000
PALETTE = {
    "SN_Town_Brick",
    "SN_Town_Plaster",
    "SN_Town_Wood",
    "SN_Town_Iron",
    "SN_Town_Stone",
    "SN_Town_Glass",
}
#: Runtime target sizes in **Godot/glTF Y-up order** (x, y=height, z=depth).
#: Blender authoring sizes: Long 20x9x11, Short 11x9x9.5, Office 9x8x14,
#: Cargo_Shed 8x6x4.5, Tavern 10x8x8 (x, depth, height).
TARGET_SIZES = {
    "SN_HT_Warehouse_Long": (20.0, 11.0, 9.0),
    "SN_HT_Warehouse_Short": (11.0, 9.5, 9.0),
    "SN_HT_Harbor_Office": (9.0, 14.0, 8.0),
    "SN_HT_Cargo_Shed": (8.0, 4.5, 6.0),
    "SN_HT_Tavern": (10.0, 8.0, 8.0),
}
EXPECTED_TRIS = {
    "SN_HT_Warehouse_Long": {"LOD0": 7436, "LOD1": 1584, "LOD1_cap": 2602},
    "SN_HT_Warehouse_Short": {"LOD0": 3788, "LOD1": 1060, "LOD1_cap": 1325},
    "SN_HT_Harbor_Office": {"LOD0": 10336, "LOD1": 1896, "LOD1_cap": 3617},
    "SN_HT_Cargo_Shed": {"LOD0": 3356, "LOD1": 776, "LOD1_cap": 1174},
    "SN_HT_Tavern": {"LOD0": 5116, "LOD1": 1248, "LOD1_cap": 1790},
}


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _glb():
    return _load(os.path.join(HERE, "glb_shared_textures.py"), "glb_shared_textures")


def _export_config():
    return _load(os.path.join(HERE, "export_iron_harbor_architecture_lod_glb.py"),
                 "export_iron_harbor_architecture_lod_glb")


def _close(left, right, tolerance):
    return abs(float(left) - float(right)) <= tolerance


def verify_asset(glb, cells, asset):
    entry = {"asset": asset, "lods": {}, "checks": {}, "failures": []}
    failures = entry["failures"]
    structure = {}
    for lod in ("LOD0", "LOD1"):
        runtime_name = asset + ".glb" if lod == "LOD0" else "%s_%s.glb" % (asset, lod)
        path = os.path.join(PROPS_DIR, runtime_name)
        if not os.path.exists(path):
            failures.append("%s missing: %s" % (lod, os.path.relpath(path, REPO_ROOT)))
            continue
        report = glb.structure_report(path)
        structure[lod] = report
        images = report["images"]
        external = [image for image in images if image.get("uri")]
        material_cells = [material.get("image") for material in report["materials"]]
        for image in external:
            file_name = str(image["uri"]).split("/")[-1]
            tile = os.path.join(TILES_DIR, file_name)
            image["tiles_match"] = bool(image.get("sha256")) and glb.sha256_file(tile) == image["sha256"]
        checks = {
            "single_root_node": len(report["nodes"]) == 1,
            "root_node_name": report["nodes"][0]["name"] == "%s_%s" % (asset, lod) if report["nodes"] else False,
            "tris_expected": report["tris"] == EXPECTED_TRIS[asset][lod],
            "tris_within_cap": lod != "LOD1" or report["tris"] <= EXPECTED_TRIS[asset]["LOD1_cap"],
            "tris_ratio_ok": lod != "LOD1" or report["tris"] <= EXPECTED_TRIS[asset]["LOD0"] * 0.35,
            "materials_le_6": 0 < len(report["materials"]) <= 6,
            "palette_only": all(material["name"] in PALETTE for material in report["materials"]),
            "images_external": bool(images) and all(image.get("uri") for image in images),
            "images_exist": all(image.get("exists") for image in images) if images else False,
            "images_match_tiles": all(image.get("tiles_match", True) for image in images) if images else False,
        }
        bbox = report["bbox"]
        size = bbox["godot_size"] if bbox else [0, 0, 0]
        target = TARGET_SIZES[asset]
        checks["size_matches_target"] = all(_close(size[i], target[i], 0.05) for i in range(3))
        checks["grounded"] = bool(bbox) and abs(bbox["godot_min"][1]) <= 0.002
        checks["pivot_ground_centre"] = bool(bbox) and abs(
            bbox["godot_min"][0] + bbox["godot_max"][0]) <= 0.002 and abs(
            bbox["godot_min"][2] + bbox["godot_max"][2]) <= 0.002
        entry["lods"][lod] = {
            "path": report["path"],
            "bytes": report["bytes"],
            "sha256": report["sha256"],
            "tris": report["tris"],
            "nodes": [node["name"] for node in report["nodes"]],
            "materials": [material["name"] for material in report["materials"]],
            "material_images": material_cells,
            "cell_files": [str(image["uri"]).split("/")[-1] for image in external],
            "bbox_godot_size": size,
            "bbox_godot_min": bbox["godot_min"] if bbox else None,
            "image_bytes": sum(int(image["bytes"] or 0) for image in images),
            "checks": checks,
        }
        for name, passed in checks.items():
            if not passed:
                failures.append("%s %s: %s" % (lod, name, checks))
        expected_cells = cells.get(asset) or {}
        if expected_cells:
            material_names = [material["name"] for material in report["materials"]]
            expected_files = sorted({expected_cells[name] for name in material_names if name in expected_cells})
            actual_files = sorted({str(image["uri"]).split("/")[-1][:-4] for image in external})
            if actual_files != expected_files:
                failures.append("%s cells %s != expected %s" % (lod, actual_files, expected_files))
    if "LOD0" in structure and "LOD1" in structure:
        bbox0 = structure["LOD0"]["bbox"]["godot_size"]
        bbox1 = structure["LOD1"]["bbox"]["godot_size"]
        entry["checks"]["lod_bbox_consistent"] = all(_close(bbox0[i], bbox1[i], 0.02) for i in range(3))
        if not entry["checks"]["lod_bbox_consistent"]:
            failures.append("LOD0/LOD1 bbox mismatch: %s vs %s" % (bbox0, bbox1))
    entry["passed"] = not failures
    return entry


def main(argv):
    glb = _glb()
    export_config = _export_config()
    report_path = None
    index = 1
    while index < len(argv):
        if argv[index] == "--report":
            index += 1
            report_path = os.path.abspath(argv[index])
        index += 1
    report = {"assets": {}, "totals": {}, "passed": True, "failures": []}
    total_bytes = 0
    total_tris_lod0 = 0
    total_tris_lod1 = 0
    for spec in export_config.ASSETS:
        asset = spec["asset"]
        entry = verify_asset(glb, export_config.CELLS, asset)
        report["assets"][asset] = entry
        total_bytes += sum(int(lod["bytes"]) for lod in entry["lods"].values())
        if "LOD0" in entry["lods"]:
            total_tris_lod0 += int(entry["lods"]["LOD0"]["tris"])
        if "LOD1" in entry["lods"]:
            total_tris_lod1 += int(entry["lods"]["LOD1"]["tris"])
        if not entry["passed"]:
            report["passed"] = False
            report["failures"].extend("%s: %s" % (asset, failure) for failure in entry["failures"])
    pngs = {}
    if os.path.isdir(SHARED_DIR):
        for file_name in sorted(os.listdir(SHARED_DIR)):
            if not file_name.endswith(".png"):
                continue
            path = os.path.join(SHARED_DIR, file_name)
            tile = os.path.join(TILES_DIR, file_name)
            pngs[file_name] = {
                "bytes": os.path.getsize(path),
                "sha256": glb.sha256_file(path),
                "tile_sha256": glb.sha256_file(tile),
                "matches_tile": glb.sha256_file(path) == glb.sha256_file(tile),
            }
    png_bytes = sum(entry["bytes"] for entry in pngs.values())
    total = total_bytes + png_bytes
    report["totals"] = {
        "glb_lod0_lod1_bytes": total_bytes,
        "shared_pngs": len(pngs),
        "shared_png_bytes": png_bytes,
        "runtime_model_plus_texture_bytes": total,
        "runtime_model_plus_texture_mb": round(total / 1e6, 3),
        "max_runtime_bytes": MAX_RUNTIME_BYTES,
        "within_runtime_budget": total <= MAX_RUNTIME_BYTES,
        "lod0_visible_tris": total_tris_lod0,
        "lod1_combo_tris": total_tris_lod1,
        "lod1_combo_within_20000": total_tris_lod1 <= 20000,
        "visible_town_buildings_within_60000": max(total_tris_lod0, total_tris_lod1) <= 60000,
    }
    checks = [pngs[name]["matches_tile"] for name in pngs]
    if not checks or not all(checks):
        report["passed"] = False
        report["failures"].append("shared pngs do not match authored tiles")
    if not report["totals"]["within_runtime_budget"]:
        report["passed"] = False
        report["failures"].append("runtime model+texture total %d > %d" % (total, MAX_RUNTIME_BYTES))
    if not report["totals"]["lod1_combo_within_20000"]:
        report["passed"] = False
        report["failures"].append("LOD1 combo tris %d > 20000" % total_tris_lod1)
    if report_path:
        os.makedirs(os.path.dirname(os.path.abspath(report_path)), exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2, ensure_ascii=False)
    print("[verify-iron-harbor-lod] JSON " + json.dumps(report, ensure_ascii=False))
    for asset, entry in report["assets"].items():
        lod0 = entry["lods"].get("LOD0", {})
        lod1 = entry["lods"].get("LOD1", {})
        print("%-26s LOD0 %5s tri %8s B | LOD1 %4s tri %8s B | %s" % (
            asset, lod0.get("tris", "?"), lod0.get("bytes", "?"),
            lod1.get("tris", "?"), lod1.get("bytes", "?"),
            "PASS" if entry["passed"] else "FAIL"))
    print("totals: %s" % json.dumps(report["totals"], ensure_ascii=False))
    return 0 if report["passed"] else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
