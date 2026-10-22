# -*- coding: utf-8 -*-
# @static-doc
# 作用：LOD1 基础套件（M0-5）的安装器：把 `.design/lod1_kit_ships/out/<category>/`
# 里已通过候选验收的 30 个 `SN_*_LOD1.glb` 复制进 `assets/models/<category>/` 与
# `dev_mods/core/assets/models/<category>/` 两处运行时目录（覆盖前备份旧件），补齐每类
# `shared_materials/` 的 11 张授权 tile，并生成机器计划
# `tools/modeling/lod1_kit_ships_plan.json`（供 `gen_kit_catalog.py` 合并进 kit 目录）。
#
# ## 契约与约束
# - 纯 Python、幂等：重复执行只重写相同字节；旧 LOD1 先备份到
#   `.design/lod1_kit_ships/backup_glb/<category>/<file>.<timestamp>.glb`，不覆盖已有备份。
# - 只安装候选 GLB 与共享贴图；不改 manifest / catalog / 文档（由收尾步骤分别处理）。
# - 共享贴图只从 `docs/design/textures/shared_materials/tiles/` 复制；写入前逐字节比较，
#   相同则跳过，避免无意义改动时间戳。
# - 安装前必须存在全部 30 个候选 GLB；缺件直接失败，不部分安装。
#
# ## 重点逻辑
# ### `install()`
# - 逐件读候选 GLB 的 `glb_world_bounds.world_bounds` / `glb_shared_textures.structure_report`
#   得到 tri、bbox、材质与字节数，写入计划；随后复制 GLB 与 tile 到 dev / core 两处。
# ### `main()`
# - `--candidate-dir` 可覆盖候选目录；`--report` 落盘安装报告；打印逐件安装结果。
# @end-static-doc

import importlib.util
import json
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_DIR = os.path.join(REPO_ROOT, ".design", "lod1_kit_ships")
BACKUP_DIR = os.path.join(OUT_DIR, "backup_glb")
PLAN_PATH = os.path.join(REPO_ROOT, "tools", "modeling", "lod1_kit_ships_plan.json")
TILES_DIR = os.path.join(REPO_ROOT, "docs", "design", "textures", "shared_materials", "tiles")


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


def _sha256(path):
    import hashlib

    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _backup(path):
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    base = os.path.splitext(os.path.basename(path))[0]
    target = os.path.join(BACKUP_DIR, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, target)
    return target


def _install_tiles(category):
    written = []
    for dst_dir in (os.path.join(REPO_ROOT, "assets", "models", category, "shared_materials"),
                    os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models",
                                 category, "shared_materials")):
        os.makedirs(dst_dir, exist_ok=True)
        for file_name in sorted(os.listdir(TILES_DIR)):
            if not file_name.endswith(".png"):
                continue
            source = os.path.join(TILES_DIR, file_name)
            target = os.path.join(dst_dir, file_name)
            if os.path.exists(target) and _sha256(target) == _sha256(source):
                continue
            shutil.copy2(source, target)
            written.append(os.path.relpath(target, REPO_ROOT))
    return written


def install(candidate_dir=None, report_path=None):
    generator, bounds, textures = _modules()
    candidate_dir = candidate_dir or generator.OUT_DIR
    missing = []
    for entry in generator.PLAN:
        asset = entry["asset"]
        path = os.path.join(candidate_dir, entry["category"], asset + "_LOD1.glb")
        if not os.path.exists(path):
            missing.append(os.path.relpath(path, REPO_ROOT))
    if missing:
        raise SystemExit("missing candidates:\n  " + "\n  ".join(missing))

    assets = []
    backups = []
    tiles = {}
    for entry in generator.PLAN:
        asset = entry["asset"]
        category = entry["category"]
        source = os.path.join(candidate_dir, category, asset + "_LOD1.glb")
        dev_target = generator.lod1_dev_path(asset)
        core_target = generator.lod1_core_path(asset)
        for target in (dev_target, core_target):
            os.makedirs(os.path.dirname(target), exist_ok=True)
            backup = _backup(target)
            if backup:
                backups.append(os.path.relpath(backup, REPO_ROOT))
            shutil.copy2(source, target)
        geometry = bounds.world_bounds(source)
        structure = textures.structure_report(source)
        lod0_geometry = bounds.world_bounds(generator.lod0_path(asset))
        lod0_tris = int(lod0_geometry["stats"]["tris"])
        lod1_tris = int(geometry["stats"]["tris"])
        plan = generator.budget_plan(lod0_tris, kind=entry["kind"])
        assets.append({
            "asset": asset, "kind": entry["kind"], "family": entry["family"],
            "category": category,
            "lod0_glb": "assets/models/%s/%s.glb" % (category, asset),
            "lod1_glb": "assets/models/%s/%s_LOD1.glb" % (category, asset),
            "lod1_core_glb": "dev_mods/core/assets/models/%s/%s_LOD1.glb" % (category, asset),
            "lod0_tri": lod0_tris, "lod1_tri": lod1_tris,
            "lod1_ratio": round(lod1_tris / float(lod0_tris), 6),
            "lod1_cap_ratio": plan["cap_ratio"], "lod1_cap_tri": plan["cap_tris"],
            "lod1_bytes": structure["bytes"], "lod1_sha256": structure["sha256"],
            "materials": [material["name"] for material in structure["materials"]],
            "primitives": int(geometry["stats"]["primitives"]),
            "bbox_size": geometry["size"], "bbox_min": geometry["min"],
            "shared_textures": "assets/models/%s/shared_materials" % category,
        })
        tiles.setdefault(category, _install_tiles(category))

    plan_payload = {
        "schema": "steam-navigator/lod1-kit-ships-plan@1",
        "generator": "tools/modeling/generators/sn_lod1_kit_ships_generator.py",
        "verifier": "tools/modeling/generators/verify_lod1_kit_ships_glb.py",
        "installer": "tools/modeling/generators/install_lod1_kit_ships.py",
        "candidate_dir": os.path.relpath(candidate_dir, REPO_ROOT),
        "shared_textures_uri_prefix": "shared_materials",
        "caps": generator.CAP_RATIO,
        "totals": {
            "assets": len(assets),
            "kit_assets": len([row for row in assets if row["kind"] == "kit"]),
            "ship_assets": len([row for row in assets if row["kind"] == "ship"]),
            "lod0_tri": sum(row["lod0_tri"] for row in assets),
            "lod1_tri": sum(row["lod1_tri"] for row in assets),
            "lod1_bytes": sum(row["lod1_bytes"] for row in assets),
        },
        "assets": assets,
    }
    os.makedirs(os.path.dirname(PLAN_PATH), exist_ok=True)
    with open(PLAN_PATH, "w", encoding="utf-8") as handle:
        json.dump(plan_payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    payload = {"plan": os.path.relpath(PLAN_PATH, REPO_ROOT), "backups": backups,
               "shared_textures_written": tiles, "totals": plan_payload["totals"],
               "assets": assets}
    if report_path:
        os.makedirs(os.path.dirname(os.path.abspath(report_path)), exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
    return payload


def main(argv):
    candidate_dir = None
    report_path = None
    index = 1
    while index < len(argv):
        if argv[index] == "--candidate-dir":
            index += 1
            candidate_dir = os.path.abspath(argv[index])
        elif argv[index] == "--report":
            index += 1
            report_path = os.path.abspath(argv[index])
        index += 1
    payload = install(candidate_dir=candidate_dir, report_path=report_path)
    for row in payload["assets"]:
        print("INSTALLED %-26s %4d tri %8d B -> %s" % (
            row["asset"], row["lod1_tri"], row["lod1_bytes"], row["lod1_glb"]))
    print("totals: " + json.dumps(payload["totals"], ensure_ascii=False))
    print("plan: %s" % payload["plan"])
    if payload["backups"]:
        print("backups: %d" % len(payload["backups"]))
    print("INSTALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
