# -*- coding: utf-8 -*-
# @static-doc
# 作用：生成通用共享材质贴图库（每张 512² 无缝平铺的 sRGB 贴图对应一个 `SN_*` 材质），
# 并把它们复制到运行时目录、拼出一张评审 montage、写出可复核的 stats。
#
# 材质贴图是“材质与模型分离”的资产真源：模型侧只按材质名引用，
# 贴图以相对 URI `shared_materials/<texture>.png` 作为外部共享资源随 core 模组发布。
# 规格文件：`docs/design/textures/shared_materials/shared_materials.spec.json`
# （材质名 / 纹理名 / tile_m / 粗糙度 / 金属度 / 调色板 / 均值目标都在 spec 里）。
#
# 画家复用 `tools/art/gen_iron_harbor_trim_sheet.py` 的周期噪声与木材 / 石材 / 玻璃
# 画家，保证与铁港建筑同一套低饱和手绘语言；金属 / 铸铁 / 锈红漆 / 黄铜 / 帆布 /
# 碎煤是新增画家。全部图案由 wrap-safe 的周期噪声与整数周期结构生成，天然无缝。
#
# 输出：
#   docs/design/textures/shared_materials/tiles/<texture>.png        512² PNG-8，入库真源
#   docs/design/textures/shared_materials/shared_materials_montage.png  评审 montage
#   docs/design/textures/shared_materials/shared_materials.stats.json   逐张统计 / 哈希 / 确定性
#   assets/models/props/shared_materials/<texture>.png                  开发态运行时副本
#   dev_mods/core/assets/models/props/shared_materials/<texture>.png    core 模组运行时副本
#
# 用法：
#   python tools/art/gen_shared_material_textures.py
#   python tools/art/gen_shared_material_textures.py --out-root <dir>
#   python tools/art/gen_shared_material_textures.py --spec <spec.json>
# @end-static-doc

import argparse
import hashlib
import io
import json
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import gen_iron_harbor_trim_sheet as ih  # noqa: E402  (同目录的共享画家 / 噪声助手)

DEFAULT_SPEC = REPO_ROOT / "docs" / "design" / "textures" / "shared_materials" / \
    "shared_materials.spec.json"


# --------------------------------------------------------------------------- #
# 新增画家（金属 / 铸铁 / 锈红漆 / 黄铜 / 帆布）
# --------------------------------------------------------------------------- #

def _paint_metal(spec, n, seed, rng):
    """拉丝钢板：低频明暗 + 纵向拉丝 + 少量磨亮高光 + 低洼油污。"""
    p = spec["palette"]
    base, alt = ih._rgb(p["base"]), ih._rgb(p["alt"])
    hi, grime = ih._rgb(p["hi"]), ih._rgb(p["grime"])
    u, v = ih._uv(n)

    mott = ih._periodic_noise(rng, n, 24.0, 8.0)
    brush = ih._periodic_noise(rng, n, 1.0, 56.0)
    fine = ih._periodic_noise(rng, n, 0.8)
    col = ih._lerp(base, alt, np.clip(0.5 + 0.24 * mott, 0.0, 1.0))
    col = col * (1.0 + 0.030 * brush[..., None] + 0.014 * fine[..., None])

    worn = ih._periodic_noise(rng, n, 1.2, 74.0) > 1.85
    col = np.where(worn[..., None], ih._lerp(col, hi, 0.22), col)

    patches = ih._periodic_noise(rng, n, 34.0, 20.0)
    col = ih._lerp(col, grime, np.clip(0.14 * (patches - 0.4), 0.0, 0.20))
    return col


def _paint_cast_iron(spec, n, seed, rng):
    """铸造铁：麻点 + 轻微铸造流痕 + 边缘磨损。"""
    p = spec["palette"]
    base, alt = ih._rgb(p["base"]), ih._rgb(p["alt"])
    hi, pit = ih._rgb(p["hi"]), ih._rgb(p["pit"])
    u, v = ih._uv(n)
    u_i, v_i = u.astype(np.int64), v.astype(np.int64)

    mott = ih._periodic_noise(rng, n, 20.0, 9.0)
    col = ih._lerp(base, alt, np.clip(0.5 + 0.30 * mott, 0.0, 1.0))
    col = col * (1.0 + 0.020 * ih._periodic_noise(rng, n, 0.9)[..., None])

    sand = ih._periodic_noise(rng, n, 2.2, 40.0)
    col = col * (1.0 + 0.012 * sand[..., None])

    pits = (ih._periodic_noise(rng, n, 0.9) > 2.35) & \
           (ih._hash01(seed + 11, u_i, v_i) < 0.65)
    col = np.where(pits[..., None], ih._lerp(col, pit, 0.50), col)

    edges = ih._periodic_noise(rng, n, 1.4, 60.0) > 2.05
    col = np.where(edges[..., None], ih._lerp(col, hi, 0.16), col)
    return col


def _paint_painted_rust(spec, n, seed, rng):
    """锈红漆面：低对比板缝 + 锈斑 + 划痕露金属。"""
    p = spec["palette"]
    base, alt = ih._rgb(p["base"]), ih._rgb(p["alt"])
    seam, rust, metal = ih._rgb(p["seam"]), ih._rgb(p["rust"]), ih._rgb(p["metal"])
    u, v = ih._uv(n)
    u_i, v_i = u.astype(np.int64), v.astype(np.int64)

    mott = ih._periodic_noise(rng, n, 22.0, 11.0)
    col = ih._lerp(base, alt, np.clip(0.5 + 0.20 * mott, 0.0, 1.0))
    col = col * (1.0 + 0.018 * ih._periodic_noise(rng, n, 0.9)[..., None])

    # 低对比板缝：每 1.0 m 一条（tile 2.0 m → n/2），缝宽 1.6 px
    seam_px = n / 2.0
    du = ih._circ_dist(u % seam_px, 0.0, seam_px)
    dv = ih._circ_dist(v % seam_px, 0.0, seam_px)
    col = np.where((du < 1.6)[..., None] | (dv < 1.6)[..., None],
                   ih._lerp(seam, base, 0.25), col)

    blooms = ih._periodic_noise(rng, n, 30.0, 18.0)
    rust_t = np.clip((blooms - 0.55) * 0.55, 0.0, 0.70)
    col = ih._lerp(col, rust, rust_t)

    scratches = ih._periodic_noise(rng, n, 0.9, 70.0) > 2.15
    chips = (ih._periodic_noise(rng, n, 0.9) > 2.5) & \
            (ih._hash01(seed + 17, u_i, v_i) < 0.55)
    exposed = scratches | chips
    col = np.where(exposed[..., None], ih._lerp(col, metal, 0.42), col)
    return col


def _paint_brass(spec, n, seed, rng):
    """黄铜：暖色拉丝 + 氧化暗带 + 铜绿斑点 + 高光擦痕。"""
    p = spec["palette"]
    base, alt = ih._rgb(p["base"]), ih._rgb(p["alt"])
    hi, tarnish, patina = ih._rgb(p["hi"]), ih._rgb(p["tarnish"]), ih._rgb(p["patina"])
    u, v = ih._uv(n)
    u_i, v_i = u.astype(np.int64), v.astype(np.int64)

    mott = ih._periodic_noise(rng, n, 18.0, 7.0)
    col = ih._lerp(base, alt, np.clip(0.5 + 0.26 * mott, 0.0, 1.0))
    col = col * (1.0 + 0.025 * ih._periodic_noise(rng, n, 1.1, 52.0)[..., None])

    tarnish_t = np.clip(0.30 * (ih._periodic_noise(rng, n, 1.6, 30.0) - 0.2), 0.0, 0.45)
    col = ih._lerp(col, tarnish, tarnish_t)

    patina_mask = (ih._periodic_noise(rng, n, 1.0) > 2.3) & \
                  (ih._hash01(seed + 23, u_i, v_i) < 0.55)
    col = np.where(patina_mask[..., None], ih._lerp(col, patina, 0.45), col)

    highlight = ih._periodic_noise(rng, n, 1.3, 66.0) > 2.0
    col = np.where(highlight[..., None], ih._lerp(col, hi, 0.30), col)
    return col


def _paint_canvas(spec, n, seed, rng):
    """粗帆布 / 麻绳：整数周期的平纹交织 + 纤维噪声 + 污渍。tile = 0.5 m。"""
    p = spec["palette"]
    base, alt = ih._rgb(p["base"]), ih._rgb(p["alt"])
    weave, stain = ih._rgb(p["weave"]), ih._rgb(p["stain"])
    u, v = ih._uv(n)

    thread = n / 32.0  # 32 根线 / 0.5 m → 156 根/米
    warp = 0.5 + 0.5 * np.cos(2.0 * np.pi * u / thread)
    weft = 0.5 + 0.5 * np.cos(2.0 * np.pi * v / thread)
    over_under = 0.5 + 0.5 * np.cos(2.0 * np.pi * (u + v) / (thread * 2.0))

    col = ih._lerp(base, alt, np.clip(0.28 + 0.22 * (warp + weft) - 0.10 * over_under, 0.0, 1.0))
    col = np.where(((warp > 0.72) & (weft > 0.72))[..., None],
                   ih._lerp(col, weave, 0.45), col)

    fiber = ih._periodic_noise(rng, n, 0.8, 9.0)
    col = col * (1.0 + 0.026 * fiber[..., None])

    stains = ih._periodic_noise(rng, n, 26.0)
    col = ih._lerp(col, stain, np.clip(0.18 * (stains - 0.7), 0.0, 0.16))
    return col


def _paint_coal(spec, n, seed, rng):
    """碎煤堆：低明度块面 + 低洼灰尘 + 少量反光棱面。tile = 1.0 m。"""
    p = spec["palette"]
    base, alt, hi = ih._rgb(p["base"]), ih._rgb(p["alt"]), ih._rgb(p["hi"])

    lump = ih._periodic_noise(rng, n, 6.0, 7.0)
    fine = ih._periodic_noise(rng, n, 1.4)
    col = ih._lerp(base, alt, np.clip(0.55 + 0.30 * lump, 0.0, 1.0))
    # 小棱面高光（碎块反光），阈值偏高，保持整体低明度
    facet = ih._periodic_noise(rng, n, 1.0, 3.0) > 1.15
    col = np.where(facet[..., None], ih._lerp(col, hi, 0.22), col)
    col = col * (1.0 + 0.035 * fine[..., None])
    return col


_CUSTOM_PAINTERS = {
    "metal": _paint_metal,
    "cast_iron": _paint_cast_iron,
    "painted_rust": _paint_painted_rust,
    "brass": _paint_brass,
    "canvas": _paint_canvas,
    "coal": _paint_coal,
}

# 直接复用铁港建筑的画家（同一套低饱和手绘语言）
_IRON_HARBOR_PAINTERS = {
    "wood": ih._paint_wood,
    "stone": ih._paint_stone,
    "glass": ih._paint_glass,
}


def _seed_for(material):
    digest = hashlib.sha256(("shared_materials/" + material["texture"]).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "little")


def paint_material(material, n, colors):
    """按 spec 条目画一张 tile，返回 (paletted PIL image, named bytes, rgb array)."""
    kind = material["kind"]
    seed = _seed_for(material)
    rng = np.random.default_rng(seed)
    if kind in _CUSTOM_PAINTERS:
        arr = _CUSTOM_PAINTERS[kind](material, n, seed, rng)
    elif kind in _IRON_HARBOR_PAINTERS:
        cell = {"palette": material["palette"], "detail": material.get("detail", "")}
        arr = _IRON_HARBOR_PAINTERS[kind](cell, n, seed, rng,
                                          str(material.get("detail", "")).lower())
    else:
        raise ValueError("unknown material kind %r" % kind)

    arr = arr + ih.FINE_GRAIN * ih._periodic_noise(rng, n, 0.6)[..., None]
    pal, rgb = ih._finish_tile(arr, material["mean_rgb"], colors)
    buf = io.BytesIO()
    pal.save(buf, format="PNG", optimize=True)
    return pal, buf.getvalue(), rgb


def _seam_ratio(rgb):
    """wrap 边差异 / 内部步进（与铁港生成器同一口径）；阈值见 ih.SEAM_RATIO_MAX。"""
    return max(ih._seam_ratio(rgb, 1), ih._seam_ratio(rgb, 0))


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def build(out_root, spec_path):
    out_root = Path(out_root).resolve()
    spec_path = Path(spec_path).resolve()
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    n = int(spec["tile_px"])
    colors = int(spec.get("quantize_colors", 96))
    tiles_dir = out_root / spec["outputs"]["tiles"]
    montage_path = out_root / spec["outputs"]["montage"]
    stats_path = out_root / spec["outputs"]["stats"]

    tiles = []
    rows = []
    row = []
    for material in spec["materials"]:
        pal, png, rgb = paint_material(material, n, colors)
        # 确定性：同 spec 再画一次必须逐字节相同
        _pal2, png2, _rgb2 = paint_material(material, n, colors)
        name = material["texture"]
        path = tiles_dir / (name + ".png")
        _write(path, png)
        tiles.append({
            "material": material["name"],
            "texture": name,
            "file": str(path.relative_to(out_root)).replace("\\", "/"),
            "bytes": len(png),
            "sha256": _sha(png),
            "deterministic": png == png2,
            "tile_m": material["tile_m"],
            "px_per_m": round(n / float(material["tile_m"]), 1),
            "roughness": material["roughness"],
            "metallic": material["metallic"],
            "mean_rgb": [round(float(v), 2) for v in rgb.reshape(-1, 3).mean(axis=0)],
            "target_mean": material["mean_rgb"],
            "seam_ratio": round(_seam_ratio(rgb), 4),
        })
        row.append(pal.convert("RGB"))
        if len(row) == 5:
            rows.append(row)
            row = []
    if row:
        rows.append(row)

    width = max(len(r) for r in rows) * n
    montage = Image.new("RGB", (width, len(rows) * n), (28, 30, 34))
    for r, row_images in enumerate(rows):
        for c, image in enumerate(row_images):
            montage.paste(image, (c * n, r * n))
    # 评审 montage 输出半尺寸（1280x512）以控制仓库体积；tiles 本身保持 512²。
    montage = montage.resize((width // 2, len(rows) * n // 2), Image.LANCZOS)
    mbuf = io.BytesIO()
    montage.save(mbuf, format="PNG", optimize=True)
    _write(montage_path, mbuf.getvalue())

    copies = []
    for runtime_dir in spec["runtime_dirs"]:
        target_dir = out_root / runtime_dir
        target_dir.mkdir(parents=True, exist_ok=True)
        for tile in tiles:
            src = out_root / tile["file"]
            dst = target_dir / (tile["texture"] + ".png")
            dst.write_bytes(src.read_bytes())
            copies.append(str(dst.relative_to(out_root)).replace("\\", "/"))

    stats = {
        "spec": str(spec_path.relative_to(out_root)).replace("\\", "/"),
        "tile_px": n,
        "colors": colors,
        "tile_m_default": spec.get("tile_m"),
        "materials": tiles,
        "montage": {
            "file": str(montage_path.relative_to(out_root)).replace("\\", "/"),
            "bytes": len(mbuf.getvalue()),
            "sha256": _sha(mbuf.getvalue()),
        },
        "runtime_copies": copies,
        "all_deterministic": all(t["deterministic"] for t in tiles),
        "all_seam_ok": all(t["seam_ratio"] <= ih.SEAM_RATIO_MAX for t in tiles),
        "total_bytes": sum(t["bytes"] for t in tiles),
    }
    _write(stats_path, json.dumps(stats, ensure_ascii=False, indent=2).encode("utf-8"))
    return stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-root", default=str(REPO_ROOT))
    parser.add_argument("--spec", default=str(DEFAULT_SPEC))
    args = parser.parse_args()
    stats = build(args.out_root, args.spec)
    print("%-22s %8s %8s %-8s %-26s %s" % (
        "material", "bytes", "seam", "det", "mean(rgb)", "target"))
    print("-" * 92)
    for tile in stats["materials"]:
        print("%-22s %8d %8.4f %-8s %-26s %s" % (
            tile["material"], tile["bytes"], tile["seam_ratio"],
            tile["deterministic"], tile["mean_rgb"], tile["target_mean"]))
    print("-" * 92)
    print("tiles=%d total_bytes=%d deterministic=%s seam_ok=%s" % (
        len(stats["materials"]), stats["total_bytes"],
        stats["all_deterministic"], stats["all_seam_ok"]))
    print("montage=%s" % stats["montage"]["file"])
    return 0 if (stats["all_deterministic"] and stats["all_seam_ok"]) else 1


if __name__ == "__main__":
    sys.exit(main())
