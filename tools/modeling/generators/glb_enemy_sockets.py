# -*- coding: utf-8 -*-
# @static-doc
# 作用：`combat_kit` 敌舰 GLB 的 **socket 后处理（纯 Python）**——把导出时仍带 BLEND 资产前缀的
# `SN_ES_Socket_Weapon_Port_1` / `SN_ER_Socket_GunPort_Port_1` 归一化为契约标准名
# `SN_Socket_Weapon_Port_1` / `SN_Socket_GunPort_Port_1`，确保 socket 是 Root 的直接空子节点，
# 并把 socket 名单写进 Root extras；最后按 `combat_kit_generator` 的期望集合做完备性校验。
#
# ## 为什么需要后处理
# - 4 艘敌舰在同一个 Blender 工作台并排建，`SN_Socket_Weapon_Port_1` 这类标准名会撞 Blender
#   全局对象命名空间（静默加 `.001`）；所以 BLEND 内统一带资产前缀（`SN_ES_` / `SN_EG_` /
#   `SN_EM_` / `SN_ER_`），导出后再归一化（做法同 `glb_ship_sockets.py` / `glb_gun_ports.py`）；
# - Blender 的 IDProperty 不支持字符串数组，`weapon_sockets` / `gun_port_sockets` 名单只能在
#   GLB JSON 层写入（Blender 侧只保留 `weapon_socket_count` / `gun_port_socket_count` 与 spec）。
#
# ## 契约
# - 期望集合**完全一致**：`ck.expected_weapon_socket_names(asset)` +
#   `ck.expected_gun_port_names(asset)`；缺 / 多 / 重名 / 改名后重名都直接失败，**失败不写盘**
#   （抛 RuntimeError，保留可诊断报告，不落半成品）；
# - 每个 socket 节点必须存在且唯一、是 Root 的直接子节点、不带 mesh；
# - Root extras：`weapon_sockets`（按 socket_index 顺序的名字数组）、`weapon_socket_count`、
#   `socket_spec = "hull-sockets@1"`；有炮门的资产（当前只有 `SN_Enemy_Ironclad_Raider`）再写
#   `gun_port_sockets` / `gun_port_socket_count` / `gun_port_socket_spec = "hull-gunports@1"`；
#   没有炮门的资产会清掉残留的 `gun_port_*` extras；其余既有 extras 原样保留；
# - mesh / Root 名字不变；**只重写 JSON chunk，BIN chunk 原样保留**（写盘后回读比对 BIN 字节）。
#
# 用法：`python tools/modeling/generators/glb_enemy_sockets.py <path.glb> <asset>`，
# 或在导出脚本里 `import glb_enemy_sockets; glb_enemy_sockets.normalize(path, asset)`。
# @end-static-doc

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import combat_kit_generator as ck  # noqa: E402

WEAPON_PREFIX = "SN_Socket_Weapon"
GUN_PORT_PREFIX = "SN_Socket_GunPort"
WEAPON_MARKER = "_Socket_Weapon_"
GUN_PORT_MARKER = "_Socket_GunPort_"
SOCKET_SPEC = ck.SOCKET_SPEC
GUN_PORT_SPEC = ck.GUN_PORT_SPEC
GUN_PORT_EXTRAS = ("gun_port_sockets", "gun_port_socket_count", "gun_port_socket_spec")

_MAGIC = 0x46546C67
_JSON = 0x4E4F534A
_BIN = 0x004E4942


# --------------------------------------------------------------------------- #
# GLB 容器读写（只替换 JSON chunk）
# --------------------------------------------------------------------------- #

def _read_glb(path):
    with open(path, "rb") as handle:
        data = handle.read()
    magic, version, length = struct.unpack("<III", data[:12])
    if magic != _MAGIC:
        raise RuntimeError("%s: not a GLB" % path)
    offset = 12
    chunks = []
    while offset < length:
        chunk_length, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        chunks.append((chunk_type, data[offset + 8: offset + 8 + chunk_length]))
        offset += 8 + chunk_length
    return version, chunks


def _pack_glb(version, chunks):
    body = bytearray()
    for chunk_type, payload in chunks:
        pad = (-len(payload)) % 4
        if chunk_type == _JSON:
            payload = payload + b" " * pad
        else:
            payload = payload + b"\x00" * pad
        body += struct.pack("<II", len(payload), chunk_type) + payload
    return struct.pack("<III", _MAGIC, version, 12 + len(body)) + bytes(body)


def _write_glb(path, version, chunks):
    out = _pack_glb(version, chunks)
    tmp = path + ".tmp"
    with open(tmp, "wb") as handle:
        handle.write(out)
    os.replace(tmp, path)


# --------------------------------------------------------------------------- #
# 数据视图（全部来自 combat_kit_generator）
# --------------------------------------------------------------------------- #

def asset_info(asset):
    """返回该资产的 Root 名与期望 GLB 名单（顺序即 socket_index 顺序）。"""
    if asset not in ck.SHIP_CLASS_ORDER:
        raise RuntimeError("未知敌舰资产 %s（应属于 ck.SHIP_CLASS_ORDER）" % asset)
    cfg = ck.SHIP_CONFIGS[asset]
    return {
        "asset": asset,
        "root": cfg["root"],
        "weapon_sockets": list(ck.expected_weapon_socket_names(asset)),
        "gun_port_sockets": list(ck.expected_gun_port_names(asset)),
    }


def _normalize_name(name):
    """把一个带 BLEND 前缀的 socket 节点名归一化为契约标准名；无需改则返回 None。"""
    if WEAPON_MARKER in name and not name.startswith(WEAPON_PREFIX + "_"):
        return WEAPON_PREFIX + "_" + name.split(WEAPON_MARKER, 1)[1]
    if GUN_PORT_MARKER in name and not name.startswith(GUN_PORT_PREFIX + "_"):
        return GUN_PORT_PREFIX + "_" + name.split(GUN_PORT_MARKER, 1)[1]
    return None


def _collect(nodes, prefix):
    """{name: [node_index, ...]}，用于重名检测。"""
    table = {}
    short = prefix + "_"
    for index, node in enumerate(nodes):
        name = node.get("name", "")
        if name.startswith(short):
            table.setdefault(name, []).append(index)
    return table


def _check_set(label, expected, found, failures):
    """期望集合完全一致：缺 / 多 / 重名都记 failure。"""
    if len(set(expected)) != len(expected):
        failures.append("%s: 期望名单内部重复 %s" % (label, expected))
    duplicates = sorted(name for name, indices in found.items() if len(indices) > 1)
    if duplicates:
        failures.append("%s: 节点重名 %s" % (label, duplicates))
    missing = [name for name in expected if name not in found]
    if missing:
        failures.append("%s: 缺少节点 %s" % (label, missing))
    extra = sorted(name for name in found if name not in expected)
    if extra:
        failures.append("%s: 规格外节点 %s" % (label, extra))
    if len(found) != len(expected):
        failures.append("%s: 节点数 %d != 期望 %d" % (label, len(found), len(expected)))


def _reparent_sockets(nodes, root_index, root_name, expected, found, label,
                      failures):
    """确保每个 socket 都是 Root 的直接子节点（先摘掉其它父级，再加进 Root）。"""
    root = nodes[root_index]
    children = list(root.get("children", []))
    for name in expected:
        indices = found.get(name)
        if not indices:
            continue
        index = indices[0]
        node = nodes[index]
        if index == root_index:
            failures.append("%s: %s 就是 Root 节点本身" % (label, name))
            continue
        if "mesh" in node:
            failures.append("%s: %s 带 mesh（应为空节点）" % (label, name))
        for other_index, other in enumerate(nodes):
            if other_index == index:
                continue
            other_children = other.get("children")
            if other_children and index in other_children:
                other["children"] = [child for child in other_children
                                     if child != index]
        if index not in children:
            children.append(index)
    root["children"] = children


def _write_root_extras(root, info, renamed, report):
    extras = root.setdefault("extras", {})
    if info["weapon_sockets"]:
        extras["weapon_sockets"] = list(info["weapon_sockets"])
        extras["weapon_socket_count"] = len(info["weapon_sockets"])
        extras["socket_spec"] = SOCKET_SPEC
    if info["gun_port_sockets"]:
        extras["gun_port_sockets"] = list(info["gun_port_sockets"])
        extras["gun_port_socket_count"] = len(info["gun_port_sockets"])
        extras["gun_port_socket_spec"] = GUN_PORT_SPEC
    else:
        for key in GUN_PORT_EXTRAS:
            extras.pop(key, None)
    report["renamed"] = renamed
    return extras


def normalize(path, asset):
    """归一化 socket 节点名 + 修父子关系 + 写 Root extras；返回报告 dict。

    失败时抛 RuntimeError 且**不写盘**（不会留下半成品 GLB）。
    """
    info = asset_info(asset)
    if not info["weapon_sockets"]:
        raise RuntimeError("%s: 期望武器 socket 名单为空，拒绝后处理" % asset)
    version, chunks = _read_glb(path)
    json_chunks = [index for index, (chunk_type, _payload) in enumerate(chunks)
                   if chunk_type == _JSON]
    if len(json_chunks) != 1:
        raise RuntimeError("%s: GLB JSON chunk 数 %d != 1"
                           % (path, len(json_chunks)))
    json_index = json_chunks[0]
    gltf = json.loads(chunks[json_index][1].decode("utf-8"))
    nodes = gltf.get("nodes", [])
    if not nodes:
        raise RuntimeError("%s: GLB 没有 nodes" % path)

    report = {
        "asset": asset,
        "glb": path,
        "root": info["root"],
        "renamed": 0,
        "weapon_sockets": list(info["weapon_sockets"]),
        "gun_port_sockets": list(info["gun_port_sockets"]),
        "failures": [],
    }
    failures = report["failures"]

    renamed = 0
    for node in nodes:
        new_name = _normalize_name(node.get("name", ""))
        if new_name is not None:
            node["name"] = new_name
            renamed += 1

    weapon_found = _collect(nodes, WEAPON_PREFIX)
    port_found = _collect(nodes, GUN_PORT_PREFIX)
    _check_set("weapon_sockets", info["weapon_sockets"], weapon_found, failures)
    _check_set("gun_port_sockets", info["gun_port_sockets"], port_found, failures)

    root_index = next((index for index, node in enumerate(nodes)
                       if node.get("name") == info["root"]), None)
    if root_index is None:
        failures.append("找不到 Root 节点 %s" % info["root"])
    else:
        _reparent_sockets(nodes, root_index, info["root"],
                          info["weapon_sockets"], weapon_found,
                          "weapon_sockets", failures)
        _reparent_sockets(nodes, root_index, info["root"],
                          info["gun_port_sockets"], port_found,
                          "gun_port_sockets", failures)
        _write_root_extras(nodes[root_index], info, renamed, report)

    if failures:
        raise RuntimeError("GLB socket 归一化失败 %s: %s"
                           % (asset, "; ".join(failures)))

    out_chunks = list(chunks)
    payload = json.dumps(gltf, ensure_ascii=False,
                         separators=(",", ":")).encode("utf-8")
    out_chunks[json_index] = (_JSON, payload)
    _write_glb(path, version, out_chunks)

    # 写盘后回读：BIN chunk 必须逐字节不变（只允许 JSON chunk 变化）
    _version, check_chunks = _read_glb(path)
    original_bin = [payload for chunk_type, payload in chunks
                    if chunk_type == _BIN]
    written_bin = [payload for chunk_type, payload in check_chunks
                   if chunk_type == _BIN]
    if original_bin != written_bin:
        raise RuntimeError("%s: BIN chunk 被改动（不应发生）" % path)
    report["bin_unchanged"] = True
    report["passed"] = True
    return report


def normalize_all(asset, paths):
    """对同一资产的多个 GLB 路径（如 LOD）逐个归一化；失败即中断。"""
    reports = []
    for path in paths:
        reports.append(normalize(path, asset))
    return reports


def main(argv):
    args = [arg for arg in argv[1:] if not arg.startswith("--")]
    if len(args) != 2:
        print("用法: python glb_enemy_sockets.py <path.glb> <asset>")
        return 2
    path, asset = args
    report = normalize(path, asset)
    print(json.dumps(report, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
