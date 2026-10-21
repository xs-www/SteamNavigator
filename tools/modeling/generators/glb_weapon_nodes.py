# -*- coding: utf-8 -*-
# @static-doc
# 作用：武器装配规范 v2 的 GLB 节点名归一化（纯 Python）。
#
# Blender 场景里多件资产并排，`SN_Mount` / `SN_Pivot_Yaw` 这类标准节点名会因
# 全局对象命名空间被加 `.001` 后缀；生成器因此先写 `<资产前缀>Mount`、
# `<资产前缀>Pivot_Yaw` 等唯一名，导出 GLB 后再由本模块把节点名归一化为契约
# 规定的标准名：`<前缀>Mount` → `SN_Mount`，`<前缀>Pivot_Pitch` →
# `SN_Pivot_Pitch`，`<前缀>Muzzle_2` → `SN_Muzzle_2`，甲板的
# `<前缀>Socket_Weapon_Port` → `SN_Socket_Weapon_Port`。mesh / Root 名不受影响。
#
# 用法：`glb_weapon_nodes.standardize(path)`（导出脚本在 externalize 之后调用）。
# @end-static-doc

import json
import re
import struct

_ROLE_RE = re.compile(
    r"^(SN_[\w]+?)_("
    r"Mount|Pivot_Yaw|Pivot_Pitch(?:_[1-9])?|Recoil(?:_[1-9])?"
    r"|Muzzle(?:_[1-9])?|Anchor_[1-9]"
    r"|Socket_Weapon_(?:Port|Starboard)"
    r")$")

_MAGIC = 0x46546C67
_JSON = 0x4E4F534A
_BIN = 0x004E4942


def _read_glb(path):
    data = open(path, "rb").read()
    magic, version, length = struct.unpack("<III", data[:12])
    if magic != _MAGIC:
        raise RuntimeError("%s: not a GLB" % path)
    off = 12
    chunks = []
    while off < length:
        clen, ctype = struct.unpack("<II", data[off:off + 8])
        chunks.append((ctype, data[off + 8:off + 8 + clen]))
        off += 8 + clen
    return version, chunks


def _write_glb(path, version, chunks):
    out = bytearray()
    body = bytearray()
    for ctype, payload in chunks:
        pad = (-len(payload)) % 4
        if ctype == _JSON:
            payload = payload + b" " * pad
        else:
            payload = payload + b"\x00" * pad
        body += struct.pack("<II", len(payload), ctype) + payload
    out += struct.pack("<III", _MAGIC, version, 12 + len(body)) + body
    open(path, "wb").write(out)


def _rename_name(name):
    m = _ROLE_RE.match(name)
    if not m:
        return name
    return "SN_" + m.group(2)


def standardize(path, asset=None):
    """把 GLB 里资产前缀形式的武器标准节点名改成契约名；返回改名数。"""
    if asset is not None and not (asset.startswith("SN_Weapon_")
                                  or asset == "SN_ShipPart_Deck"):
        return 0
    version, chunks = _read_glb(path)
    changed = 0
    out_chunks = []
    for ctype, payload in chunks:
        if ctype != _JSON:
            out_chunks.append((ctype, payload))
            continue
        gltf = json.loads(payload.decode("utf-8"))
        for node in gltf.get("nodes", []):
            old = node.get("name", "")
            new = _rename_name(old)
            if new != old:
                node["name"] = new
                changed += 1
        out_chunks.append((ctype, json.dumps(
            gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")))
    if changed:
        _write_glb(path, version, out_chunks)
    return changed


if __name__ == "__main__":
    import sys
    total = 0
    for item in sys.argv[1:]:
        total += standardize(item)
    print("STANDARDIZED", total)
