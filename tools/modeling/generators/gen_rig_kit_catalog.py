# -*- coding: utf-8 -*-
# @static-doc
# 作用：从 `rig_kit_batch1_generator`（12 件套件）与 `sn_ship_rig_sockets`（3 艘船
# 22 个船侧 socket）的纯 Python 真源导出机器可读目录
# `tools/modeling/rig_kit_catalog.json`，供运行时装配（后续 `ShipVisualAssembler`）、
# Godot 测试与文档交叉核对使用；不手写尺寸 / socket 坐标，避免第二套数据。
#
# 用法：`python tools/modeling/generators/gen_rig_kit_catalog.py`
# 通过标准：写出 JSON 并打印资产 / socket / tri 统计；不修改其它文件。
# @end-static-doc

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import rig_kit_batch1_generator as gen  # noqa: E402
import sn_rig_materials as rigmat  # noqa: E402
import sn_ship_rig_sockets as ships  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT_PATH = os.path.join(WORKDIR, "tools", "modeling", "rig_kit_catalog.json")


def _tri(part):
    return sum(max(0, len(f) - 2) for f, _m in part.faces)


def _asset_entry(asset):
    spec = gen.SPECS[asset]
    parts = gen.build_geometry(asset)
    tris = sum(_tri(part) for part, _parent in parts.values())
    sockets = []
    entries = gen.socket_entries(asset)
    glb_names = gen.socket_roles(asset)
    for entry, glb_name in zip(entries, glb_names):
        sockets.append({
            "name": glb_name,
            "blend_name": entry["name"],
            "local": [round(v, 6) for v in entry["location"]],
            "parent": "Root",
        })
    return {
        "asset": asset,
        "family": "rig_kit",
        "role": spec["role"],
        "type": spec["type"],
        "collection": spec["collection"],
        "root": spec["prefix"] + "Root",
        "prefix": spec["prefix"],
        "glb": "assets/models/rig/%s.glb" % asset,
        "core_glb": "dev_mods/core/assets/models/rig/%s.glb" % asset,
        "shared_materials": "assets/models/rig/shared_materials",
        "datum": spec["datum"],
        "closed": spec["closed"],
        "footprint_kind": spec["footprint_kind"],
        "base_footprint": list(spec["base_footprint"]),
        "bbox": list(spec["bbox"]),
        "z_range": list(spec["z_range"]),
        "tri_count": tris,
        "tri_budget": spec["tri_budget"],
        "materials": rigmat.material_names(asset),
        "sockets": sockets,
        "extras": dict(spec.get("extra", {})),
    }


def build_catalog():
    assets = [_asset_entry(asset) for asset in gen.ASSETS]
    ship_specs = ships.build_specs()
    ship_entries = {}
    for ship in ships.SHIPS:
        asset = ship["asset"]
        items = []
        for index, sock in enumerate(ship_specs[asset]):
            entry = {
                "name": sock["glb_name"],
                "kind": sock["kind"],
                "mast_key": sock["mast_key"],
                "socket_index": index,
                "local": [round(v, 6) for v in sock["local"]],
            }
            for key, value in sock.items():
                if key in ("kind", "mast_key", "glb_name", "local"):
                    continue
                entry[key] = value
            items.append(entry)
        ship_entries[asset] = {
            "collection": ship["collection"],
            "root": ship["root"],
            "root_type": ship["root_type"],
            "mesh_baseline": list(ship["mesh_baseline"]),
            "rig_sockets": items,
        }
    return {
        "schema": "steam-navigator/rig-kit-catalog@1",
        "version": "1.0",
        "units": "metres",
        "axes": {"up": "+Z", "forward": "+X"},
        "contract": "docs/design/RIG_KIT_CONTRACT.md",
        "brief": "tools/modeling/briefs/sn_rig_kit_batch1.json",
        "source_generator": "tools/modeling/generators/rig_kit_batch1_generator.py",
        "source_library": "tools/modeling/generators/rig_kit.py",
        "socket_standard": {
            "mount": "SN_Mount",
            "mast": "SN_Socket_Mast_*",
            "yard": "SN_Socket_Yard_*",
            "sail": "SN_Socket_Sail_*",
            "spec": ships.SOCKET_SPEC,
        },
        "totals": {
            "assets": len(assets),
            "tri_count": sum(item["tri_count"] for item in assets),
            "tri_budget": sum(item["tri_budget"] for item in assets),
            "rig_sockets": sum(len(item["rig_sockets"]) for item in ship_entries.values()),
        },
        "assets": {item["asset"]: item for item in assets},
        "ships": ship_entries,
    }


def main():
    catalog = build_catalog()
    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print("wrote %s" % os.path.relpath(OUT_PATH, WORKDIR))
    for asset, item in catalog["assets"].items():
        print("  %-22s tris=%-5d sockets=%d" % (
            asset, item["tri_count"], len(item["sockets"])))
    print("totals=%r" % catalog["totals"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
