# -*- coding: utf-8 -*-
# @static-doc
# 作用：旧资产 UV 迁移 B 的纯 Python 预检（不进 Blender）——校对船模块 / 船 / 旧小镇
# 目标清单、旧材质 -> `SN_Tex_*` 映射是否全部落在共享材质 spec 内、运行时贴图目录是否
# 齐备，并用 `.design/legacy_uv_b/baseline.json`（迁移前 GLB 快照）核对基线事实。
#
# 用法：
#   python tools/modeling/generators/dryrun_legacy_uv_b.py
#
# 通过标准：输出 ALL OK 并返回 0；否则列出失败项并返回 1。
# 基线 JSON 是本地产物（.design/ 被 gitignore），缺失时只做静态契约检查。
# @end-static-doc

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sn_legacy_uv_migration as mig
import sn_shared_materials as smat

REPO_ROOT = mig.REPO_ROOT
DEFAULT_BASELINE = os.path.join(REPO_ROOT, ".design", "legacy_uv_b", "baseline.json")

# 迁移前 GLB 实测（capture_baseline_b.py）：12 模块 / 4 船 / 5 旧小镇。
EXPECTED_BASELINE = {
    "modules": {"count": 12, "tris": 7492},
    "ships": {"count": 4, "tris": 45968},
    "town": {"count": 5, "tris": 1796},
}
EXPECTED_BASSETS = {"modules": 12, "ships": 4, "town": 5}
# 已在建筑套件批次完成迁移、不应出现在本批目标里的旧小镇建筑
ALREADY_MIGRATED_TOWN = [
    "SN_HT_Warehouse_Long", "SN_HT_Warehouse_Short", "SN_HT_Harbor_Office",
    "SN_HT_Cargo_Shed", "SN_HT_Tavern", "SN_HT_Boiler_House",
    "SN_HT_Workshop_Row", "SN_HT_Brick_Tenement",
]


def _check(condition, failures, message):
    if not condition:
        failures.append(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", default=DEFAULT_BASELINE)
    args = parser.parse_args()

    failures = []
    specs = smat.material_specs()
    names = mig.b_asset_names()

    # 1) 目标清单 / 映射 / 贴图真源
    _check(len(names) == 21, failures, "批次 B 目标数 %d != 21" % len(names))
    _check(len(names) == len(set(names)), failures, "批次 B 目标名重复")
    for category, expected in EXPECTED_BASSETS.items():
        _check(len(mig.BATCH_B_ASSETS[category]) == expected, failures,
               "%s 目标数 != %d" % (category, expected))
    _check(not (set(mig.BATCH_B_ASSETS["town"]) & set(ALREADY_MIGRATED_TOWN)),
           failures, "已迁移的旧小镇建筑不应出现在本批目标里")
    _check(all(v in specs for v in mig.LEGACY_TO_SHARED.values()), failures,
           "存在未落在共享材质 spec 内的映射目标")
    tile_report = smat.texture_report()
    for target in sorted(set(mig.LEGACY_TO_SHARED.values())):
        info = tile_report[target]
        _check(info["exists"] and info["bytes"] > 0, failures,
               "贴图缺失：%s" % target)

    # 2) 运行时共享贴图目录（贴图生成器 runtime_dirs 的产物）
    for category in ("modules", "ships"):
        for root in ("assets/models", "dev_mods/core/assets/models"):
            folder = os.path.join(REPO_ROOT, root, category, "shared_materials")
            pngs = [n for n in os.listdir(folder)] if os.path.isdir(folder) else []
            _check(len(pngs) >= 11, failures,
                   "%s 的共享贴图目录缺失或不足 11 张：%s" % (category, folder))

    # 3) 基线事实
    baseline_info = None
    if os.path.isfile(args.baseline):
        baseline = json.load(open(args.baseline, encoding="utf-8"))
        items = baseline["targets"]
        _check(set(items) == set(EXPECTED_BASSETS), failures,
               "基线类别应为 modules/ships/town")
        for category, expected in EXPECTED_BASELINE.items():
            actual = items[category]
            _check(len(actual) == expected["count"], failures,
                   "%s 基线件数 %d != %d" % (category, len(actual),
                                             expected["count"]))
            _check(sum(v["tris"] for v in actual.values()) == expected["tris"],
                   failures, "%s 基线三角面 != %d" % (category, expected["tris"]))
            _check(set(actual) == set(mig.BATCH_B_ASSETS[category]), failures,
                   "%s 基线对象名与迁移清单不一致" % category)
            for name, item in actual.items():
                _check(item["embedded_images"] == 0, failures,
                       "%s 迁移前不应有内嵌贴图" % name)
                unknown = [m for m in item["materials"]
                           if m not in mig.LEGACY_TO_SHARED]
                _check(not unknown, failures,
                       "%s 存在未映射旧材质：%s" % (name, unknown))
        for asset, _collection, root_name in mig.BATCH_B_SHIPS:
            roots = items["ships"][asset]["root_nodes"]
            _check(root_name in roots, failures,
                   "%s 根节点 %s 不在基线 root_nodes %s" % (asset, root_name, roots))
        baseline_info = {
            "file": os.path.relpath(args.baseline, REPO_ROOT).replace("\\", "/"),
            "count": baseline["summary"]["total_count"],
            "tris": baseline["summary"]["total_tris"],
            "bytes": baseline["summary"]["total_bytes"],
            "prims_without_uv": sum(v["prims_without_uv"]
                                    for c in items.values() for v in c.values()),
        }
    else:
        _check(False, failures, "缺少基线文件 %s（先跑 capture_baseline_b.py）"
               % args.baseline)

    legacy_used = set()
    if baseline_info:
        legacy_used = {m for c in json.load(open(args.baseline, encoding="utf-8"))[
            "targets"].values() for v in c.values() for m in v["materials"]}

    print("=== 旧资产 UV 迁移 B 预检 ===")
    print("目标：%d 件（modules %d / ships %d / town %d）" % (
        len(names), len(mig.BATCH_B_ASSETS["modules"]),
        len(mig.BATCH_B_ASSETS["ships"]), len(mig.BATCH_B_ASSETS["town"])))
    print("旧材质（%d）：%s" % (len(legacy_used), sorted(legacy_used)))
    print("映射目标（%d）：%s" % (len(set(mig.LEGACY_TO_SHARED.values())),
                                 sorted(set(mig.LEGACY_TO_SHARED.values()))))
    if baseline_info:
        print("基线：%s（%d 件 / %d tri / %d bytes / 无 UV 图元 %d）" % (
            baseline_info["file"], baseline_info["count"], baseline_info["tris"],
            baseline_info["bytes"], baseline_info["prims_without_uv"]))
    if failures:
        print("FAILURES:")
        for failure in failures:
            print("  - " + failure)
        print("dryrun = FAIL (%d)" % len(failures))
        return 1
    print("ALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
