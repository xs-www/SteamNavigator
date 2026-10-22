# -*- coding: utf-8 -*-
# @static-doc
# 作用：LOD1 基础套件（M0-5）的独立结构验收：逐件解析 30 个 `SN_*_LOD1.glb`
# （kit 26 + 船 4），核对单根节点 / 单 mesh / tri 比例与硬上限 / 与 LOD0 的世界包围盒
# 逐轴一致 / `SN_Tex_*` 共享材质 / 外部 `shared_materials/<texture>.png` 与授权 tile
# 逐字节一致 / 每个 primitive 的 UV 完整 / LOD1 节点 extras；并汇总 kit 与船两组预算
# 与 Core manifest 的船体 LOD1 资源键。纯 Python，不依赖 Blender / Godot。
#
# ## 契约与约束
# - 默认验收**已安装**路径（`assets/models/<category>/` 与 `dev_mods/core/...`）；`--candidate`
#   改验 `.design/lod1_kit_ships/out/<category>/`，供安装前门禁。
# - LOD0 世界包围盒用 `glb_world_bounds.world_bounds`（按节点层级合成 TRS、读真实顶点），
#   不用 accessor min/max 近似；LOD1 单节点同一路径，因此 bbox 对账是精确值。
# - 上限口径与生成器一致：kit ≤ LOD0×0.35、船 ≤ LOD0×0.30；同时必须有实质简化
#   （LOD1 ≤ LOD0×0.5）与足够几何（LOD1 ≥ 24 tri），防止空模型通过。
# - 外部 PNG 必须与 `docs/design/textures/shared_materials/tiles/<texture>.png`
#   字节一致；不比对 Blender 重编码字节。缺文件 / 内嵌图 / URI 不在 `shared_materials/`
#   一律失败，不静默回退。
# - manifest 只校验 `model.ship.*_lod1` 四个键（kit 尚未登记 manifest，归
#   `kit_catalog.json` 的 LOD1 段）；缺键或路径不存在记失败。
#
# ## 重点逻辑
# ### `verify_asset(asset)`
# - 读 LOD0/LOD1 两个 GLB：tri、bbox、材质、image URI、UV、root extras 全部一次拿齐；
#   逐项 checks 记录后在 `main()` 汇总；任何 failures 让退出码为 2。
# ### `main(argv)`
# - `--candidate` 切候选目录；`--report <path>` 落盘 JSON；打印逐件表与总 tri / 总字节。
# @end-static-doc

import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_DIR = os.path.join(REPO_ROOT, ".design", "lod1_kit_ships")
TILES_DIR = os.path.join(REPO_ROOT, "docs", "design", "textures", "shared_materials", "tiles")
MANIFEST_PATH = os.path.join(REPO_ROOT, "dev_mods", "core", "manifest.json")
TEXTURE_PREFIX = "SN_Tex_"
URI_PREFIX = "shared_materials/"
SHIP_MANIFEST_KEYS = {
    "model.ship.ironclad_lod1": "assets/models/ships/SN_Ironclad_LOD1.glb",
    "model.ship.paddle_freighter_lod1": "assets/models/ships/SN_Paddle_Freighter_LOD1.glb",
    "model.ship.paddle_steamer_lod1": "assets/models/ships/SN_Paddle_Steamer_LOD1.glb",
    "model.ship.schooner_fame_lod1": "assets/models/ships/SN_Schooner_Fame_LOD1.glb",
}


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _modules():
    generator = _load(os.path.join(HERE, "sn_lod1_kit_ships_generator.py"),
                      "sn_lod1_kit_ships_generator")
    bounds = _load(os.path.join(HERE, "glb_world_bounds.py"), "glb_world_bounds")
    textures = _load(os.path.join(HERE, "glb_shared_textures.py"), "glb_shared_textures")
    return generator, bounds, textures


def _candidate_lod1_path(generator, asset):
    entry = generator.PLAN_BY_ASSET[asset]
    return os.path.join(generator.OUT_DIR, entry["category"], asset + "_LOD1.glb")


def _tile_hashes(textures):
    hashes = {}
    for file_name in sorted(os.listdir(TILES_DIR)):
        if file_name.endswith(".png"):
            hashes[file_name] = textures.sha256_file(os.path.join(TILES_DIR, file_name))
    return hashes


def _root_extras(generator, textures, asset, path):
    document, _bin = textures.read_glb(path)
    nodes = document.get("nodes", [])
    if len(nodes) != 1:
        return None
    return nodes[0].get("extras") or {}


def verify_asset(generator, bounds, textures, tile_hashes, asset, candidate=False):
    entry = generator.PLAN_BY_ASSET[asset]
    lod0_path = generator.lod0_path(asset)
    lod1_path = (_candidate_lod1_path(generator, asset) if candidate
                 else generator.lod1_dev_path(asset))
    failures = []
    checks = {}
    row = {"asset": asset, "kind": entry["kind"], "category": entry["category"],
           "lod0": {"path": os.path.relpath(lod0_path, REPO_ROOT)},
           "lod1": {"path": os.path.relpath(lod1_path, REPO_ROOT)}}
    if not os.path.exists(lod0_path):
        failures.append("missing LOD0")
        row["passed"] = False
        row["failures"] = failures
        return row
    if not os.path.exists(lod1_path):
        failures.append("missing LOD1")
        row["passed"] = False
        row["failures"] = failures
        return row

    lod0 = bounds.world_bounds(lod0_path)
    lod1 = bounds.world_bounds(lod1_path)
    report0 = textures.structure_report(lod0_path)
    report1 = textures.structure_report(lod1_path)
    row["lod0"].update({"tris": lod0["stats"]["tris"], "bbox_size": lod0["size"],
                        "bbox_min": lod0["min"], "bbox_max": lod0["max"]})
    row["lod1"].update({
        "tris": lod1["stats"]["tris"],
        "bbox_size": lod1["size"], "bbox_min": lod1["min"], "bbox_max": lod1["max"],
        "bytes": report1["bytes"], "sha256": report1["sha256"],
        "primitives": lod1["stats"]["primitives"],
        "nodes": [node["name"] for node in report1["nodes"]],
        "materials": [material["name"] for material in report1["materials"]],
        "images": [image.get("uri") for image in report1["images"]],
    })

    lod0_tris = int(lod0["stats"]["tris"])
    lod1_tris = int(lod1["stats"]["tris"])
    cap_ratio = generator.CAP_RATIO[entry["kind"]]
    row["lod1"]["ratio"] = round(lod1_tris / float(lod0_tris), 6) if lod0_tris else 99.0
    row["lod1"]["cap_ratio"] = cap_ratio
    row["lod1"]["cap_tris"] = int(lod0_tris * cap_ratio)
    checks["tris_nonzero"] = lod1_tris >= 24
    checks["tris_within_cap"] = lod1_tris <= row["lod1"]["cap_tris"]
    checks["tris_ratio_within_cap"] = row["lod1"]["ratio"] <= cap_ratio + 1e-9
    checks["tris_reduced"] = lod1_tris <= lod0_tris * 0.5

    checks["single_root_node"] = len(report1["nodes"]) == 1
    checks["root_node_name"] = bool(report1["nodes"]) and report1["nodes"][0]["name"] == (
        asset + "_LOD1")
    checks["single_mesh_node"] = int(lod1["stats"]["mesh_nodes"]) == 1
    checks["uv_complete"] = (lod1["stats"]["uv_missing"] == 0
                             and lod1["stats"]["uv_count_mismatch"] == 0)

    comparison = bounds.compare_bounds(lod0, lod1, tolerance=0.02)
    row["bbox_compare"] = comparison
    checks["bbox_matches_lod0"] = comparison["ok"]

    lod0_materials = {material["name"] for material in report0["materials"]}
    lod1_materials = {material["name"] for material in report1["materials"]}
    checks["materials_shared"] = bool(lod1_materials) and all(
        name.startswith(TEXTURE_PREFIX) for name in lod1_materials)
    checks["materials_subset_of_lod0"] = lod1_materials <= lod0_materials

    images = report1["images"]
    checks["images_external"] = bool(images) and all(
        image.get("uri") and str(image["uri"]).startswith(URI_PREFIX) for image in images)
    checks["images_exist"] = all(image.get("exists") for image in images) if images else False
    checks["images_match_authored_tiles"] = bool(images) and all(
        image.get("sha256") == tile_hashes.get(str(image.get("uri", "")).split("/")[-1])
        for image in images)

    extras = _root_extras(generator, textures, asset, lod1_path) or {}
    checks["root_extras_lod"] = str(extras.get("lod_level")) == "1"
    checks["root_extras_source"] = extras.get("lod_source") == asset

    row["failures"] = ["%s: %s" % (asset, name) for name, passed in checks.items()
                       if not passed]
    row["checks"] = checks
    row["passed"] = not row["failures"]
    return row


def verify_manifest(installed=True):
    failures = []
    rows = {}
    if not os.path.exists(MANIFEST_PATH):
        return {"failures": ["manifest missing"], "rows": rows}
    manifest = json.load(open(MANIFEST_PATH, encoding="utf-8"))
    assets = manifest.get("assets", {})
    for key, expected in SHIP_MANIFEST_KEYS.items():
        actual = assets.get(key)
        rows[key] = {"expected": expected, "actual": actual}
        if actual != expected:
            failures.append("%s: manifest %r != %r" % (key, actual, expected))
        elif installed and not os.path.exists(os.path.join(REPO_ROOT, "dev_mods", "core", expected)):
            failures.append("%s: core asset missing %s" % (key, expected))
    return {"failures": failures, "rows": rows}


def main(argv):
    generator, bounds, textures = _modules()
    candidate = "--candidate" in argv
    report_path = None
    index = 1
    while index < len(argv):
        if argv[index] == "--report":
            index += 1
            report_path = os.path.abspath(argv[index])
        index += 1

    tile_hashes = _tile_hashes(textures)
    rows = {}
    failures = []
    totals = {"lod0_tris": 0, "lod1_tris": 0, "lod1_bytes": 0, "lod1_images": 0}
    groups = {}
    for entry in generator.PLAN:
        asset = entry["asset"]
        row = verify_asset(generator, bounds, textures, tile_hashes, asset,
                           candidate=candidate)
        rows[asset] = row
        totals["lod0_tris"] += int(row.get("lod0", {}).get("tris", 0) or 0)
        totals["lod1_tris"] += int(row.get("lod1", {}).get("tris", 0) or 0)
        totals["lod1_bytes"] += int(row.get("lod1", {}).get("bytes", 0) or 0)
        totals["lod1_images"] += len(row.get("lod1", {}).get("images") or [])
        group = groups.setdefault(entry["kind"], {"assets": 0, "lod0_tris": 0,
                                                  "lod1_tris": 0, "failures": 0})
        group["assets"] += 1
        group["lod0_tris"] += int(row.get("lod0", {}).get("tris", 0) or 0)
        group["lod1_tris"] += int(row.get("lod1", {}).get("tris", 0) or 0)
        if not row["passed"]:
            group["failures"] += 1
        failures.extend(row["failures"])
    manifest = verify_manifest(installed=not candidate)
    failures.extend(manifest["failures"])

    payload = {"mode": "candidate" if candidate else "installed", "assets": rows,
               "groups": groups, "totals": totals, "manifest": manifest,
               "failures": failures, "passed": not failures}
    if report_path:
        os.makedirs(os.path.dirname(report_path), exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, ensure_ascii=False)

    print("%-26s %-5s %6s %6s %7s %7s %s" % (
        "asset", "kind", "L0tri", "L1tri", "ratio", "cap", "status"))
    print("-" * 72)
    for asset, row in rows.items():
        lod1 = row.get("lod1", {})
        print("%-26s %-5s %6s %6s %7s %7s %s" % (
            asset, row["kind"], row["lod0"].get("tris"), lod1.get("tris"),
            ("%.3f" % lod1["ratio"]) if "ratio" in lod1 else "-",
            lod1.get("cap_tris"), "PASS" if row["passed"] else "FAIL"))
    print("-" * 72)
    print("groups: " + json.dumps(groups, ensure_ascii=False))
    print("totals: " + json.dumps(totals, ensure_ascii=False))
    print("manifest keys: %d/%d ok" % (
        len(SHIP_MANIFEST_KEYS) - len([f for f in manifest["failures"] if f.startswith("model.")]),
        len(SHIP_MANIFEST_KEYS)))
    if failures:
        print("FAILURES:")
        for failure in failures:
            print("  " + failure)
        return 2
    print("LOD1 VERIFY OK (%s)" % ("candidate" if candidate else "installed"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
