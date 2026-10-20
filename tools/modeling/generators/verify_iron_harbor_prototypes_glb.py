# @static-doc
# 作用：批次 B 三栋新原型（Boiler House / Workshop Row / Brick Tenement）运行时 GLB 的纯 Python 结构复检：逐件解析 LOD0+LOD1，核对 tri（LOD0 精确值 / LOD1 硬上限）、单根节点、材质槽、共享外部贴图 URI、LOD0↔LOD1 包围盒与轴心，并汇总「新原型模型+新增共享贴图」的包体增量。不依赖 Blender/Godot，可在 CI 与验收脚本里复跑。
#
# ### 契约与约束
# - LOD0 期望 tri 精确等于需求/构建报表：BH 7 388 / WR 7 312 / BT 9 376；LOD1 期望精确 2 536 / 2 444 / 2 704 且必须 ≤ 硬上限 2 800 / 2 800 / 4 900 与 ≤ LOD0 35%。
# - 所有 image 必须是外部 URI（`iron_harbor_shared/<cell>.png`）且文件存在、与 `docs/design/textures/iron_harbor/tiles/` 源字节一致。
# - 尺寸以 Godot/glTF Y-up 顺序校验：BH 12×12×10、WR 18×8.5×7、BT 10×12×8（x, height, depth，容差 ±0.10）；LOD0↔LOD1 逐轴差 ≤0.02；zmin=0、x/z 包围盒中心=0。
# - 读取 `export_iron_harbor_prototypes_glb.CELLS` 作为每栋应使用的 trim cell 期望；材质名必须全部是 `SN_Town_*`。
# - 失败项逐条打印并以退出码 2 失败；输出 `[verify-iron-harbor-prototypes] JSON {...}`。
# @end-static-doc

# -*- coding: utf-8 -*-
"""Pure-Python structure verification for the batch-B prototype GLBs."""

import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PROPS_DIR = os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models", "props")
SHARED_DIR = os.path.join(PROPS_DIR, "iron_harbor_shared")
TILES_DIR = os.path.join(REPO_ROOT, "docs", "design", "textures", "iron_harbor", "tiles")
PALETTE = {"SN_Town_Brick", "SN_Town_Plaster", "SN_Town_Wood", "SN_Town_Iron", "SN_Town_Stone", "SN_Town_Glass"}
#: Godot/glTF Y-up target sizes (x, height, depth); Blender authoring x/y/z.
TARGET_SIZES = {
    "SN_HT_Boiler_House": (12.0, 12.0, 10.0),
    "SN_HT_Workshop_Row": (18.0, 8.5, 7.0),
    "SN_HT_Brick_Tenement": (10.0, 12.0, 8.0),
}
EXPECTED_TRIS = {
    "SN_HT_Boiler_House": {"LOD0": 7388, "LOD1": 2536, "LOD1_cap": 2800},
    "SN_HT_Workshop_Row": {"LOD0": 7312, "LOD1": 2444, "LOD1_cap": 2800},
    "SN_HT_Brick_Tenement": {"LOD0": 9376, "LOD1": 2704, "LOD1_cap": 4900},
}


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _glb():
    return _load(os.path.join(HERE, "glb_shared_textures.py"), "glb_shared_textures")


def _export_config():
    return _load(os.path.join(HERE, "export_iron_harbor_prototypes_glb.py"),
                 "export_iron_harbor_prototypes_glb")


def _close(left, right, tolerance):
    return abs(float(left) - float(right)) <= tolerance


def verify_asset(glb, cells, asset):
    entry = {"asset": asset, "lods": {}, "checks": {}, "failures": []}
    failures = entry["failures"]
    structures = {}
    for lod in ("LOD0", "LOD1"):
        runtime_name = asset + ".glb" if lod == "LOD0" else "%s_%s.glb" % (asset, lod)
        path = os.path.join(PROPS_DIR, runtime_name)
        if not os.path.exists(path):
            failures.append("%s missing: %s" % (lod, os.path.relpath(path, REPO_ROOT)))
            continue
        report = glb.structure_report(path)
        structures[lod] = report
        images = report["images"]
        external = [image for image in images if image.get("uri")]
        for image in external:
            file_name = str(image["uri"]).split("/")[-1]
            tile = os.path.join(TILES_DIR, file_name)
            image["tiles_match"] = bool(image.get("sha256")) and glb.sha256_file(tile) == image["sha256"]
        bbox = report["bbox"]
        size = bbox["godot_size"] if bbox else [0, 0, 0]
        target = TARGET_SIZES[asset]
        checks = {
            "single_root_node": len(report["nodes"]) == 1,
            "root_node_name": bool(report["nodes"]) and report["nodes"][0]["name"] == "%s_%s" % (asset, lod),
            "tris_expected": report["tris"] == EXPECTED_TRIS[asset][lod],
            "tris_within_cap": lod != "LOD1" or report["tris"] <= EXPECTED_TRIS[asset]["LOD1_cap"],
            "tris_ratio_ok": lod != "LOD1" or report["tris"] <= EXPECTED_TRIS[asset]["LOD0"] * 0.35,
            "materials_le_6": 0 < len(report["materials"]) <= 6,
            "palette_only": all(material["name"] in PALETTE for material in report["materials"]),
            "images_external": bool(images) and all(image.get("uri") for image in images),
            "images_exist": all(image.get("exists") for image in images) if images else False,
            "images_match_tiles": all(image.get("tiles_match") for image in images) if images else False,
            "size_matches_target": all(_close(size[i], target[i], 0.10) for i in range(3)),
            "grounded": bool(bbox) and abs(bbox["godot_min"][1]) <= 0.002,
            "pivot_ground_centre": bool(bbox) and abs(
                bbox["godot_min"][0] + bbox["godot_max"][0]) <= 0.002 and abs(
                bbox["godot_min"][2] + bbox["godot_max"][2]) <= 0.002,
        }
        entry["lods"][lod] = {
            "path": report["path"],
            "bytes": report["bytes"],
            "sha256": report["sha256"],
            "tris": report["tris"],
            "nodes": [node["name"] for node in report["nodes"]],
            "materials": [material["name"] for material in report["materials"]],
            "cell_files": [str(image["uri"]).split("/")[-1] for image in external],
            "bbox_godot_size": size,
            "checks": checks,
        }
        for name, passed in checks.items():
            if not passed:
                failures.append("%s %s failed: %s" % (lod, name, checks))
        expected_cells = cells.get(asset) or {}
        if expected_cells:
            material_names = [material["name"] for material in report["materials"]]
            expected_files = sorted({expected_cells[name] for name in material_names if name in expected_cells})
            actual_files = sorted({str(image["uri"]).split("/")[-1][:-4] for image in external})
            if actual_files != expected_files:
                failures.append("%s cells %s != expected %s" % (lod, actual_files, expected_files))
    if "LOD0" in structures and "LOD1" in structures:
        bbox0 = structures["LOD0"]["bbox"]["godot_size"]
        bbox1 = structures["LOD1"]["bbox"]["godot_size"]
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
    glb_bytes = 0
    tris_lod0 = 0
    tris_lod1 = 0
    for spec in export_config.ASSETS:
        asset = spec["asset"]
        entry = verify_asset(glb, export_config.CELLS, asset)
        report["assets"][asset] = entry
        glb_bytes += sum(int(lod["bytes"]) for lod in entry["lods"].values())
        if "LOD0" in entry["lods"]:
            tris_lod0 += int(entry["lods"]["LOD0"]["tris"])
        if "LOD1" in entry["lods"]:
            tris_lod1 += int(entry["lods"]["LOD1"]["tris"])
        if not entry["passed"]:
            report["passed"] = False
            report["failures"].extend("%s: %s" % (asset, failure) for failure in entry["failures"])
    shared = {}
    if os.path.isdir(SHARED_DIR):
        for file_name in sorted(os.listdir(SHARED_DIR)):
            if not file_name.endswith(".png"):
                continue
            path = os.path.join(SHARED_DIR, file_name)
            tile = os.path.join(TILES_DIR, file_name)
            shared[file_name] = {
                "bytes": os.path.getsize(path),
                "matches_tile": glb.sha256_file(path) == glb.sha256_file(tile),
            }
            if not shared[file_name]["matches_tile"]:
                report["passed"] = False
                report["failures"].append("shared tile mismatch: " + file_name)
    report["totals"] = {
        "prototype_glb_bytes": glb_bytes,
        "shared_pngs_total": len(shared),
        "shared_png_bytes_total": sum(entry["bytes"] for entry in shared.values()),
        "new_lod0_tris": tris_lod0,
        "new_lod1_tris": tris_lod1,
        "lod1_combo_within_20000": tris_lod1 <= 20000,
    }
    if tris_lod1 > 20000:
        report["passed"] = False
        report["failures"].append("LOD1 combo tris %d > 20000" % tris_lod1)
    if report_path:
        os.makedirs(os.path.dirname(os.path.abspath(report_path)), exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2, ensure_ascii=False)
    print("[verify-iron-harbor-prototypes] JSON " + json.dumps(report, ensure_ascii=False))
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
