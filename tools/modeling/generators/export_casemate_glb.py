# -*- coding: utf-8 -*-
# @static-doc
# 作用：casemate gun 模块化的 **GLB 归档导出**（Blender 内执行，验收通过后由 Lead 运行）：
# - 导出独立炮模块 `SN_Weapon_CasemateGun.glb`（标准节点名 + 外部共享贴图 + Core 副本）；
# - 重导空炮门版 `SN_Ironclad.glb`（保留 Root extras 与 4 武器 socket + 9 帆索 socket +
#   12 炮门 socket），依次做贴图外部化 → 武器 socket 归一化 → 帆索 socket 归一化 →
#   炮门 socket 归一化，并把名单写进 Root extras；
# - 覆盖前备份旧 GLB，Core 副本与共享贴图同步，最后保存工作台 .blend。
#
# 前置条件（任一不满足直接抛错，不静默降级）：
# - `sn_ship_gun_ports.verify_all()` / `sn_ship_weapon_sockets.verify_ship()` /
#   `sn_ship_rig_sockets.verify_ship()` 场景复核通过；
# - 场景里存在 `SN_Ironclad` 网格与 `SN_Weapon_CasemateGun_Prototype` 集合。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy

import glb_gun_ports
import glb_ship_rig_sockets
import glb_ship_sockets
import glb_shared_textures
import glb_weapon_nodes
import sn_ship_gun_ports as gunports
import sn_ship_rig_sockets as rigsocks
import sn_ship_weapon_sockets as socks
import export_ship_weapon_sockets_glb as ship_export
import export_weapon_glb as weapon_export

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures", "shared_materials", "tiles")
WEAPON_OUT = os.path.join(WORKDIR, "assets", "models", "weapons")
WEAPON_CORE = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "weapons")
REPORT_PATH = os.path.join(WORKDIR, ".design", "casemate", "export_report.json")
URI_PREFIX = "shared_materials"

GUN_ASSET = "SN_Weapon_CasemateGun"
GUN_COLLECTION = GUN_ASSET + "_Prototype"
GUN_ROOT = GUN_ASSET + "_Root"
IRONCLAD = "SN_Ironclad"


def _relative(path):
    return os.path.relpath(path, WORKDIR).replace("\\", "/")


def _copy_shared(shared_dir, core_dir, external):
    os.makedirs(core_dir, exist_ok=True)
    copied = []
    for entry in external.get("pngs", []):
        name = os.path.basename(entry["png"])
        shutil.copy2(os.path.join(shared_dir, name), os.path.join(core_dir, name))
        copied.append(name)
    return copied


def _export_gun():
    path, backup = weapon_export._export_glb(GUN_ASSET, GUN_COLLECTION, GUN_ROOT)
    shared_out = os.path.join(WEAPON_OUT, "shared_materials")
    shared_core = os.path.join(WEAPON_CORE, "shared_materials")
    external = glb_shared_textures.externalize_glb(
        path, path,
        shared_dir=shared_out,
        uri_prefix=URI_PREFIX,
        tiles_dir=TILES_DIR,
        write_pngs=True,
        prefer_authored=True,
    )
    renamed = glb_weapon_nodes.standardize(path, GUN_ASSET)
    core_glb = os.path.join(WEAPON_CORE, "%s.glb" % GUN_ASSET)
    os.makedirs(WEAPON_CORE, exist_ok=True)
    shutil.copy2(path, core_glb)
    tiles = _copy_shared(shared_out, shared_core, external)
    return {
        "asset": GUN_ASSET,
        "glb": _relative(path),
        "core_glb": _relative(core_glb),
        "bytes": os.path.getsize(path),
        "backup": _relative(backup) if backup else None,
        "renamed_nodes": renamed,
        "images": len(external.get("images", [])),
        "core_tiles": len(tiles),
    }


def _export_ironclad():
    ship = next(item for item in socks.SHIPS if item["asset"] == IRONCLAD)
    path, backup = ship_export._export_single_mesh(ship)
    shared_out = os.path.join(ship_export.OUT_DIR, "shared_materials")
    shared_core = os.path.join(ship_export.CORE_DIR, "shared_materials")
    external = glb_shared_textures.externalize_glb(
        path, path,
        shared_dir=shared_out,
        uri_prefix=URI_PREFIX,
        tiles_dir=TILES_DIR,
        write_pngs=True,
        prefer_authored=True,
    )
    weapon_report = glb_ship_sockets.standardize(path, IRONCLAD)
    rig_report = glb_ship_rig_sockets.standardize(path, IRONCLAD)
    port_report = glb_gun_ports.standardize(path, IRONCLAD)
    core_glb, core_tiles = ship_export._sync_core(
        path, IRONCLAD, shared_out, shared_core, external)
    return {
        "asset": IRONCLAD,
        "glb": _relative(path),
        "core_glb": _relative(core_glb),
        "bytes": os.path.getsize(path),
        "backup": _relative(backup) if backup else None,
        "images": len(external.get("images", [])),
        "core_tiles": core_tiles,
        "weapon_sockets": len(weapon_report["sockets"]),
        "rig_sockets": len(rig_report["sockets"]),
        "gun_ports": len(port_report["ports"]),
    }


def export_all():
    gun_ports_verify = gunports.verify_all()
    if not gun_ports_verify["passed"]:
        raise RuntimeError("炮门 socket 场景复核失败：%r"
                           % [item["failures"] for item in gun_ports_verify["ships"]])
    ic_ship = next(item for item in socks.SHIPS if item["asset"] == IRONCLAD)
    weapon_verify = socks.verify_ship(ic_ship)
    if not weapon_verify["passed"]:
        raise RuntimeError("甲板武器 socket 场景复核失败：%r" % weapon_verify["failures"])
    rig_ship = next(item for item in rigsocks.SHIPS if item["asset"] == IRONCLAD)
    rig_specs = rigsocks.build_specs()[IRONCLAD]
    rig_verify = rigsocks.verify_ship(rig_ship, rig_specs)
    if not rig_verify["passed"]:
        raise RuntimeError("帆索 socket 场景复核失败：%r" % rig_verify.get("failures"))

    results = [_export_gun(), _export_ironclad()]
    bpy.ops.wm.save_mainfile()
    report = {
        "workbench": bpy.data.filepath,
        "results": results,
        "total_bytes": sum(item["bytes"] for item in results),
        "gun_ports": gun_ports_verify["ships"][0]["ports"],
    }
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=1)
    print("CASEMATE_EXPORT_DONE " + json.dumps(
        {"files": [item["asset"] for item in results],
         "total_bytes": report["total_bytes"],
         "workbench": report["workbench"]}, ensure_ascii=False))
    return report


if __name__ == "__main__":
    export_all()
