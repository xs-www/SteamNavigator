# -*- coding: utf-8 -*-
# @static-doc
# 作用：`combat_kit` 敌舰套件（M2-1）的 GLB 落盘导出（Blender 内执行，人工 / 独立
# Verifier 验收通过后由 Lead 触发）—— 4 艘敌舰各自从集合导出为独立 GLB：
# - 导出前强制跑武器 socket / 炮门 socket 的场景只读复核，不通过拒绝导出；
# - 根空物体归零后整集合导出（`export_extras=True`），保留 Root extras；
# - 共享贴图外部化为 `shared_materials/<texture>.png`（授权 tile 字节）；
# - `glb_enemy_sockets.normalize()` 把 BLEND 内带资产前缀的 socket 节点归一化为
#   `SN_Socket_Weapon_*` / `SN_Socket_GunPort_*`，并写 Root 名单 extras；
# - 旧 GLB（若存在）备份到 `.design/combat/backup_glb/`，同步 `dev_mods/core` 副本，
#   最后保存工作台 `.design/SN_Asset_Workbench.blend`。
#
# 目标目录：`assets/models/combat/` + `dev_mods/core/assets/models/combat/`；
# 报告：`.design/combat/export_report.json`。
#
# 用法（已连 Blender、且 socket 已 apply 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import json
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402

import combat_kit_generator as ck  # noqa: E402
import glb_enemy_sockets  # noqa: E402
import glb_shared_textures  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
CATEGORY = "combat"
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures",
                         "shared_materials", "tiles")
OUT_DIR = os.path.join(WORKDIR, "assets", "models", CATEGORY)
CORE_DIR = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models",
                        CATEGORY)
BACKUP_ROOT = os.path.join(WORKDIR, ".design", "combat", "backup_glb")
REPORT_PATH = os.path.join(WORKDIR, ".design", "combat", "export_report.json")
URI_PREFIX = "shared_materials"
RTOL = 1e-6


def _relative(path):
    return os.path.relpath(path, WORKDIR).replace("\\", "/")


def _deselect_all():
    for obj in bpy.context.selected_objects:
        obj.select_set(False)


def _backup(path):
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUP_ROOT, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(BACKUP_ROOT, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, dst)
    return dst


def _strip_scene_extras(path):
    """剥掉 GLB scenes[].extras 里的 MCP 会话元数据（非资产契约字段）。

    Blender MCP 会在 scene 上写 `blendermcp_server_running` 之类自定义属性；
    `export_extras=True` 会把它导出到 glTF scene extras，属于交付物里的工具元数据泄漏。
    只重写 JSON chunk，BIN 原样保留。
    """
    version, chunks = glb_enemy_sockets._read_glb(path)
    removed = []
    out = []
    changed = False
    for chunk_type, payload in chunks:
        if chunk_type != glb_enemy_sockets._JSON:
            out.append((chunk_type, payload))
            continue
        gltf = json.loads(payload.decode("utf-8"))
        for scene in gltf.get("scenes", []):
            extras = scene.get("extras")
            if not extras:
                continue
            for key in list(extras):
                if key.startswith("blendermcp") or key.startswith("mcp_"):
                    removed.append(key)
                    extras.pop(key)
                    changed = True
            if not extras:
                scene.pop("extras", None)
        out.append((chunk_type, json.dumps(
            gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")))
    if changed:
        glb_enemy_sockets._write_glb(path, version, out)
    return sorted(set(removed))


def _verify_sockets():
    """导出前门禁：武器 socket + 炮门 socket 场景复核必须通过。"""
    import sn_enemy_weapon_sockets as weapon
    import sn_enemy_gun_ports as gunports

    failures = []
    weapon_verify = getattr(weapon, "verify_all", None) or getattr(
        weapon, "verify", None)
    if weapon_verify is None:
        raise RuntimeError("sn_enemy_weapon_sockets 缺少 verify_all()")
    report = weapon_verify()
    if not report.get("passed"):
        failures.append("weapon sockets: %r" % (report.get("failures"),))
    gun_check = getattr(gunports, "verify_all", None) or getattr(
        gunports, "verify", None)
    if gun_check is not None:
        report = gun_check()
        if not report.get("passed"):
            failures.append("gun ports: %r" % (report.get("failures"),))
    if failures:
        raise RuntimeError("socket 复核失败，拒绝导出：%s" % "; ".join(failures))
    return {"weapon": "passed", "gun_ports": "passed"}


def _export_asset(asset):
    cfg = ck.SHIP_CONFIGS[asset]
    collection = bpy.data.collections.get(cfg["collection"])
    root = bpy.data.objects.get(cfg["root"])
    if collection is None or root is None:
        raise RuntimeError("%s: 场景里找不到集合 / 根节点（集合 %s）"
                           % (asset, cfg["collection"]))
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "%s.glb" % asset)
    backup = _backup(path)
    saved_loc = tuple(root.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        root.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        _deselect_all()
        objects = list(collection.all_objects)
        for item in objects:
            item.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
            export_extras=True,
        )
    finally:
        root.location = saved_loc
        _deselect_all()
        for other in saved_selection:
            other.select_set(True)
        bpy.context.view_layer.update()
    return path, backup, len(objects)


def export_all():
    socket_report = _verify_sockets()
    os.makedirs(os.path.join(OUT_DIR, "shared_materials"), exist_ok=True)
    os.makedirs(os.path.join(CORE_DIR, "shared_materials"), exist_ok=True)
    os.makedirs(BACKUP_ROOT, exist_ok=True)
    results = []
    for asset in ck.SHIP_CLASS_ORDER:
        path, backup, objects = _export_asset(asset)
        shared_out = os.path.join(OUT_DIR, "shared_materials")
        external = glb_shared_textures.externalize_glb(
            path, path,
            shared_dir=shared_out,
            uri_prefix=URI_PREFIX,
            tiles_dir=TILES_DIR,
            write_pngs=True,
            prefer_authored=True,
        )
        socket_normalize = glb_enemy_sockets.normalize(path, asset)
        if not socket_normalize.get("passed"):
            raise RuntimeError("%s: GLB socket 归一化失败 %r"
                               % (asset, socket_normalize.get("failures")))
        stripped = _strip_scene_extras(path)
        core_glb = os.path.join(CORE_DIR, "%s.glb" % asset)
        shutil.copy2(path, core_glb)
        core_shared = os.path.join(CORE_DIR, "shared_materials")
        pngs = []
        for entry in external.get("pngs", []):
            name = os.path.basename(entry["png"])
            shutil.copy2(os.path.join(shared_out, name),
                         os.path.join(core_shared, name))
            pngs.append(name)
        results.append({
            "asset": asset,
            "glb": _relative(path),
            "core_glb": _relative(core_glb),
            "objects": objects,
            "bytes": os.path.getsize(path),
            "backup": _relative(backup) if backup else None,
            "images": len(external.get("images", [])),
            "pngs": sorted(set(pngs)),
            "weapon_sockets": socket_normalize.get("weapon_sockets", []),
            "gun_port_sockets": socket_normalize.get("gun_port_sockets", []),
            "stripped_scene_extras": stripped,
        })
        print("EXPORTED %-28s %8d bytes sockets=%d gunports=%d images=%d"
              % (asset, results[-1]["bytes"],
                 len(results[-1]["weapon_sockets"]),
                 len(results[-1]["gun_port_sockets"]),
                 results[-1]["images"]))
    bpy.ops.wm.save_mainfile()
    # 工作台里 4 艘船共用同一批共享贴图：assets/combat 与 core/combat 的
    # shared_materials 目录内容必须一致
    core_shared = os.path.join(CORE_DIR, "shared_materials")
    out_shared = os.path.join(OUT_DIR, "shared_materials")
    for name in sorted(os.listdir(out_shared)):
        src = os.path.join(out_shared, name)
        dst = os.path.join(core_shared, name)
        if os.path.isfile(src) and not os.path.isfile(dst):
            shutil.copy2(src, dst)
    report = {
        "workbench": bpy.data.filepath,
        "category": CATEGORY,
        "assets": len(results),
        "total_bytes": sum(item["bytes"] for item in results),
        "total_weapon_sockets": sum(len(item["weapon_sockets"])
                                    for item in results),
        "total_gun_port_sockets": sum(len(item["gun_port_sockets"])
                                      for item in results),
        "socket_gate": socket_report,
        "results": results,
    }
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=1)
    print("COMBAT_KIT_EXPORT_DONE %r"
          % {"assets": report["assets"],
             "bytes": report["total_bytes"],
             "weapon_sockets": report["total_weapon_sockets"],
             "gun_port_sockets": report["total_gun_port_sockets"],
             "workbench": report["workbench"]})
    return report


if __name__ == "__main__":
    export_all()
