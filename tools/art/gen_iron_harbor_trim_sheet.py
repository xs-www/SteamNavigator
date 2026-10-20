#!/usr/bin/env python3
"""Generate the iron-harbor shared material trim sheet for Steam Navigator.

The iron-harbor "town kit" uses six materials (SN_Town_Brick / Plaster / Wood /
Iron / Stone / Glass) that all sample one shared atlas.  The atlas is a 4x4 grid
of sixteen 512x512 cells; every cell is a full-bleed, seamlessly tiling 2.0 m
material patch (256 px/m, no gutters).  Each cell is also emitted as its own
standalone tiling texture because that is what the GLB / UV mapping samples.

Outputs (paths come from the spec, relative to --out-root; the default out-root
is the repository root):

    docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.png
        2048x2048 RGB review montage (4x4, row 0 at the top).  Never sampled by
        the game; it exists so the whole set can be judged at a glance.  It is
        assembled from exactly the same arrays as the tile files, so the two
        cannot drift.

    docs/design/textures/iron_harbor/tiles/<cell_id>.png
        16 standalone 512x512 tiling textures, PNG-8 with an adaptive 96-colour
        palette, no alpha.  Deterministic: two runs are byte-identical.

    docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.stats.json
        Per-cell measured mean vs target, seam-vs-interior ratios, tile bytes +
        sha256, atlas sha256, montage bytes, determinism and validation flags.

Run:
    python tools/art/gen_iron_harbor_trim_sheet.py
    python tools/art/gen_iron_harbor_trim_sheet.py --out-root D:\\somewhere
    python tools/art/gen_iron_harbor_trim_sheet.py --spec PATH --stats PATH

The generator is deterministic.  Every pattern is built from wrapped / modular
coordinates and integer period counts, so each 512 px tile wraps exactly on
itself in U and V (no border, no gutter fill, no visible grid).

Spec deltas worth knowing (the spec prose still carries a few 480-px-era
numbers; the metre values and the grid block are authoritative):
  * A cell is 512 px = 2.0 m, i.e. 256 px/m.  Brick course = 512/26, stone
    course = 512/4, etc.
  * The roof detail says ribs every 0.15 m; 2.0 m is not a multiple of 0.15 m,
    so the tile uses 13 integer ribs (0.1538 m) instead of a non-wrapping
    13.33 ribs.
  * The wood detail says 0.22 m planks; the tile uses 9 integer planks
    (0.2222 m) for the same reason.
  * Detail pixel numbers quoted at the old 240 px/m scale (18.4 px courses,
    60 px bricks, 36 px ribs, 53 px planks, 3 px joints) are treated as
    art-direction sizes; metre values win where both exist.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# art direction / tuning constants
# ---------------------------------------------------------------------------
TILE_M = 2.0  # metres covered by one cell (spec "tile_m")

# Brick: 26 courses and 8 bricks per 2.0 m (spec detail, metre derived).
BRICK_COURSES = 26
BRICKS_PER_COURSE = 8
MORTAR_PX = 2.0

# Stone: coursed ashlar, 4 courses per 2.0 m, 3 px recessed joints, block
# lengths 1.0 m and 0.67 m.
STONE_COURSES = 4
STONE_JOINT_PX = 3.0

# Iron: 1.0 m plate seams, rivet rows every 0.125 m, 4 px rivet dots.
IRON_PLATE_M = 1.0
IRON_RIVET_M = 0.125
IRON_RIVET_PX = 2.2  # dot radius

# Roof: corrugated sheet, integer ribs running along V, sheet seams every 1.0 m.
ROOF_RIBS = 13
ROOF_SEAM_M = 1.0

# Wood: integer vertical planks (0.2222 m each) with 2 px dark gaps.
WOOD_PLANKS = 9
PLANK_GAP_PX = 2.0

# Reserved iron_grate: 0.25 m bar grating cells.
GRATE_CELL_M = 0.25

# Glass: single soft diagonal reflection band, wrap-safe.
GLASS_BAND_OFFSET = 0.30  # band centre as a fraction of the tile diagonal
GLASS_BAND_WIDTH = 0.105  # band sigma as a fraction of the tile

# Validation thresholds from the task/spec.
MEAN_TOLERANCE = 14.0
SEAM_RATIO_MAX = 2.5

# Per-channel mean matching: bounded so the palette identity survives the grade.
GRADE_LIMIT = 22.0

# A whisper of periodic fine grain stops the palette quantiser from producing
# long flat plateaus (which would make the seam metric noisy on smooth cells).
FINE_GRAIN = 1.1

# Per-cell RNG derivation.  Never a shared global sequence: the seed is hashed
# from the cell id, so cell iteration order can never affect the output.
SEED_SALT = "iron_harbor_trim_sheet_2048"


# ---------------------------------------------------------------------------
# small numpy helpers
# ---------------------------------------------------------------------------
def _uv(n: int) -> tuple[np.ndarray, np.ndarray]:
    """Pixel-centre coordinates (u = column, v = row) of one cell."""
    v, u = np.mgrid[0:n, 0:n]
    return u.astype(np.float64), v.astype(np.float64)


def _rgb(colour) -> np.ndarray:
    return np.asarray(colour, dtype=np.float64)


def _lerp(a, b, t) -> np.ndarray:
    """Linear blend a -> b; t may be a scalar or a (n, n) array."""
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    t = np.asarray(t, dtype=np.float64)
    if t.ndim:
        t = t[..., None]
    return a + (b - a) * t


def _px(metres: float, n: int) -> float:
    """Metres -> pixels inside one cell (a cell spans TILE_M)."""
    return metres * n / TILE_M


def _circ_dist(x: np.ndarray, centre: float, period: float) -> np.ndarray:
    """Wrap-around distance from x to centre on a periodic axis."""
    d = np.abs(x - centre) % period
    return np.minimum(d, period - d)


def _cell_seed(cell_id: str) -> int:
    """Stable per-cell RNG seed derived from the cell id (never Python hash)."""
    digest = hashlib.sha256(f"{SEED_SALT}/{cell_id}".encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "little")


def _hash01(seed: int, a, b) -> np.ndarray:
    """Deterministic 64-bit hash -> float in [0, 1) for integer cell identity.

    Used for per-brick / per-plank / per-pixel jitter so the result depends only
    on the identity of the element, never on iteration order.
    """
    a = np.asarray(a, dtype=np.uint64)
    b = np.asarray(b, dtype=np.uint64)
    x = a * np.uint64(0x9E3779B97F4A7C15)
    x = x + b * np.uint64(0xBF58476D1CE4E5B9)
    x = x + np.uint64(seed & 0xFFFFFFFFFFFFFFFF)
    x = x ^ (x >> np.uint64(30))
    x = x * np.uint64(0xBF58476D1CE4E5B9)
    x = x ^ (x >> np.uint64(27))
    x = x * np.uint64(0x94D049BB133111EB)
    x = x ^ (x >> np.uint64(31))
    return (x >> np.uint64(11)).astype(np.float64) / float(1 << 53)


def _periodic_noise(rng: np.random.Generator, n: int,
                    sigma_x: float, sigma_y: float | None = None) -> np.ndarray:
    """Zero-mean unit-std Gaussian-filtered noise, exactly periodic on n pixels.

    Filtering in the frequency domain makes the field periodic by construction,
    so every structure derived from it tiles in U and V without a border.
    """
    if sigma_y is None:
        sigma_y = sigma_x
    white = rng.standard_normal((n, n)).astype(np.float64)
    spectrum = np.fft.rfft2(white)
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.rfftfreq(n)[None, :]
    kernel = np.exp(-2.0 * np.pi ** 2 * (sigma_x ** 2 * fx ** 2 +
                                        sigma_y ** 2 * fy ** 2))
    field = np.fft.irfft2(spectrum * kernel, s=(n, n))
    field -= field.mean()
    std = field.std()
    if std > 1e-9:
        field /= std
    return field


# ---------------------------------------------------------------------------
# cell painters -- one per spec "kind", parameterised from palette + detail
# ---------------------------------------------------------------------------
def _paint_brick(cell, n: int, seed: int, rng, detail: str) -> np.ndarray:
    """Running-bond brick: 26 courses, 8 bricks per course, staggered half bond."""
    p = cell["palette"]
    brick, brick_alt = _rgb(p["brick"]), _rgb(p["brick_alt"])
    mortar, soot = _rgb(p["mortar"]), _rgb(p["soot"])
    u, v = _uv(n)

    course_h = n / BRICK_COURSES
    brick_len = n / BRICKS_PER_COURSE
    # Phase the pattern so the tile edge crosses mid-brick / mid-course instead
    # of a mortar joint; the tile is still a continuous crop of the same bond.
    v_shift = (v + course_h * 0.5) % n
    course = np.floor(v_shift / course_h).astype(np.int64)
    local_y = v_shift - course * course_h
    offset = (course % 2) * (brick_len * 0.5)
    xp = (u + offset + brick_len * 0.25) % n
    brick_x = np.floor(xp / brick_len).astype(np.int64)
    local_x = xp - brick_x * brick_len

    joint = (local_x < MORTAR_PX) | (local_y < MORTAR_PX)

    tone = _hash01(seed + 11, course * 97 + 3, brick_x)
    base = _lerp(brick, brick_alt, tone)
    base = base * (0.94 + 0.12 * _hash01(seed + 12, course, brick_x + 7))[..., None]
    base = base * (1.0 + 0.020 * _periodic_noise(rng, n, 1.5))[..., None]

    recess = np.minimum(local_x, local_y)
    recess_t = np.clip(1.0 - recess / MORTAR_PX, 0.0, 1.0)
    mortar_col = _lerp(mortar, soot, 0.20 + 0.45 * recess_t)
    mortar_col = mortar_col * (1.0 + 0.015 * _periodic_noise(rng, n, 0.8))[..., None]

    col = np.where(joint[..., None], mortar_col, base)

    # faint vertical soot streaks (narrow in U, long in V)
    streak = _periodic_noise(rng, n, 2.0, 36.0)
    col = _lerp(col, soot, np.clip(0.30 * (streak - 0.5), 0.0, 0.30))

    if "heavier soot" in detail:
        # Heavier soot from the top; periodic in V, so it wraps as a sooty band
        # at the tile edge instead of breaking the tiling.
        band = np.exp((np.cos(2.0 * np.pi * v / n) - 1.0) * 3.2)
        col = _lerp(col, soot, 0.55 * band)
    if "damp" in detail:
        band = np.exp((np.cos(2.0 * np.pi * (v / n - 0.5)) - 1.0) * 3.4)
        col = _lerp(col, _lerp(soot, mortar, 0.35), 0.35 * band)
    return col


def _paint_stone(cell, n: int, seed: int, rng, detail: str) -> np.ndarray:
    """Coursed ashlar: 4 courses, 0.5 m / 0.33 m blocks, 3 px recessed joints."""
    p = cell["palette"]
    block, block_alt = _rgb(p["block"]), _rgb(p["block_alt"])
    joint_c, damp = _rgb(p["joint"]), _rgb(p["damp"])
    u, v = _uv(n)

    course_h = n / STONE_COURSES
    # Crop the tile away from the joints so the wrap edge runs through block
    # faces (a tile is just a crop of an infinite masonry field).
    us = (u + 31.0) % n
    vs = (v + course_h * 0.5) % n
    course = np.floor(vs / course_h).astype(np.int64)
    local_y = vs - course * course_h

    # Two bond patterns, both summing to one tile: 2 blocks of 1.0 m, or
    # 3 blocks of 0.67 m.  Per-course offsets stagger the vertical joints.
    layouts = ((0.5, 0.5), (1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0))
    offsets = (0.0, 0.21 * n, 0.09 * n, 0.44 * n)

    block_x = np.zeros((n, n), dtype=np.int64)
    local_x = np.zeros((n, n), dtype=np.float64)
    for c in range(STONE_COURSES):
        mask = course == c
        lengths = np.asarray(layouts[c % 2], dtype=np.float64) * n
        cumulative = np.cumsum(lengths)
        xp = (us[mask] - offsets[c]) % n
        idx = np.searchsorted(cumulative, xp, side="right")
        idx = np.minimum(idx, len(cumulative) - 1)
        previous = np.where(idx > 0, cumulative[np.maximum(idx - 1, 0)], 0.0)
        block_x[mask] = idx
        local_x[mask] = xp - previous

    joint = (local_x < STONE_JOINT_PX) | (local_y < STONE_JOINT_PX)

    tone = _hash01(seed + 21, course * 53 + 1, block_x)
    base = _lerp(block, block_alt, tone)
    base = base * (0.93 + 0.14 * _hash01(seed + 24, course + 3, block_x + 5))[..., None]
    # patchy weathering inside each block (broad stains + finer mottling)
    base = base * (1.0 + 0.060 * _periodic_noise(rng, n, 30.0))[..., None]
    base = base * (1.0 + 0.030 * _periodic_noise(rng, n, 10.0))[..., None]
    # porous stone grain and a few pits
    base = base * (1.0 + 0.030 * _periodic_noise(rng, n, 1.3))[..., None]
    u_i = u.astype(np.int64)
    v_i = v.astype(np.int64)
    pits = (_periodic_noise(rng, n, 0.8) > 2.55) & \
           (_hash01(seed + 25, u_i, v_i) < 0.8)
    base = np.where(pits[..., None], _lerp(base, joint_c, 0.35), base)
    # weathering darkens the stone towards the joint edges
    edge_fade = np.clip((STONE_JOINT_PX + 6.0 -
                         np.minimum(local_x, local_y)) / 6.0, 0.0, 1.0)
    base = base * (1.0 - 0.10 * edge_fade)[..., None]

    recess = np.minimum(local_x, local_y)
    recess_t = np.clip(1.0 - recess / STONE_JOINT_PX, 0.0, 1.0)
    joint_col = _lerp(joint_c, damp, 0.25)
    joint_col = _lerp(joint_col, joint_c * 0.78, 0.60 * recess_t)

    col = np.where(joint[..., None], joint_col, base)

    # chipped corners: a little broken material right at the joint crossings
    near_corner = (local_x < STONE_JOINT_PX + 4.0) & (local_y < STONE_JOINT_PX + 4.0)
    chip = near_corner & (_hash01(seed + 22, u_i, v_i) < 0.30)
    col = np.where(chip[..., None], _lerp(col, joint_c, 0.55), col)

    # Slight damp darkening as broad, soft vertical stains (not brushed grain).
    damp_field = _periodic_noise(rng, n, 16.0, 38.0)
    damp_t = np.clip(0.24 * (damp_field - 0.15), 0.0, 0.24)
    if "damp streaks" in detail:
        streaks = _periodic_noise(rng, n, 2.8, 34.0)
        damp_t = np.clip(0.34 * (damp_field - 0.0) +
                         0.20 * (streaks - 0.2), 0.0, 0.45)
    col = _lerp(col, damp, damp_t)

    if "moss" in detail:
        moss = _rgb((86, 94, 64))
        speck = (_periodic_noise(rng, n, 0.8) > 2.45) & \
                (_hash01(seed + 23, u_i, v_i) < 0.65)
        col = np.where(speck[..., None], _lerp(col, moss, 0.45), col)
    return col


def _paint_grate(cell, n: int, seed: int, rng, detail: str) -> np.ndarray:
    """Reserved iron_grate: flat plate with a 0.25 m bar-grating pattern."""
    p = cell["palette"]
    plate, plate_alt = _rgb(p["plate"]), _rgb(p["plate_alt"])
    seam, rivet, rust = _rgb(p["seam"]), _rgb(p["rivet"]), _rgb(p["rust"])
    u, v = _uv(n)

    cell_px = _px(GRATE_CELL_M, n)
    local_x = u % cell_px
    local_y = v % cell_px
    bar = cell_px * 0.20
    inner = cell_px - bar

    inside = (local_x >= bar) & (local_x < inner) & (local_y >= bar) & (local_y < inner)
    edge = np.minimum(np.minimum(local_x - bar, inner - local_x),
                      np.minimum(local_y - bar, inner - local_y))
    edge = np.where(inside, edge, 0.0)
    hole_base = _lerp(seam, plate_alt, 0.15)
    hole_col = hole_base * (0.70 + 0.38 * np.clip(edge / 9.0, 0.0, 1.0))[..., None]

    base = _lerp(plate, plate_alt, _hash01(seed + 31, np.floor(u / cell_px), np.floor(v / cell_px)))
    base = base * (1.0 + 0.02 * _periodic_noise(rng, n, 12.0))[..., None]

    col = np.where(inside[..., None], hole_col, base)

    # rounded bar highlight towards the bar centre line (the cell border)
    border = np.minimum(np.minimum(local_x, cell_px - local_x),
                        np.minimum(local_y, cell_px - local_y))
    bar_light = np.exp(-0.5 * (border / 3.2) ** 2)
    col = _lerp(col, _lerp(plate, rivet, 0.45), 0.70 * bar_light)

    # rivets at the bar intersections
    dot_d = np.sqrt(np.minimum(local_x, cell_px - local_x) ** 2 +
                    np.minimum(local_y, cell_px - local_y) ** 2)
    rivet_mask = dot_d < 2.4
    rivet_t = np.clip(1.0 - dot_d / 2.4, 0.0, 1.0) ** 0.6
    col = np.where(rivet_mask[..., None], _lerp(seam, rivet, rivet_t), col)

    field = _periodic_noise(rng, n, 7.0)
    rust_t = np.clip((field - 1.35) * 1.2, 0.0, 0.60)
    col = _lerp(col, _lerp(plate, rust, 0.55), rust_t)
    return col


def _paint_iron(cell, n: int, seed: int, rng, detail: str) -> np.ndarray:
    """Riveted plate: 1.0 m plate seams, rivet rows every 0.125 m."""
    if "grating" in detail:
        return _paint_grate(cell, n, seed, rng, detail)

    p = cell["palette"]
    plate, plate_alt = _rgb(p["plate"]), _rgb(p["plate_alt"])
    seam, rivet, rust = _rgb(p["seam"]), _rgb(p["rivet"]), _rgb(p["rust"])
    u, v = _uv(n)

    plate_px = _px(IRON_PLATE_M, n)
    # Crop mid-plate so the wrap edge does not sit on a plate seam.
    us = (u + plate_px * 0.5) % n
    vs = (v + plate_px * 0.5) % n
    dist_u = _circ_dist(us % plate_px, 0.0, plate_px)
    dist_v = _circ_dist(vs % plate_px, 0.0, plate_px)

    plate_x = np.floor(us / plate_px).astype(np.int64)
    plate_y = np.floor(vs / plate_px).astype(np.int64)
    tone = _hash01(seed + 41, plate_y * 2 + plate_x, 1)
    base = _lerp(plate, plate_alt, 0.25 + 0.55 * tone)
    base = base * (1.0 + 0.030 * _periodic_noise(rng, n, 24.0))[..., None]
    base = base * (1.0 + 0.012 * _periodic_noise(rng, n, 1.2))[..., None]

    spacing = _px(IRON_RIVET_M, n)
    row_v = np.abs((vs % spacing) - spacing * 0.5)
    row_u = np.abs((us % spacing) - spacing * 0.5)
    rad_v = np.sqrt(dist_u ** 2 + row_v ** 2)
    rad_u = np.sqrt(dist_v ** 2 + row_u ** 2)
    rad = np.minimum(rad_v, rad_u)
    rivet_mask = rad < IRON_RIVET_PX
    rivet_t = np.clip(1.0 - rad / IRON_RIVET_PX, 0.0, 1.0) ** 0.6

    seam_mask = (dist_u < 1.5) | (dist_v < 1.5)
    seam_col = _lerp(seam, plate, 0.15)
    lip = ((dist_u >= 1.5) & (dist_u < 3.2)) | ((dist_v >= 1.5) & (dist_v < 3.2))

    col = base
    col = np.where(lip[..., None], _lerp(col, rivet, 0.10), col)
    col = np.where(seam_mask[..., None], seam_col, col)
    col = np.where(rivet_mask[..., None], _lerp(seam, rivet, rivet_t), col)

    bloom = _periodic_noise(rng, n, 9.0)
    texture = _periodic_noise(rng, n, 2.4)
    runs = _periodic_noise(rng, n, 1.4, 26.0)
    if "blooms" in detail:
        # Rust blooms over roughly a third of the plate, softened and broken up
        # internally so they read as corrosion rather than paint.
        base_t = np.clip((bloom - 0.10) * 1.05, 0.0, 1.0) ** 1.15
        rust_t = np.clip(base_t * (0.62 + 0.45 * texture) +
                         0.10 * np.clip(runs, 0.0, 1.0), 0.0, 0.85)
        tint = _lerp(_lerp(plate, rust, 0.50), _lerp(plate, rust, 0.80),
                     np.clip(0.5 + 0.5 * texture, 0.0, 1.0))
    else:
        rust_t = np.clip((bloom - 1.60) * 1.20 +
                         0.10 * np.clip(runs - 1.0, 0.0, 1.0), 0.0, 0.55)
        tint = _lerp(plate, rust, 0.55)
    col = _lerp(col, tint, rust_t)
    return col


def _paint_roof(cell, n: int, seed: int, rng, detail: str) -> np.ndarray:
    """Corrugated roof sheet: integer ribs along V, seams every 1.0 m."""
    p = cell["palette"]
    sheet, rib_hi = _rgb(p["sheet"]), _rgb(p["rib_hi"])
    rib_lo, seam, rust = _rgb(p["rib_lo"]), _rgb(p["seam"]), _rgb(p["rust"])
    u, v = _uv(n)

    rib_px = n / ROOF_RIBS
    # Crop mid-rib at the wrap edge so the seam is not a crest/valley edge.
    up = (u + rib_px * 0.5) % n
    phase = (up % rib_px) / rib_px
    profile = 0.5 + 0.5 * np.cos(2.0 * np.pi * phase)
    col = _lerp(rib_lo, rib_hi, profile)

    rib_index = np.floor(up / rib_px).astype(np.int64)
    tone = 0.94 + 0.12 * _hash01(seed + 51, rib_index, 0)
    col = col * tone[..., None]
    col = col * (1.0 + 0.020 * _periodic_noise(rng, n, 26.0))[..., None]

    # specular crest line, then a darker valley
    crest = np.exp(-0.5 * (_circ_dist(up % rib_px, 0.0, rib_px) / 1.7) ** 2)
    col = _lerp(col, _lerp(rib_hi, sheet, 0.35), 0.45 * crest)
    valley = np.exp(-0.5 * (np.abs((up % rib_px) - rib_px * 0.5) / 2.0) ** 2)
    col = _lerp(col, _lerp(rib_lo, seam, 0.25), 0.40 * valley)

    # horizontal sheet seams every 1.0 m (period n/2)
    seam_px = _px(ROOF_SEAM_M, n)
    dist_seam = _circ_dist(v % seam_px, 0.0, seam_px)
    col = np.where((dist_seam < 1.6)[..., None],
                   _lerp(seam, rib_lo, 0.25), col)
    lip = (dist_seam >= 1.6) & (dist_seam < 3.6)
    col = np.where(lip[..., None], _lerp(col, rib_hi, 0.18), col)

    runs = _periodic_noise(rng, n, 1.6, 26.0)
    if "stronger rust" in detail:
        soot_band = np.exp(-0.5 * (dist_seam / 18.0) ** 2)
        col = _lerp(col, _lerp(seam, rib_lo, 0.30), 0.35 * soot_band)
        rust_t = np.clip((runs - 0.35) * 1.40, 0.0, 0.75)
    else:
        rust_t = np.clip((runs - 1.20) * 1.20, 0.0, 0.55)
    col = _lerp(col, _lerp(sheet, rust, 0.55), rust_t)
    return col


def _paint_glass(cell, n: int, seed: int, rng, detail: str) -> np.ndarray:
    """Very dark pane with one soft, wrap-safe diagonal reflection band."""
    p = cell["palette"]
    glass, reflect, grime = _rgb(p["glass"]), _rgb(p["reflect"]), _rgb(p["grime"])
    u, v = _uv(n)

    diagonal = (u + v) % n
    centre = GLASS_BAND_OFFSET * n
    width = GLASS_BAND_WIDTH * n
    band = np.exp(-0.5 * (_circ_dist(diagonal, centre, n) / width) ** 2)

    brightness = 0.95 if "brighter" in detail else 0.55
    col = _lerp(glass, reflect, brightness * band)

    # uneven, slightly grubby glass: very low contrast, no tiling structure
    col = col * (1.0 + 0.035 * _periodic_noise(rng, n, 34.0))[..., None]
    col = col * (1.0 + 0.015 * _periodic_noise(rng, n, 1.4))[..., None]

    u_i = u.astype(np.int64)
    v_i = v.astype(np.int64)
    dust = (_periodic_noise(rng, n, 0.8) > 2.35) & \
           (_hash01(seed + 61, u_i, v_i) < 0.7)
    col = np.where(dust[..., None], _lerp(col, grime, 0.45), col)
    return col


def _paint_wood(cell, n: int, seed: int, rng, detail: str) -> np.ndarray:
    """Vertical planks (default) or a coarse horizontal timber beam (reserved)."""
    p = cell["palette"]
    plank, plank_alt = _rgb(p["plank"]), _rgb(p["plank_alt"])
    gap, grain = _rgb(p["gap"]), _rgb(p["grain"])
    u, v = _uv(n)

    if "horizontal" in detail:
        # Reserved timber_beam: coarse horizontal grain + a few wrapped knots.
        base = _lerp(plank, plank_alt, _hash01(seed + 71, v.astype(np.int64), 3))
        base = base * (1.0 + 0.025 * _periodic_noise(rng, n, 30.0, 3.0))[..., None]
        wav = _periodic_noise(rng, n, 40.0, 18.0)
        lines = np.sin(2.0 * np.pi * (v / 14.0) + 2.0 * wav)
        col = _lerp(base, grain, np.clip(-lines, 0.0, 1.0) ** 1.2 * 0.50)
        knots = rng.integers(0, n, size=(3, 2))
        for cx, cy in knots:
            du = _circ_dist(u, float(cx), n)
            dv = _circ_dist(v, float(cy), n)
            radius = np.sqrt(du ** 2 + dv ** 2)
            ring = np.exp(-0.5 * ((radius - 6.0) / 1.8) ** 2)
            core = np.exp(-0.5 * (radius / 2.2) ** 2)
            col = _lerp(col, gap, 0.55 * ring)
            col = _lerp(col, grain, 0.80 * core)
        return col

    # Vertical plank door / shutter leaf.  9 integer planks tile exactly.
    plank_px = n / WOOD_PLANKS
    # Crop mid-plank at the wrap edge (the tile is a crop of a plank field).
    up = (u + plank_px * 0.5) % n
    plank_index = np.floor(up / plank_px).astype(np.int64)
    local_x = up - plank_index * plank_px

    tone = _hash01(seed + 72, plank_index, 5)
    base = _lerp(plank, plank_alt, tone)
    base = base * (0.97 + 0.06 * _hash01(seed + 73, plank_index, 9))[..., None]

    # wavy grain lines running along the plank
    wav = _periodic_noise(rng, n, 40.0, 24.0)
    lines = np.sin(2.0 * np.pi * (local_x / 8.0) + 3.0 * wav)
    base = _lerp(base, grain, np.clip(-lines, 0.0, 1.0) ** 1.3 * 0.42)
    base = base * (1.0 + 0.020 * _periodic_noise(rng, n, 1.0, 12.0))[..., None]

    # 2 px dark gaps between planks, with a worn highlight on the arris
    in_gap = local_x < PLANK_GAP_PX
    col = np.where(in_gap[..., None], _lerp(gap, grain, 0.25), base)
    arris = (local_x >= PLANK_GAP_PX) & (local_x < PLANK_GAP_PX + 1.6)
    col = np.where(arris[..., None], _lerp(col, plank, 0.18), col)

    if "greyed" in detail or "split ends" in detail:
        # a few split plank ends: widen the gap briefly near the tile ends
        split_plank = _hash01(seed + 74, plank_index, 0) < 0.35
        split_v = (v < 0.06 * n) | (v > 0.94 * n)
        split = split_plank & split_v & (local_x < PLANK_GAP_PX + 2.0)
        col = np.where(split[..., None], _lerp(col, gap, 0.55), col)
    return col


def _paint_plaster(cell, n: int, seed: int, rng, detail: str) -> np.ndarray:
    """Fine stucco noise with patchy wear; no visible tiling structure."""
    p = cell["palette"]
    plaster, wear, speck = _rgb(p["plaster"]), _rgb(p["wear"]), _rgb(p["speck"])
    u, v = _uv(n)

    patch = _periodic_noise(rng, n, 48.0)
    wear_t = np.clip(0.5 + 0.45 * patch, 0.0, 1.0) * 0.50
    col = _lerp(plaster, wear, wear_t)

    stucco = _periodic_noise(rng, n, 1.1)
    col = col * (1.0 + 0.020 * stucco)[..., None]

    u_i = u.astype(np.int64)
    v_i = v.astype(np.int64)
    speck_mask = (_periodic_noise(rng, n, 0.7) > 2.45) & \
                 (_hash01(seed + 81, u_i, v_i) < 0.75)
    col = np.where(speck_mask[..., None], _lerp(col, speck, 0.50), col)

    if "soot streaks" in detail:
        streaks = _periodic_noise(rng, n, 2.0, 42.0)
        col = _lerp(col, _lerp(wear, speck, 0.45),
                    np.clip(0.45 * (streaks - 0.15), 0.0, 0.40))
    return col


_PAINTERS = {
    "brick": _paint_brick,
    "stone": _paint_stone,
    "iron": _paint_iron,
    "roof": _paint_roof,
    "glass": _paint_glass,
    "wood": _paint_wood,
    "plaster": _paint_plaster,
}


# ---------------------------------------------------------------------------
# tile finishing: bounded mean match + adaptive-palette quantisation
# ---------------------------------------------------------------------------
def _finish_tile(array: np.ndarray, target, colors: int):
    """Grade the painted cell towards its target mean, then quantise it.

    Returns (paletted PIL image, its RGB numpy array).  The loop measures the
    *quantised* result and re-nudges, so the shipped pixels -- not just the
    floating-point artwork -- hit the spec mean.
    """
    target = np.asarray(target, dtype=np.float64)
    arr = np.asarray(array, dtype=np.float64)
    pal = None
    rgb = None
    for _ in range(4):
        arr = np.clip(arr, 0.0, 255.0)
        image = Image.fromarray(np.round(arr).astype(np.uint8), "RGB")
        pal = image.quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                             dither=Image.Dither.NONE)
        rgb = np.asarray(pal.convert("RGB"), dtype=np.float64)
        delta = target - rgb.mean(axis=(0, 1))
        if float(np.abs(delta).max()) <= 1.0:
            break
        arr = np.clip(arr + np.clip(delta, -GRADE_LIMIT, GRADE_LIMIT), 0.0, 255.0)
    assert pal is not None and rgb is not None
    return pal, rgb


def _paint_cell(cell, n: int, px_per_m: float, seed: int,
                rng: np.random.Generator, colors: int):
    """Paint one cell, add periodic grain, grade it and quantise it."""
    kind = cell["kind"]
    try:
        painter = _PAINTERS[kind]
    except KeyError as exc:
        raise ValueError(f"unknown cell kind {kind!r} for {cell['id']!r}") from exc
    detail = str(cell.get("detail", "")).lower()
    arr = painter(cell, n, seed, rng, detail)
    # Shared periodic grain: keeps smooth cells from quantising into flat
    # plateaus, which would otherwise make the seam statistic noisy.
    arr = arr + FINE_GRAIN * _periodic_noise(rng, n, 0.6)[..., None]
    return _finish_tile(arr, cell["mean_rgb"], colors)


# ---------------------------------------------------------------------------
# spec loading / validation
# ---------------------------------------------------------------------------
def _load_config(spec: dict, spec_path: Path) -> dict:
    """Read the spec, derive the pixel constants and reject contradictions."""
    def need(key: str, obj: dict):
        if key not in obj:
            raise ValueError(f"spec missing required key {key!r}")
        return obj[key]

    atlas_px = int(need("atlas_px", spec))
    grid = need("grid", spec)
    cols = int(need("cols", grid))
    rows = int(need("rows", grid))
    cell_px = int(need("cell_px", grid))
    gutter_px = int(need("gutter_px", grid))
    content_px = int(need("content_px", grid))
    tile_m = float(need("tile_m", spec))
    px_per_m = float(need("px_per_m", spec))
    row_origin = str(need("row_origin", spec))
    color_space = str(need("color_space", spec))

    if row_origin != "top":
        raise ValueError("this generator assumes row_origin='top'")
    if color_space.lower() != "srgb":
        raise ValueError("this generator assumes color_space='srgb'")
    if gutter_px != 0:
        raise ValueError("this generator implements the no-gutter spec; "
                         f"grid.gutter_px is {gutter_px}, expected 0")
    if content_px != cell_px:
        raise ValueError("no-gutter spec requires grid.content_px == grid.cell_px")
    if atlas_px != cell_px * cols or atlas_px != cell_px * rows:
        raise ValueError(f"atlas_px {atlas_px} does not match "
                         f"{cell_px} px x {cols}x{rows} grid")
    expected_px_per_m = cell_px / tile_m
    if abs(px_per_m - expected_px_per_m) > 1e-6:
        raise ValueError(f"px_per_m {px_per_m} does not match "
                         f"cell_px/tile_m = {expected_px_per_m}")

    outputs = need("outputs", spec)
    for key in ("png", "tiles", "stats"):
        need(key, outputs)

    quantize = spec.get("quantize", {})
    colors = int(quantize.get("max_colors", 256))
    if not 2 <= colors <= 256:
        raise ValueError(f"quantize.max_colors {colors} is outside 2..256")

    cells = spec["cells"]
    if len(cells) != cols * rows:
        raise ValueError(f"spec has {len(cells)} cells, expected {cols * rows}")

    seen_ids: set[str] = set()
    seen_slots: set[tuple[int, int]] = set()
    for cell in cells:
        cell_id = str(need("id", cell))
        col = int(need("col", cell))
        row = int(need("row", cell))
        if cell_id in seen_ids:
            raise ValueError(f"duplicate cell id {cell_id!r}")
        seen_ids.add(cell_id)
        if not (0 <= col < cols and 0 <= row < rows):
            raise ValueError(f"cell {cell_id!r} col/row {col},{row} out of range")
        if (col, row) in seen_slots:
            raise ValueError(f"cell index collision at col {col}, row {row}")
        seen_slots.add((col, row))
        if "kind" not in cell or "palette" not in cell or "mean_rgb" not in cell:
            raise ValueError(f"cell {cell_id!r} is missing kind/palette/mean_rgb")
    expected_slots = {(c, r) for c in range(cols) for r in range(rows)}
    if seen_slots != expected_slots:
        missing = sorted(expected_slots - seen_slots)
        raise ValueError(f"spec does not cover every grid slot; missing {missing}")

    return {
        "spec_path": spec_path,
        "atlas_px": atlas_px,
        "cols": cols,
        "rows": rows,
        "cell_px": cell_px,
        "gutter_px": gutter_px,
        "content_px": content_px,
        "tile_m": tile_m,
        "px_per_m": px_per_m,
        "quant_colors": colors,
        "outputs": outputs,
        "cells": cells,
    }


# ---------------------------------------------------------------------------
# rendering / writing / measuring
# ---------------------------------------------------------------------------
def _render_all(cfg: dict) -> tuple[list[dict], bytes]:
    """Paint all cells and assemble the review montage; returns tiles + PNGs."""
    tiles: list[dict] = []
    for cell in cfg["cells"]:
        seed = _cell_seed(cell["id"])
        rng = np.random.default_rng(seed)
        pal, rgb = _paint_cell(cell, cfg["cell_px"], cfg["px_per_m"],
                               seed, rng, cfg["quant_colors"])
        buf = io.BytesIO()
        pal.save(buf, format="PNG", optimize=True)
        tiles.append({"cell": cell, "pal": pal, "rgb": rgb, "png": buf.getvalue()})

    atlas = np.zeros((cfg["atlas_px"], cfg["atlas_px"], 3), dtype=np.uint8)
    for tile in tiles:
        cell = tile["cell"]
        y = cell["row"] * cfg["cell_px"]
        x = cell["col"] * cfg["cell_px"]
        atlas[y:y + cfg["cell_px"], x:x + cfg["cell_px"]] = tile["rgb"]

    buf = io.BytesIO()
    Image.fromarray(atlas, "RGB").save(buf, format="PNG", optimize=True)
    return tiles, buf.getvalue()


def _seam_ratio(rgb: np.ndarray, axis: int) -> float:
    """Seam-vs-interior difference ratio (wrap edge compared to interior steps)."""
    a = rgb.astype(np.int16)
    if axis == 1:  # U: last column wraps to the first
        seam = np.abs(a[:, -1, :] - a[:, 0, :]).mean()
        interior = np.abs(np.diff(a, axis=1)).mean()
    else:  # V: last row wraps to the first
        seam = np.abs(a[-1, :, :] - a[0, :, :]).mean()
        interior = np.abs(np.diff(a, axis=0)).mean()
    return float(seam / max(interior, 1e-6))


def _measure(tiles: list[dict], montage_png: bytes, cfg: dict,
             deterministic_ok: bool) -> tuple[dict, list[str]]:
    """Build the stats document and collect every validation failure."""
    failures: list[str] = []
    cells_out: list[dict] = []
    means_ok = True
    seams_ok = True
    sizes_ok = True
    tile_bytes_total = 0

    n = cfg["cell_px"]
    for tile in tiles:
        cell = tile["cell"]
        rgb = tile["rgb"]
        mean = rgb.mean(axis=(0, 1))
        target = np.asarray(cell["mean_rgb"], dtype=np.float64)
        delta = mean - target
        seam_u = _seam_ratio(rgb, axis=1)
        seam_v = _seam_ratio(rgb, axis=0)
        mean_ok = float(np.abs(delta).max()) <= MEAN_TOLERANCE
        seam_ok = seam_u < SEAM_RATIO_MAX and seam_v < SEAM_RATIO_MAX
        size_ok = (rgb.shape == (n, n, 3) and tile["pal"].size == (n, n)
                   and tile["pal"].mode == "P"
                   and "transparency" not in tile["pal"].info)
        means_ok &= mean_ok
        seams_ok &= seam_ok
        sizes_ok &= size_ok
        tile_bytes_total += len(tile["png"])

        ok = mean_ok and seam_ok and size_ok
        if not mean_ok:
            failures.append(
                f"{cell['id']}: mean {np.round(mean, 1).tolist()} is "
                f"{float(np.abs(delta).max()):.1f} from target "
                f"{cell['mean_rgb']} (limit {MEAN_TOLERANCE})")
        if not seam_ok:
            failures.append(
                f"{cell['id']}: seam ratio u={seam_u:.2f} v={seam_v:.2f} "
                f"(limit {SEAM_RATIO_MAX})")
        if not size_ok:
            failures.append(f"{cell['id']}: tile is not a {n}x{n} palette PNG")

        rel_tiles = Path(cfg["outputs"]["tiles"])
        cells_out.append({
            "id": cell["id"],
            "col": int(cell["col"]),
            "row": int(cell["row"]),
            "material": cell.get("material"),
            "primary": bool(cell.get("primary", False)),
            "reserved": bool(cell.get("reserved", False)),
            "path": str((rel_tiles / f"{cell['id']}.png").as_posix()),
            "bytes": len(tile["png"]),
            "sha256": hashlib.sha256(tile["png"]).hexdigest(),
            "mean_rgb": [round(float(x), 2) for x in mean],
            "target_rgb": [float(x) for x in target],
            "delta": [round(float(x), 2) for x in delta],
            "seam_u": round(seam_u, 3),
            "seam_v": round(seam_v, 3),
            "ok": ok,
        })

    atlas_ok = cfg["atlas_px"] == n * cfg["cols"] == n * cfg["rows"]
    if not atlas_ok:
        failures.append(f"montage is not {cfg['atlas_px']}x{cfg['atlas_px']}")
    if not deterministic_ok:
        failures.append("determinism check failed: a second render differs")

    checks = {
        "spec_consistent": True,
        "cells_complete": True,
        "no_index_collisions": True,
        "means_within_tolerance": bool(means_ok),
        "seams_within_limit": bool(seams_ok),
        "tile_png_sizes": bool(sizes_ok),
        "montage_size": bool(atlas_ok),
        "deterministic": bool(deterministic_ok),
    }
    all_ok = all(checks.values())
    stats = {
        "spec": Path(cfg["spec_path"]).as_posix(),
        "atlas_px": cfg["atlas_px"],
        "grid": {
            "cols": cfg["cols"],
            "rows": cfg["rows"],
            "cell_px": cfg["cell_px"],
            "gutter_px": cfg["gutter_px"],
            "content_px": cfg["content_px"],
        },
        "row_origin": "top",
        "tile_m": cfg["tile_m"],
        "px_per_m": cfg["px_per_m"],
        "quantize": {"mode": "adaptive-palette-png",
                     "max_colors": cfg["quant_colors"]},
        "png": str(Path(cfg["outputs"]["png"]).as_posix()),
        "tiles": str(Path(cfg["outputs"]["tiles"]).as_posix()),
        "sha256": hashlib.sha256(montage_png).hexdigest(),
        "bytes": len(montage_png),
        "tile_bytes_total": tile_bytes_total,
        "deterministic_check": bool(deterministic_ok),
        "all_ok": all_ok,
        "checks": checks,
        "cells": cells_out,
    }
    return stats, failures


# ---------------------------------------------------------------------------
# reporting
# ---------------------------------------------------------------------------
def _print_table(stats: dict) -> None:
    print(f"{'cell':<22} {'c,r':<5} {'measured rgb':<20} {'target rgb':<18} "
          f"{'dmax':>5} {'seamU':>6} {'seamV':>6} {'KiB':>7} {'ok':>3}")
    for cell in stats["cells"]:
        mean = ", ".join(f"{x:5.1f}" for x in cell["mean_rgb"])
        target = ", ".join(f"{x:3.0f}" for x in cell["target_rgb"])
        dmax = max(abs(a - b) for a, b in zip(cell["mean_rgb"], cell["target_rgb"]))
        print(f"{cell['id']:<22} {cell['col']},{cell['row']:<3} {mean:<20} "
              f"{target:<18} {dmax:5.1f} {cell['seam_u']:6.2f} {cell['seam_v']:6.2f} "
              f"{cell['bytes'] / 1024:7.1f} {'yes' if cell['ok'] else 'NO':>3}")


def _display(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


# ---------------------------------------------------------------------------
# cli
# ---------------------------------------------------------------------------
def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--spec", type=Path,
        default=repo_root / "docs/design/textures/iron_harbor/"
                             "iron_harbor_trim_sheet_2048.spec.json",
        help="Trim-sheet spec JSON (default: the repo spec).")
    parser.add_argument(
        "--out-root", type=Path, default=repo_root,
        help="Repository root; the spec's repo-relative output paths resolve "
             "under it (default: repo root).")
    parser.add_argument(
        "--stats", type=Path, default=None,
        help="Override the stats JSON path (default: the spec's "
             "outputs.stats under --out-root).")
    args = parser.parse_args()

    spec_path: Path = args.spec
    if not spec_path.is_file():
        print(f"error: spec not found: {spec_path}", file=sys.stderr)
        return 1
    try:
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
        cfg = _load_config(spec, spec_path)
    except (ValueError, KeyError, TypeError) as exc:
        print(f"error: unusable spec {spec_path}: {exc}", file=sys.stderr)
        return 1

    root: Path = args.out_root
    png_path = root / cfg["outputs"]["png"]
    tiles_dir = root / cfg["outputs"]["tiles"]
    stats_path = args.stats if args.stats is not None else root / cfg["outputs"]["stats"]

    # First render: write the files.
    tiles, montage_png = _render_all(cfg)
    png_path.parent.mkdir(parents=True, exist_ok=True)
    tiles_dir.mkdir(parents=True, exist_ok=True)
    for tile in tiles:
        (tiles_dir / f"{tile['cell']['id']}.png").write_bytes(tile["png"])
    png_path.write_bytes(montage_png)

    # Second render (fresh RNGs): byte-identical output is a hard requirement.
    tiles_b, montage_b = _render_all(cfg)
    deterministic_ok = (
        montage_b == montage_png
        and [t["png"] for t in tiles_b] == [t["png"] for t in tiles]
    )

    stats, failures = _measure(tiles, montage_png, cfg, deterministic_ok)
    stats_path.parent.mkdir(parents=True, exist_ok=True)
    stats_path.write_text(json.dumps(stats, indent=2) + "\n", encoding="utf-8")

    _print_table(stats)
    print()
    print(f"tiles   {_display(tiles_dir, root)}/  ({len(tiles)} files, "
          f"{stats['tile_bytes_total'] / 1024:.1f} KiB total)")
    print(f"atlas   {_display(png_path, root)}  "
          f"{cfg['atlas_px']}x{cfg['atlas_px']}  {len(montage_png) / 1024:.1f} KiB  "
          f"sha256 {stats['sha256']}")
    print(f"stats   {_display(stats_path, root)}  "
          f"deterministic={deterministic_ok}  all_ok={stats['all_ok']}")

    if failures:
        print("\nFAILED checks:", file=sys.stderr)
        for message in failures:
            print(f"  - {message}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
