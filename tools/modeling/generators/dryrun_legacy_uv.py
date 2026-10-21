# -*- coding: utf-8 -*-
# @static-doc
# 作用：旧资产 UV 迁移 A 的纯 Python 预检（不进 Blender）——校对 37 件目标清单、
# 旧材质 -> `SN_Tex_*` 映射是否全部落在共享材质 spec 内、贴图真源是否存在，
# 并用 `.design/legacy_uv/baseline.json`（迁移前 GLB 快照）核对基线数与待迁移事实。
#
# 用法：
#   python tools/modeling/generators/dryrun_legacy_uv.py
#   python tools/modeling/generators/dryrun_legacy_uv.py --baseline <baseline.json>
#
# 通过标准：输出 ALL OK 并返回 0；否则列出失败项并返回 1。
# 注意：基线 JSON 是本地产物（.design/ 被 gitignore），缺失时只做静态契约检查。
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
DEFAULT_BASELINE = os.path.join(REPO_ROOT, ".design", "legacy_uv", "baseline.json")

# 迁移前 GLB 实测（capture_baseline.py）：31 件 6282 tri / 6 件 4996 tri。
EXPECTED_BASELINE = {
    "props": {"count": 31, "tris": 6282},
    "port": {"count": 6, "tris": 4996},
}


def _check(condition, failures, message):
    if not condition:
        failures.append(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", default=DEFAULT_BASELINE)
    args = parser.parse_args()

    failures = []
    static = mig.check_static_contract()
    for key in static["failures"]:
        failures.append("静态契约失败：%s" % key)
    _check(all(static["tiles"].values()), failures,
           "共享贴图缺失：%s" % [k for k, v in static["tiles"].items() if not v])

    tile_report = smat.texture_report()
    for name in static["mapped_materials"]:
        info = tile_report[name]
        _check(info["exists"] and info["bytes"] > 0 and info["tile_m"] > 0,
               failures, "贴图 spec 异常：%s" % name)

    baseline_info = None
    mapped_count = len(static["mapped_materials"])
    if os.path.isfile(args.baseline):
        with open(args.baseline, "r", encoding="utf-8") as handle:
            baseline = json.load(handle)
        items = baseline["targets"]
        _check(set(items) == {"props", "port"}, failures,
               "基线类别应为 props/port")
        baseline_materials = {m for category in items.values()
                              for item in category.values()
                              for m in item["materials"]}
        mapped_used = {mig.LEGACY_TO_SHARED[m] for m in baseline_materials}
        mapped_count = len(mapped_used)
        _check(len(mapped_used) == 9, failures,
               "旧资产实际映射后的共享材质应为 9 个，实际 %d：%s" % (
                   len(mapped_used), sorted(mapped_used)))
        for category, expected in EXPECTED_BASELINE.items():
            actual = items.get(category, {})
            _check(len(actual) == expected["count"], failures,
                   "%s 基线件数 %d != %d" % (category, len(actual),
                                             expected["count"]))
            _check(sum(v["tris"] for v in actual.values()) == expected["tris"],
                   failures, "%s 基线三角面 != %d" % (category, expected["tris"]))
            _check(set(actual) == set(mig.TARGETS[category]), failures,
                   "%s 基线对象名与迁移清单不一致" % category)
            for name, item in actual.items():
                _check(item["prims_without_uv"] == item["primitives"],
                       failures, "%s 迁移前应无 UV（%d/%d 有 UV）" % (
                           name, item["primitives"] - item["prims_without_uv"],
                           item["primitives"]))
                unknown = [m for m in item["materials"]
                           if m not in mig.LEGACY_TO_SHARED]
                _check(not unknown, failures,
                       "%s 存在未映射旧材质：%s" % (name, unknown))
                _check(item["embedded_images"] == 0, failures,
                       "%s 迁移前不应有内嵌贴图" % name)
        baseline_info = {
            "file": os.path.relpath(args.baseline, REPO_ROOT).replace("\\", "/"),
            "count": baseline["summary"]["total_count"],
            "tris": baseline["summary"]["total_tris"],
            "bytes": baseline["summary"]["total_bytes"],
        }

    print("=== 旧资产 UV 迁移 A 预检 ===")
    print("目标：%d 件（props %d / port %d），映射到 %d 个 SN_Tex_* 材质" % (
        len(mig.all_target_names()), len(mig.TARGETS["props"]),
        len(mig.TARGETS["port"]), mapped_count))
    print("映射：%s" % json.dumps(mig.LEGACY_TO_SHARED, ensure_ascii=False,
                                  sort_keys=True))
    print("UV 空间：%s" % mig.UV_SPACE)
    if baseline_info:
        print("基线：%s（%d 件 / %d tri / %d bytes）" % (
            baseline_info["file"], baseline_info["count"],
            baseline_info["tris"], baseline_info["bytes"]))
    else:
        print("基线：未找到 %s（仅做静态契约检查）" % args.baseline)
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
