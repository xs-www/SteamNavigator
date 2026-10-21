# -*- coding: utf-8 -*-
# @static-doc
# 作用：`rig_kit` 船体帆索重构的纯 Python 几何基线工具——加载 3 艘有桅帆索的船
# （SN_Paddle_Freighter / SN_Schooner_Fame / SN_Ironclad）的 `build_all_geometry()`，
# 逐对象记录顶点 / 面 / 三角面 / 材质计数 / 父级，并生成 SHA-256 digest。
#
# 为什么需要它：M0-4 要求 3 艘船改由 `rig_kit` 部件库参数化生成，但**几何必须与重构前
# 逐对象逐位一致**。Blender 装配（Pivot 位移 / 原点扣除 / 法线重算）不改顶点与面，
# 因此纯 Python 的 `build_all_geometry()` 输出就是可靠基线；重构前后各跑一次并对比
# `BASELINE` 即可在进 Blender 之前抓住任何 0.1 mm 漂移。
#
# 用法：
# - 记录（重构前，写入 `.design/rig_kit/baseline_<asset>.json`）：
#   `python tools/modeling/generators/rig_kit_baseline.py --capture`
# - 对比（重构后，与基线逐对象比较）：
#   `python tools/modeling/generators/rig_kit_baseline.py --compare`
# 退出码 0 表示 0 差异；非 0 会打印差异对象与字段。
# @end-static-doc

import hashlib
import importlib
import json
import os
import sys

GEN_DIR = os.path.dirname(os.path.abspath(__file__))
if GEN_DIR not in sys.path:
    sys.path.insert(0, GEN_DIR)

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(GEN_DIR)))
BASELINE_DIR = os.path.join(WORKDIR, ".design", "rig_kit")

# asset -> (module, collection, root)
SHIPS = {
    "SN_Paddle_Freighter": ("sn_paddle_freighter_generator",
                            "SN_Paddle_Freighter_Prototype", "SN_PF_Root"),
    "SN_Schooner_Fame": ("sn_schooner_fame_generator",
                         "SN_Schooner_Fame_Prototype", "SN_SF_Root"),
    "SN_Ironclad": ("sn_ironclad_generator",
                    "SN_Ironclad_Prototype", "SN_Ironclad"),
}


def load_ship(asset):
    module_name = SHIPS[asset][0]
    if module_name in sys.modules:
        return importlib.reload(sys.modules[module_name])
    return importlib.import_module(module_name)


def part_record(part, parent):
    verts = [(float(x), float(y), float(z)) for (x, y, z) in part.verts]
    faces = [([int(i) for i in face], material) for face, material in part.faces]
    payload = repr((verts, faces)).encode("utf-8")
    materials = {}
    for _face, material in part.faces:
        materials[material] = materials.get(material, 0) + 1
    return {
        "parent": parent,
        "verts": len(verts),
        "faces": len(faces),
        "tris": sum(max(0, len(face) - 2) for face, _m in part.faces),
        "materials": dict(sorted(materials.items())),
        "sha256": hashlib.sha256(payload).hexdigest(),
        "bbox": _bbox(verts),
    }


def _bbox(verts):
    if not verts:
        return None
    xs = [v[0] for v in verts]
    ys = [v[1] for v in verts]
    zs = [v[2] for v in verts]
    return [round(max(xs) - min(xs), 6), round(max(ys) - min(ys), 6),
            round(max(zs) - min(zs), 6)]


def capture_ship(asset):
    module = load_ship(asset)
    parts = module.build_all_geometry()
    objects = {}
    for name, value in parts.items():
        # PF / SF 返回 (Part, parent)；铁甲舰是单 mesh，返回 Part（隐含 ROOT）
        if hasattr(value, "verts"):
            part, parent = value, "ROOT"
        else:
            part, parent = value
        objects[name] = part_record(part, parent)
    return {
        "asset": asset,
        "module": SHIPS[asset][0],
        "objects": objects,
        "totals": {
            "objects": len(objects),
            "verts": sum(o["verts"] for o in objects.values()),
            "faces": sum(o["faces"] for o in objects.values()),
            "tris": sum(o["tris"] for o in objects.values()),
        },
    }


def capture_all():
    return {asset: capture_ship(asset) for asset in SHIPS}


def _baseline_path(asset):
    return os.path.join(BASELINE_DIR, "baseline_%s.json" % asset)


def write_baselines():
    os.makedirs(BASELINE_DIR, exist_ok=True)
    report = capture_all()
    for asset, record in report.items():
        path = _baseline_path(asset)
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(record, handle, ensure_ascii=False, indent=1)
        print("BASELINE %-22s objects=%-3d tris=%-6d -> %s"
              % (asset, record["totals"]["objects"], record["totals"]["tris"], path))
    return report


def compare_ship(asset, baseline):
    current = capture_ship(asset)
    problems = []
    base_objects = baseline["objects"]
    cur_objects = current["objects"]
    for name in sorted(set(base_objects) | set(cur_objects)):
        base = base_objects.get(name)
        cur = cur_objects.get(name)
        if base is None:
            problems.append("%s: 新增对象" % name)
            continue
        if cur is None:
            problems.append("%s: 对象缺失" % name)
            continue
        for field in ("parent", "verts", "faces", "tris", "materials", "bbox"):
            if base[field] != cur[field]:
                problems.append("%s.%s: %r -> %r" % (name, field, base[field], cur[field]))
        if base["sha256"] != cur["sha256"]:
            problems.append("%s: 几何 digest 变化 %s -> %s"
                            % (name, base["sha256"][:12], cur["sha256"][:12]))
    if baseline["totals"] != current["totals"]:
        problems.append("totals: %r -> %r" % (baseline["totals"], current["totals"]))
    return current, problems


def compare_all():
    failures = 0
    for asset in SHIPS:
        path = _baseline_path(asset)
        if not os.path.isfile(path):
            print("MISSING baseline %s（先跑 --capture）" % path)
            failures += 1
            continue
        with open(path, encoding="utf-8") as handle:
            baseline = json.load(handle)
        current, problems = compare_ship(asset, baseline)
        if problems:
            failures += 1
            print("DIFF    %-22s %d 项" % (asset, len(problems)))
            for item in problems:
                print("   - " + item)
        else:
            print("SAME    %-22s objects=%-3d tris=%-6d 0 差异"
                  % (asset, current["totals"]["objects"], current["totals"]["tris"]))
    print("=== 结果：%d/%d 艘几何逐位一致 ===" % (len(SHIPS) - failures, len(SHIPS)))
    return 1 if failures else 0


def main(argv):
    if "--capture" in argv:
        write_baselines()
        return 0
    return compare_all()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
