# -*- coding: utf-8 -*-
# @static-doc
# 作用：从 `combat_kit_generator.py` 的纯 Python 数据段生成机器可读的敌舰套件目录
# `tools/modeling/combat_kit_catalog.json`（schema `steam-navigator/combat-kit@1`）。
# 目录是「运行时 / 装配层 / 文档」读取敌舰规格的唯一入口，字段全部来自生成器真源，
# 不在本脚本里写死任何 tri / bbox / socket 数字：
#
# - 每艘：`asset` / `enemy_class` / `enemy_archetype` / `collection` / `root` /
#   `tri_budget` / `tris`（`report()` 纯几何实算）/ `objects` / `bbox`（实算尺寸）+
#   `bbox_target` / `bbox_tol`（工单目标）/ `materials`（`SN_Tex_*` 白名单结果）/
#   `glb` / `core_glb` / `shared_materials`（assets 与 core 两个运行时目录）；
# - `weapon_sockets`：按 `socket_index` 顺序的 `SN_Socket_Weapon_*` 规格（class / 位置 /
#   deck_z / 净空 / mount_scale / note），契约 `hull-sockets@1`；`deck_z` 优先取已导出 GLB
#   的节点 translation（实测甲板面），未导出时回退生成器解析值并标 `deck_z_source`；
# - `gun_ports`：铁甲舰 8 个 `SN_Socket_GunPort_*` 规格（含解析炮门平面中心 `center`、
#   port_class / 口径 / 门内纵深 / 舷外净空 / 俯仰极限），契约 `hull-gunports@1`；其余 3 艘为空；
# - 顶层：schema / version / 单位与轴向 / 生成器与工单路径 / 类别目录 / shared_materials
#   目录 / `total_tri` / `total_objects` / `enemy_classes` / socket 契约版本。
#
# 用法：
#     python tools/modeling/gen_combat_kit_catalog.py
#
# 写盘口径：`json.dump(..., ensure_ascii=False, indent=1)` + 末尾换行；重复运行幂等。
# @end-static-doc

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GENERATORS = os.path.join(HERE, "generators")
if GENERATORS not in sys.path:
    sys.path.insert(0, GENERATORS)

import combat_kit_generator as ck  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(HERE))
CATEGORY = "combat"
OUT = os.path.join(HERE, "combat_kit_catalog.json")
GLB_DIR = "assets/models/%s" % CATEGORY
CORE_GLB_DIR = "dev_mods/core/assets/models/%s" % CATEGORY
SCHEMA = "steam-navigator/combat-kit@1"
VERSION = "1.0"


def _round3(value):
    return round(float(value), 3)


_JSON_CHUNK = 0x4E4F534A


def _glb_socket_deck_z(asset):
    """从已导出的 GLB 读取每个 socket 节点的实测安装面高度（glTF y）。

    目录里的 `deck_z` 要与运行时 GLB 节点一致（契约 §8.2：原点是 down-ray 实测甲板面）；
    生成器的解析值单列为 `deck_z_analytic`，供排查。GLB 尚未导出时返回空 map。
    """
    import struct
    path = os.path.join(WORKDIR, GLB_DIR, "%s.glb" % asset)
    if not os.path.isfile(path):
        return {}
    data = open(path, "rb").read()
    _magic, _version, length = struct.unpack("<III", data[:12])
    offset = 12
    while offset < length:
        chunk_length, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        payload = data[offset + 8: offset + 8 + chunk_length]
        offset += 8 + chunk_length
        if chunk_type != _JSON_CHUNK:
            continue
        gltf = json.loads(payload.decode("utf-8"))
        out = {}
        for node in gltf.get("nodes", []):
            name = node.get("name", "")
            if not name.startswith("SN_Socket_Weapon_"):
                continue
            translation = node.get("translation") or [0.0, 0.0, 0.0]
            out[name] = round(float(translation[1]), 4)
        return out
    return {}


def _weapon_socket_entry(index, asset, spec, measured):
    name = ck.glb_weapon_socket_name(spec["suffix"])
    analytic = _round3(spec["deck_z"])
    deck_z = measured.get(name, analytic)
    return {
        "socket_index": index,
        "name": name,
        "suffix": spec["suffix"],
        "socket_class": spec["socket_class"],
        "x": _round3(spec["x"]),
        "y": _round3(spec["y"]),
        "rot_z_deg": _round3(spec["rot_z"]),
        "deck_z": deck_z,
        "deck_z_analytic": analytic,
        "deck_z_source": "glb-node" if name in measured else "generator-analytic",
        "deck_z_tolerance": 0.03,
        "clearance_r": _round3(spec["clearance_r"]),
        "clearance_x": _round3(spec["clearance_x"]),
        "clearance_y": _round3(spec["clearance_y"]),
        "clearance_h": _round3(spec["clearance_h"]),
        "mount_scale": 1.0,
        "note": spec["note"],
    }


def _gun_port_entry(index, asset, spec):
    pose = ck.raider_gun_port_pose(spec["x"], spec["side"])
    return {
        "socket_index": index,
        "name": ck.glb_gun_port_socket_name(spec["suffix"]),
        "suffix": spec["suffix"],
        "side_index": int(spec["side_index"]),
        "side": int(spec["side"]),
        "x": _round3(spec["x"]),
        "center": [_round3(value) for value in pose["center"]],
        "rot_z_deg": _round3(pose["rot_z_deg"]),
        "rot_y_deg": _round3(pose["rot_y_deg"]),
        "port_class": spec["port_class"],
        "port_w": _round3(spec["port_w"]),
        "port_h": _round3(spec["port_h"]),
        "sill_z": _round3(spec["sill_z"]),
        "deck_z": _round3(spec["deck_z"]),
        "deck_z_source": "gunport-spec",
        "deck_z_tolerance": 0.03,
        "inboard_depth": _round3(spec["inboard_depth"]),
        "outboard_clearance": _round3(spec["outboard_clearance"]),
        "lid": spec["lid"],
        "lid_hinge_z": _round3(spec["lid_hinge_z"]),
        "elev_min_deg": _round3(spec["elev_min_deg"]),
        "elev_max_deg": _round3(spec["elev_max_deg"]),
        "traverse_deg": _round3(spec["traverse_deg"]),
        "mount_scale": _round3(spec["mount_scale"]),
        "note": spec["note"],
    }


def _asset_entry(asset):
    cfg = ck.SHIP_CONFIGS[asset]
    info = ck.report(asset, verbose=False)
    measured = _glb_socket_deck_z(asset)
    weapon_sockets = [
        _weapon_socket_entry(index, asset, spec, measured)
        for index, spec in ck.weapon_socket_entries(asset)
    ]
    gun_ports = [
        _gun_port_entry(index, asset, spec)
        for index, spec in ck.gun_port_entries(asset)
    ]
    return {
        "asset": asset,
        "enemy_class": cfg["enemy_class"],
        "enemy_archetype": cfg["enemy_archetype"],
        "collection": cfg["collection"],
        "root": cfg["root"],
        "tri_budget": int(cfg["tri_budget"]),
        "tris": int(info["tris"]),
        "objects": int(info["objects"]),
        "bbox": {
            "x": _round3(info["size"][0]),
            "y": _round3(info["size"][1]),
            "z": _round3(info["size"][2]),
        },
        "z_min": _round3(info["z_min"]),
        "z_max": _round3(info["z_max"]),
        "bbox_target": [_round3(value) for value in cfg["bbox"]],
        "bbox_tol": [_round3(value) for value in cfg["bbox_tol"]],
        "materials": list(info["materials"]),
        "weapon_socket_count": len(weapon_sockets),
        "weapon_sockets": weapon_sockets,
        "gun_port_count": len(gun_ports),
        "gun_ports": gun_ports,
        "glb": "%s/%s.glb" % (GLB_DIR, asset),
        "core_glb": "%s/%s.glb" % (CORE_GLB_DIR, asset),
        "shared_materials": "%s/shared_materials" % GLB_DIR,
        "core_shared_materials": "%s/shared_materials" % CORE_GLB_DIR,
    }


def build_catalog():
    assets = {
        asset: _asset_entry(asset)
        for asset in ck.SHIP_CLASS_ORDER
    }
    total_tri = sum(entry["tris"] for entry in assets.values())
    total_objects = sum(entry["objects"] for entry in assets.values())
    total_sockets = sum(entry["weapon_socket_count"]
                        for entry in assets.values())
    total_gun_ports = sum(entry["gun_port_count"] for entry in assets.values())
    return {
        "schema": SCHEMA,
        "version": VERSION,
        "units": "metres",
        "axes": {"up": "+Z", "forward": "+X"},
        "pivot": "waterline, centre of hull（+X 船首、+Z 向上，吃水为负 z）",
        "source_generator": "tools/modeling/generators/combat_kit_generator.py",
        "verifier": "tools/modeling/generators/verify_combat_kit_glb.py",
        "catalog_generator": "tools/modeling/gen_combat_kit_catalog.py",
        "brief": "tools/modeling/briefs/sn_combat_kit_batch1.json",
        "verifier_command": "python tools/modeling/generators/verify_combat_kit_glb.py",
        "contracts": {
            "combat_kit": ck.COMBAT_KIT_SPEC,
            "weapon_socket": ck.SOCKET_SPEC,
            "gun_port": ck.GUN_PORT_SPEC,
            "weapon_socket_contract": "docs/design/WEAPON_SOCKET_CONTRACT.md §8",
            "gun_port_contract": "docs/design/WEAPON_SOCKET_CONTRACT.md §9",
        },
        "category": CATEGORY,
        "glb_dir": GLB_DIR,
        "core_glb_dir": CORE_GLB_DIR,
        "shared_materials": "%s/shared_materials" % GLB_DIR,
        "core_shared_materials": "%s/shared_materials" % CORE_GLB_DIR,
        "allowed_materials": sorted(ck.ALLOWED_MATERIALS),
        "enemy_classes": sorted({entry["enemy_class"]
                                 for entry in assets.values()}),
        "total_tri": total_tri,
        "total_objects": total_objects,
        "total_weapon_sockets": total_sockets,
        "total_gun_port_sockets": total_gun_ports,
        "assets": assets,
    }


def main():
    catalog = build_catalog()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    print("COMBAT_KIT_CATALOG_WRITTEN %s assets=%d tri=%d objects=%d "
          "sockets=%d gun_ports=%d"
          % (os.path.relpath(OUT, WORKDIR).replace("\\", "/"),
             len(catalog["assets"]), catalog["total_tri"],
             catalog["total_objects"], catalog["total_weapon_sockets"],
             catalog["total_gun_port_sockets"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
