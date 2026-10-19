#!/usr/bin/env python3
"""Generate the shipyard refit textures for Steam Navigator.

Outputs (relative to --out-root, which defaults to the repository root):

    assets/ui/shipyard/ship_section.png         1792 x 1008  (16:9)
        Steampunk ironclad longitudinal section / broadside cutaway used as the
        full background of the shipyard refit stage.  Purely hand-drawn with
        Pillow primitives (no text, no baked UI frames).

    assets/ui/shipyard/ship_thumb_ironclad.png  640 x 360
        Card thumbnail derived from
        docs/design/screenshots/ironclad_broadside.png: cropped, background
        replaced with the UI palette gradient + vignette, no text, no border.

Run:
    python tools/art/gen_shipyard_textures.py
    python tools/art/gen_shipyard_textures.py --out-root D:\\somewhere
    python tools/art/gen_shipyard_textures.py --thumb-only

The generator is deterministic: the same Pillow/numpy versions produce the same
pixels on every run.  All geometry is expressed as fractions of the canvas in
the constants block below so the composition is easy to tweak.
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# ---------------------------------------------------------------------------
# canvas
# ---------------------------------------------------------------------------
W, H = 1792, 1008
SS = 2  # supersampling factor for the section artwork

# ---------------------------------------------------------------------------
# palette -- mirrors assets/ui/tokens.json and SNShipView
# ---------------------------------------------------------------------------
BG_TOP = (7, 26, 29)          # #071a1d  abyss_950
BG_BOT = (14, 42, 47)         # #0e2a2f  deep teal-navy
BRASS = (225, 196, 135)       # #e1c487  brass_300
BRASS_DIM = (197, 154, 84)    # #c59a54  brass_500
TEAL = (118, 170, 167)        # #76aaa7
PAPER = (215, 201, 167)       # #d7c9a7  paper_200
RUST = (159, 77, 62)          # #9f4d3e  rust_500
STEEL_DARK = (34, 50, 55)     # #223237
STEEL_MID = (48, 71, 75)      # #30474b
STEEL_LIGHT = (60, 88, 92)    # #3c585c
COPPER = (92, 57, 50)         # #5c3932  copper sheathing (rust pulled dark)
COPPER_DARK = (66, 41, 36)
VOID = (16, 28, 31)           # openings / firebox
WOOD = (74, 63, 51)           # cargo crates, chart table
WOOD_LIGHT = (99, 85, 69)
GLOW = (214, 138, 86)         # firebox ember

# ---------------------------------------------------------------------------
# composition anchors (fractions of the canvas)
# ---------------------------------------------------------------------------
DECK_Y = 0.400
KEEL_Y = 0.782
WATER_Y = 0.675
FLOOR_Y = 0.660
INNER_TOP = 0.416
HULL_L, HULL_R = 0.072, 0.932

# Compartment anchors -- also reported to the UI team; keep them in sync with
# the slot-chip anchors in framework/ui/components/sn_ship_view.gd.
ANCHORS = {
    "paddle_wheel": (0.108, 0.590),
    "boiler": (0.345, 0.552),
    "cargo": (0.545, 0.578),
    "safety": (0.674, 0.330),
    "navigation": (0.756, 0.340),
    "cabin": (0.854, 0.340),
    "funnel": (0.356, 0.300),
    "mast_flag": (0.704, 0.150),
}

BULKHEADS = [0.213, 0.272, 0.423, 0.455, 0.545, 0.645, 0.715, 0.800, 0.900]

_HULL_OUTLINE = [
    (0.072, 0.400), (0.932, 0.400),
    # bow: near-vertical stem with a slight ram flare at the waterline
    (0.936, 0.455), (0.934, 0.520), (0.930, 0.585), (0.925, 0.640),
    # short underwater bow curve
    (0.910, 0.685), (0.885, 0.720), (0.850, 0.745), (0.805, 0.762),
    (0.760, 0.774), (0.740, 0.778),
    # long flat keel
    (0.680, 0.781), (0.560, 0.782), (0.400, 0.782), (0.260, 0.782), (0.160, 0.781),
    # stern run and counter
    (0.128, 0.770), (0.108, 0.748), (0.096, 0.715),
    (0.090, 0.660), (0.083, 0.560),
]

_HULL_INNER = [
    (0.090, 0.416), (0.918, 0.416),
    (0.922, 0.470), (0.920, 0.525), (0.916, 0.585), (0.911, 0.635),
    (0.897, 0.675), (0.873, 0.708), (0.840, 0.732), (0.798, 0.748),
    (0.760, 0.760), (0.740, 0.764),
    (0.680, 0.767), (0.560, 0.768), (0.400, 0.768), (0.262, 0.768), (0.168, 0.767),
    (0.138, 0.757), (0.119, 0.737), (0.107, 0.707),
    (0.100, 0.658), (0.093, 0.560),
]


# ---------------------------------------------------------------------------
# colour helpers
# ---------------------------------------------------------------------------
def mix(a, b, t: float):
    """Linear blend a -> b; returns an integer RGB tuple."""
    return (
        int(round(a[0] + (b[0] - a[0]) * t)),
        int(round(a[1] + (b[1] - a[1]) * t)),
        int(round(a[2] + (b[2] - a[2]) * t)),
    )


def bg_at(fy: float):
    """Background gradient colour at a vertical fraction (must match build_background)."""
    t = min(1.0, max(0.0, fy)) ** 1.15
    return mix(BG_TOP, BG_BOT, t)


def clip_above(points, y_cut: float):
    """Sutherland-Hodgman clip: keep the part of a polygon at y <= y_cut."""
    out = []
    n = len(points)
    for i in range(n):
        p = points[i]
        q = points[(i + 1) % n]
        p_in, q_in = p[1] <= y_cut, q[1] <= y_cut
        if p_in:
            out.append(p)
        if p_in != q_in:
            t = (y_cut - p[1]) / (q[1] - p[1])
            out.append((p[0] + t * (q[0] - p[0]), y_cut))
    return out


def clip_below(points, y_cut: float):
    """Keep the part of a polygon at y >= y_cut."""
    return clip_above(points, -y_cut)


def inner_bottom_y(fx: float) -> float:
    pts = sorted(_HULL_INNER[2:-2], key=lambda p: p[0])
    if fx <= pts[0][0]:
        return pts[0][1]
    if fx >= pts[-1][0]:
        return pts[-1][1]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if x0 <= fx <= x1:
            if abs(x1 - x0) < 1e-9:
                return max(y0, y1)
            t = (fx - x0) / (x1 - x0)
            return y0 + (y1 - y0) * t
    return pts[-1][1]


# ---------------------------------------------------------------------------
# section artwork
# ---------------------------------------------------------------------------
class SectionArt:
    """Draws the 2x RGBA cutaway layer; coordinates are canvas fractions."""

    def __init__(self, scale: int = SS):
        self.scale = scale
        self.w = W * scale
        self.h = H * scale
        self.img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    # -- primitive helpers --------------------------------------------------
    def _pt(self, p):
        return (p[0] * self.w, p[1] * self.h)

    def _pts(self, pts):
        return [self._pt(p) for p in pts]

    def _width(self, width: float) -> int:
        return max(1, int(round(width * self.scale)))

    def line(self, a, b, color, width: float = 1.0):
        self.d.line([self._pt(a), self._pt(b)], fill=color, width=self._width(width))

    def polyline(self, pts, color, width: float = 1.0, closed: bool = False):
        p = self._pts(pts)
        if closed:
            p = p + [p[0]]
        self.d.line(p, fill=color, width=self._width(width), joint="curve")

    def polygon(self, pts, fill=None, outline=None, width: float = 1.0):
        xy = self._pts(pts)
        if len(xy) < 3:
            return
        if fill is not None:
            self.d.polygon(xy, fill=fill)
        if outline is not None:
            self.polyline(pts, outline, width, closed=True)

    def rect(self, x0, y0, x1, y1, fill=None, outline=None, width: float = 1.0):
        xy = [self._pt((x0, y0)), self._pt((x1, y1))]
        if fill is not None:
            self.d.rectangle(xy, fill=fill)
        if outline is not None:
            self.d.rectangle(xy, outline=outline, width=self._width(width))

    def rrect(self, x0, y0, x1, y1, radius: float, fill=None, outline=None,
              width: float = 1.0):
        xy = [self._pt((x0, y0)), self._pt((x1, y1))]
        r = max(1.0, radius * self.h)
        if fill is not None:
            self.d.rounded_rectangle(xy, radius=r, fill=fill)
        if outline is not None:
            self.d.rounded_rectangle(xy, radius=r, outline=outline,
                                    width=self._width(width))

    def ellipse(self, cx, cy, rx, ry, fill=None, outline=None, width: float = 1.0):
        x0 = (cx - rx) * self.w
        y0 = (cy - ry) * self.h
        x1 = (cx + rx) * self.w
        y1 = (cy + ry) * self.h
        box = [x0, y0, x1, y1]
        if fill is not None:
            self.d.ellipse(box, fill=fill)
        if outline is not None:
            self.d.arc(box, 0, 360, fill=outline, width=self._width(width))

    def circle(self, cx, cy, r: float, fill=None, outline=None, width: float = 1.0):
        # r is a fraction of the canvas height, so circles stay circular.
        self.ellipse(cx, cy, r * H / W, r, fill=fill, outline=outline, width=width)

    def arc(self, cx, cy, r: float, start: float, end: float, color,
            width: float = 1.0):
        x0 = (cx - r * H / W) * self.w
        y0 = (cy - r) * self.h
        x1 = (cx + r * H / W) * self.w
        y1 = (cy + r) * self.h
        self.d.arc([x0, y0, x1, y1], start, end, fill=color, width=self._width(width))

    def dot(self, cx, cy, r_px: float, color):
        r = r_px / W  # convert a final-pixel radius into an x fraction
        self.ellipse(cx, cy, r, r * W / H, fill=color)

    def grad_line_bg(self, a, b, color, alpha: float, width: float = 1.0,
                     segments: int = 14):
        """A line drawn over the background, pre-blended per segment."""
        for i in range(segments):
            t0 = i / segments
            t1 = (i + 1) / segments
            p0 = (a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0)
            p1 = (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)
            c = mix(bg_at((p0[1] + p1[1]) * 0.5), color, alpha)
            self.line(p0, p1, c, width)

    # -- hull ---------------------------------------------------------------
    def hull_points(self):
        return list(_HULL_OUTLINE)

    def inner_points(self):
        return list(_HULL_INNER)

    def add_hull_reflection(self):
        """Soft dark reflection of the hull under the waterline."""
        pts = [(x, min(KEEL_Y + 0.055, y + 0.045)) for x, y in self.inner_points()]
        layer = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(self._pts(pts), fill=(0, 0, 0, 96))
        layer = layer.filter(ImageFilter.GaussianBlur(9 * self.scale))
        self.img = Image.alpha_composite(self.img, layer)
        self.d = ImageDraw.Draw(self.img)

    def draw_hull(self):
        self.add_hull_reflection()

        outer = self.hull_points()
        inner = self.inner_points()

        # outer plating: copper below the waterline, steel above
        self.polygon(outer, fill=COPPER)
        above = clip_above(outer, WATER_Y)
        if len(above) >= 3:
            self.polygon(above, fill=STEEL_DARK)

        # copper strakes (drawn before the interior so they stay on the shell)
        for fy in (0.692, 0.706, 0.721, 0.736, 0.751):
            pts = clip_below(outer, fy)
            if len(pts) >= 3:
                self.polyline(pts, mix(COPPER, COPPER_DARK, 0.55), 1.0, closed=False)
        # hull plate seams on the visible shell
        for fx in (0.120, 0.166, 0.212, 0.258, 0.304, 0.350, 0.396, 0.442, 0.488,
                   0.534, 0.580, 0.626, 0.672, 0.718, 0.764, 0.810, 0.856):
            self.line((fx, DECK_Y + 0.012), (fx, self._outer_bottom_y(fx) - 0.004),
                      mix(STEEL_DARK, TEAL, 0.10), 0.8)
        # keel band (thick dark copper arc under the outline)
        keel_path = outer[5:] + [outer[0]]
        self.polyline(keel_path, COPPER_DARK, 6.0, closed=False)

        # interior of the cut
        self.polygon(inner, fill=STEEL_MID)
        below_floor = clip_below(inner, FLOOR_Y)
        if len(below_floor) >= 3:
            self.polygon(below_floor, fill=mix(STEEL_DARK, VOID, 0.35))
        # double-bottom plating hint
        deep = clip_below(inner, 0.735)
        if len(deep) >= 3:
            self.polygon(deep, fill=mix(STEEL_DARK, VOID, 0.55))

        # waterline across the section
        self.line((0.090, WATER_Y), (0.902, WATER_Y), mix(STEEL_MID, TEAL, 0.58), 1.7)
        self.line((0.090, WATER_Y + 0.006), (0.902, WATER_Y + 0.006),
                  mix(COPPER, TEAL, 0.30), 1.0)

        # inner cut edge + hull outline
        self.polyline(inner, BRASS_DIM, 1.7, closed=True)
        self.polyline(outer, BRASS, 2.5, closed=True)

        # deck edge (shell cap)
        self.line((HULL_L, DECK_Y), (HULL_R, DECK_Y), BRASS, 3.0)
        self.line((HULL_L, DECK_Y - 0.004), (HULL_R, DECK_Y - 0.004),
                  mix(BRASS, PAPER, 0.4), 1.1)

    def _outer_bottom_y(self, fx: float) -> float:
        pts = sorted(_HULL_OUTLINE[5:-2], key=lambda p: p[0])
        if fx <= pts[0][0]:
            return pts[0][1]
        if fx >= pts[-1][0]:
            return pts[-1][1]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            if x0 <= fx <= x1:
                if abs(x1 - x0) < 1e-9:
                    return max(y0, y1)
                t = (fx - x0) / (x1 - x0)
                return y0 + (y1 - y0) * t
        return pts[-1][1]


    def draw_interior_frames(self):
        # faint vertical frames (ribs) between deck and keel
        rib_col = mix(STEEL_MID, TEAL, 0.13)
        fx = 0.104
        while fx < 0.918:
            y1 = inner_bottom_y(fx) - 0.008
            if y1 > INNER_TOP + 0.02:
                self.line((fx, INNER_TOP + 0.004), (fx, y1), rib_col, 0.9)
            fx += 0.0225
        # floor / deck of the hold spaces
        self.line((0.102, FLOOR_Y), (0.912, FLOOR_Y), mix(STEEL_MID, TEAL, 0.42), 1.4)
        # bilge frames below the floor
        bilge_col = mix(STEEL_DARK, TEAL, 0.10)
        fx = 0.12
        while fx < 0.90:
            y1 = inner_bottom_y(fx) - 0.006
            if y1 > FLOOR_Y + 0.012:
                self.line((fx, FLOOR_Y + 0.006), (fx, y1), bilge_col, 0.8)
            fx += 0.032
        # stringer line
        self.line((0.108, 0.700), (0.906, 0.700), mix(STEEL_DARK, TEAL, 0.20), 0.9)

    def draw_bulkheads(self):
        col = mix(STEEL_MID, TEAL, 0.38)
        cap = mix(STEEL_MID, BRASS_DIM, 0.48)
        for fx in BULKHEADS:
            y1 = inner_bottom_y(fx) - 0.007
            if y1 <= INNER_TOP + 0.02:
                continue
            self.line((fx, INNER_TOP + 0.002), (fx, y1), col, 1.35)
            # small gussets at deck and floor
            self.line((fx, INNER_TOP + 0.002), (fx + 0.006, INNER_TOP + 0.002),
                      cap, 1.0)
            self.line((fx - 0.006, INNER_TOP + 0.002), (fx, INNER_TOP + 0.002),
                      cap, 1.0)
            if y1 > FLOOR_Y:
                self.line((fx - 0.005, FLOOR_Y - 0.012), (fx, FLOOR_Y - 0.012),
                          cap, 1.0)
            # rivets along the bulkhead
            fy = INNER_TOP + 0.026
            while fy < min(y1, FLOOR_Y) - 0.01:
                self.dot(fx, fy, 1.15, mix(STEEL_MID, TEAL, 0.55))
                fy += 0.028

    # -- stern machinery ----------------------------------------------------
    def draw_paddle_wheel(self):
        cx, cy = ANCHORS["paddle_wheel"]
        r = 0.090
        shaft = mix(STEEL_DARK, BRASS_DIM, 0.55)

        # shaft running forward into the engine room / boiler compartment
        self.line((cx + 0.02, cy), (0.292, cy), shaft, 3.0)
        for bx in (0.150, 0.184, 0.238, 0.262):
            self.rect(bx - 0.004, cy - 0.012, bx + 0.004, cy + 0.012,
                      fill=mix(STEEL_DARK, STEEL_MID, 0.55), outline=BRASS_DIM, width=1.0)

        # wheel: rim, spokes and paddle boards
        self.circle(cx, cy, r, fill=None, outline=BRASS, width=2.4)
        self.circle(cx, cy, r - 0.006, fill=None,
                    outline=mix(STEEL_MID, TEAL, 0.38), width=1.0)
        spokes = 12
        for i in range(spokes):
            a = 2 * math.pi * i / spokes
            p0 = (cx + math.cos(a) * 0.010 * H / W, cy + math.sin(a) * 0.010)
            p1 = (cx + math.cos(a) * (r - 0.006) * H / W, cy + math.sin(a) * (r - 0.006))
            self.line(p0, p1, mix(STEEL_MID, TEAL, 0.52), 1.05)
        for i in range(spokes):
            a = 2 * math.pi * i / spokes + math.pi / spokes
            ca, sa = math.cos(a), math.sin(a)
            rad = (r - 0.003) * H
            half_w, half_h = 6.5, 13.5
            pts = []
            for dx, dy in ((-half_w, -half_h), (half_w, -half_h),
                           (half_w, half_h), (-half_w, half_h)):
                gx = cx * W + ca * (rad + dy) - sa * dx
                gy = cy * H + sa * (rad + dy) + ca * dx
                pts.append((gx / W, gy / H))
            self.polygon(pts, fill=STEEL_DARK, outline=BRASS_DIM, width=0.9)
        self.circle(cx, cy, 0.013, fill=mix(STEEL_DARK, STEEL_MID, 0.5),
                    outline=BRASS, width=1.7)
        self.circle(cx, cy, 0.004, fill=BRASS)

        # thin paddle-box guard over the top of the wheel
        self.arc(cx, cy, r + 0.016, 186, 354, mix(STEEL_MID, BRASS_DIM, 0.50), 1.8)
        self.arc(cx, cy, r + 0.020, 186, 354, mix(STEEL_DARK, BRASS_DIM, 0.30), 0.8)
        for ang in (210, 270, 330):
            a = math.radians(ang)
            self.line((cx + math.cos(a) * (r + 0.004) * H / W, cy + math.sin(a) * (r + 0.004)),
                      (cx + math.cos(a) * (r + 0.020) * H / W, cy + math.sin(a) * (r + 0.020)),
                      mix(STEEL_MID, BRASS_DIM, 0.42), 1.2)
        # guard supports down to the hull
        for ang, tx, ty in ((186, 0.086, 0.648), (354, 0.166, 0.640)):
            a = math.radians(ang)
            self.line((cx + math.cos(a) * (r + 0.018) * H / W, cy + math.sin(a) * (r + 0.018)),
                      (tx, ty), mix(STEEL_MID, BRASS_DIM, 0.35), 1.3)

        # stern stores: crates + lantern in the compartment forward of the wheel
        self.draw_crate(0.224, 0.604, 0.262, 0.652, 0.25)
        lx, ly = 0.213, 0.470
        self.line((lx, 0.430), (lx, ly - 0.010), mix(STEEL_MID, BRASS_DIM, 0.4), 1.0)
        self.polygon([(lx - 0.008, ly - 0.010), (lx + 0.008, ly - 0.010),
                      (lx + 0.005, ly + 0.004), (lx - 0.005, ly + 0.004)],
                     fill=mix(STEEL_DARK, BRASS_DIM, 0.5), outline=BRASS_DIM, width=0.9)
        self.circle(lx, ly, 0.006, fill=mix(PAPER, GLOW, 0.30), outline=None)

    # -- boiler room --------------------------------------------------------
    def draw_boiler_room(self):
        drum = mix(STEEL_MID, STEEL_LIGHT, 0.55)
        outline = mix(STEEL_MID, BRASS_DIM, 0.75)
        brass = BRASS_DIM

        # boiler drum (rounded horizontal cylinder)
        x0, x1 = 0.292, 0.400
        y0, y1 = 0.512, 0.606
        self.rrect(x0, y0, x1, y1, (y1 - y0) / 2, fill=drum, outline=outline, width=1.7)
        # end caps
        for ex in (x0, x1):
            self.ellipse(ex, (y0 + y1) / 2, 0.0075, (y1 - y0) / 2 - 0.001,
                         fill=mix(STEEL_DARK, STEEL_MID, 0.6), outline=outline, width=1.4)
            for k in range(7):
                a = 2 * math.pi * k / 7
                self.dot(ex + math.cos(a) * 0.0045 * H / W,
                         (y0 + y1) / 2 + math.sin(a) * 0.032, 1.0, brass)
        # riveted bands
        for bx in (0.322, 0.347, 0.372):
            self.line((bx, y0 + 0.008), (bx, y1 - 0.008), brass, 1.9)
            for k in range(3):
                self.dot(bx, y0 + 0.022 + k * 0.026, 1.0, mix(drum, PAPER, 0.25))

        # steam dome
        self.rrect(0.330, 0.492, 0.362, 0.516, 0.010, fill=mix(STEEL_MID, STEEL_LIGHT, 0.4),
                   outline=outline, width=1.4)
        self.line((0.346, 0.492), (0.346, 0.400), mix(STEEL_MID, BRASS_DIM, 0.65), 3.0)
        self.circle(0.346, 0.456, 0.012, fill=None, outline=brass, width=1.6)
        self.circle(0.346, 0.456, 0.004, fill=mix(drum, BRASS, 0.4))
        for i in range(3):
            a = math.radians(90 + 120 * i)
            self.line((0.346, 0.456),
                      (0.346 + math.cos(a) * 0.012 * H / W, 0.456 + math.sin(a) * 0.012),
                      brass, 1.0)
        # safety valve
        self.rect(0.340, 0.482, 0.352, 0.493, fill=mix(STEEL_DARK, STEEL_MID, 0.5),
                  outline=brass, width=1.0)
        self.dot(0.346, 0.482, 1.3, brass)

        # firebox with a faint ember glow
        self.rect(0.305, 0.606, 0.385, 0.651, fill=VOID, outline=outline, width=1.4)
        for i, gy in enumerate((0.620, 0.630, 0.640)):
            self.line((0.313, gy), (0.377, gy), mix(GLOW, VOID, 0.45 - i * 0.08), 1.5)
        self.line((0.305, 0.615), (0.385, 0.615), mix(STEEL_DARK, BRASS_DIM, 0.35), 1.0)
        # ash pan handle
        self.line((0.336, 0.645), (0.354, 0.645), brass, 1.3)
        self.circle(0.345, 0.652, 0.004, fill=brass)

        # coal bunker between the boiler and the cargo bulkhead
        self.rect(0.404, 0.518, 0.420, 0.652, fill=mix(STEEL_DARK, VOID, 0.25),
                  outline=mix(STEEL_DARK, BRASS_DIM, 0.45), width=1.1)
        self.line((0.404, 0.528), (0.420, 0.528), mix(STEEL_DARK, BRASS_DIM, 0.4), 1.0)
        coal = mix(VOID, STEEL_DARK, 0.40)
        for cx, cy, rx, ry in ((0.408, 0.542, 0.005, 0.009), (0.416, 0.556, 0.004, 0.008),
                               (0.409, 0.574, 0.005, 0.010), (0.417, 0.590, 0.004, 0.009),
                               (0.409, 0.608, 0.005, 0.010), (0.417, 0.626, 0.004, 0.009),
                               (0.410, 0.642, 0.005, 0.008)):
            self.ellipse(cx, cy, rx, ry, fill=coal, outline=None)
            self.dot(cx - rx * 0.35, cy - ry * 0.35, 0.9, mix(coal, BRASS_DIM, 0.30))

        # feed pipes / flanges
        pipe = mix(STEEL_MID, BRASS_DIM, 0.55)
        self.line((0.400, 0.560), (0.423, 0.560), pipe, 2.2)
        self.line((0.423, 0.560), (0.423, 0.470), pipe, 2.2)
        self.rect(0.418, 0.548, 0.428, 0.572, fill=mix(STEEL_DARK, STEEL_MID, 0.4),
                  outline=brass, width=1.0)
        self.line((0.292, 0.622), (0.272, 0.622), pipe, 2.0)
        self.rect(0.286, 0.612, 0.298, 0.632, fill=mix(STEEL_DARK, STEEL_MID, 0.4),
                  outline=brass, width=1.0)

        # wall pipe on the aft bulkhead
        self.line((0.274, 0.462), (0.292, 0.462), pipe, 1.8)
        self.line((0.274, 0.462), (0.274, 0.645), mix(STEEL_MID, BRASS_DIM, 0.45), 1.5)
        for fy in (0.495, 0.560, 0.625):
            self.line((0.270, fy), (0.278, fy), brass, 1.2)

        # pressure gauge on the aft bulkhead
        gx, gy = 0.406, 0.455
        self.circle(gx, gy, 0.016, fill=mix(STEEL_DARK, VOID, 0.4), outline=brass, width=1.6)
        self.circle(gx, gy, 0.012, fill=mix(PAPER, STEEL_DARK, 0.28), outline=None)
        for i in range(7):
            a = math.radians(210 + i * 20)
            self.line((gx + math.cos(a) * 0.009 * H / W, gy + math.sin(a) * 0.009),
                      (gx + math.cos(a) * 0.011 * H / W, gy + math.sin(a) * 0.011),
                      mix(STEEL_DARK, BRASS_DIM, 0.5), 1.0)
        self.line((gx, gy), (gx + 0.007 * H / W * 0.9, gy - 0.006), mix(STEEL_DARK, RUST, 0.5), 1.1)
        self.dot(gx, gy, 1.2, BRASS_DIM)

        # ladder up to the deck
        self.line((0.410, 0.655), (0.410, 0.404), mix(STEEL_MID, BRASS_DIM, 0.4), 1.2)
        self.line((0.418, 0.655), (0.418, 0.404), mix(STEEL_MID, BRASS_DIM, 0.4), 1.2)
        for k in range(8):
            fy = 0.430 + k * 0.029
            self.line((0.410, fy), (0.418, fy), mix(STEEL_MID, BRASS_DIM, 0.5), 1.0)

        # boiler-room floor rivets / tools
        for fx in (0.284, 0.300, 0.390, 0.414):
            self.dot(fx, FLOOR_Y - 0.008, 1.2, mix(STEEL_MID, BRASS_DIM, 0.35))

    # -- cargo --------------------------------------------------------------
    def draw_crate(self, x0, y0, x1, y1, tone: float = 0.0):
        fill = mix(WOOD, WOOD_LIGHT, tone)
        edge = mix(WOOD, BRASS_DIM, 0.35)
        self.rect(x0, y0, x1, y1, fill=fill, outline=edge, width=1.3)
        # diagonal braces
        self.line((x0, y0), (x1, y1), mix(fill, WOOD_LIGHT, 0.55), 1.0)
        self.line((x0, y1), (x1, y0), mix(fill, WOOD_LIGHT, 0.55), 1.0)
        # horizontal straps
        for fy in (y0 + (y1 - y0) * 0.18, y1 - (y1 - y0) * 0.18):
            self.line((x0, fy), (x1, fy), mix(fill, BRASS_DIM, 0.3), 0.9)
        # corner plates + nails
        for cx, cy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            self.dot(cx, cy, 0.9, mix(fill, BRASS, 0.4))
        self.dot((x0 + x1) / 2, (y0 + y1) / 2, 1.0, mix(fill, BRASS_DIM, 0.3))

    def draw_barrel(self, cx, cy, rx, ry, fill):
        self.ellipse(cx, cy, rx, ry, fill=fill, outline=mix(fill, BRASS_DIM, 0.4), width=1.2)
        for k in (-0.55, 0.0, 0.55):
            x = cx + rx * k
            # hoop follows the barrel side
            self.line((x, cy - ry * 0.92), (x, cy + ry * 0.92),
                      mix(fill, BRASS_DIM, 0.55), 1.1)
        self.line((cx - rx * 0.92, cy), (cx + rx * 0.92, cy), mix(fill, WOOD_LIGHT, 0.5), 0.8)

    def draw_cargo_holds(self):
        # hold 1
        self.draw_crate(0.462, 0.578, 0.512, 0.653, 0.0)
        self.draw_crate(0.466, 0.500, 0.507, 0.572, 0.35)
        self.draw_crate(0.516, 0.607, 0.540, 0.653, 0.15)
        self.draw_barrel(0.526, 0.566, 0.0115, 0.038, mix(WOOD, STEEL_DARK, 0.30))

        # hold 2
        self.draw_crate(0.556, 0.585, 0.602, 0.653, 0.1)
        self.draw_crate(0.560, 0.512, 0.597, 0.580, 0.45)
        self.draw_crate(0.606, 0.607, 0.640, 0.653, 0.0)
        self.draw_barrel(0.616, 0.570, 0.012, 0.040, mix(WOOD, STEEL_DARK, 0.2))

        # dunnage on the hold floors
        for x0, x1 in ((0.458, 0.544), (0.548, 0.643)):
            self.line((x0, 0.656), (x1, 0.656), mix(WOOD, BRASS_DIM, 0.30), 1.2)

        # hold ladders / blocking
        self.line((0.548, 0.470), (0.552, 0.652), mix(STEEL_MID, BRASS_DIM, 0.3), 1.0)
        self.line((0.544, 0.470), (0.540, 0.652), mix(STEEL_MID, BRASS_DIM, 0.3), 1.0)
        for k in range(6):
            fy = 0.492 + k * 0.026
            self.line((0.542, fy), (0.550, fy), mix(STEEL_MID, BRASS_DIM, 0.35), 0.9)

    # -- safety / lifeboat --------------------------------------------------
    def draw_safety_station(self):
        # davits
        davit = mix(STEEL_MID, BRASS_DIM, 0.55)
        for base_x, sign in ((0.648, -1), (0.700, 1)):
            pts = [(base_x, DECK_Y), (base_x + sign * 0.002, 0.360),
                   (base_x + sign * 0.008, 0.330), (base_x + sign * 0.016, 0.314)]
            self.polyline(pts, davit, 2.0)
            self.dot(base_x, 0.396, 1.6, mix(STEEL_MID, BRASS_DIM, 0.6))

        # lifeboat
        boat = [
            (0.639, 0.332), (0.647, 0.313), (0.674, 0.307),
            (0.699, 0.313), (0.707, 0.332), (0.699, 0.349),
            (0.674, 0.354), (0.647, 0.349),
        ]
        self.polygon(boat, fill=mix(STEEL_MID, PAPER, 0.30), outline=BRASS_DIM, width=1.8)
        # planks
        self.line((0.646, 0.325), (0.701, 0.325), mix(PAPER, STEEL_MID, 0.45), 1.0)
        self.line((0.645, 0.339), (0.702, 0.339), mix(PAPER, STEEL_MID, 0.45), 1.0)
        self.line((0.651, 0.349), (0.696, 0.349), mix(PAPER, STEEL_MID, 0.35), 0.9)
        # gunwale + keel
        self.line((0.641, 0.327), (0.706, 0.327), BRASS, 1.4)
        self.line((0.657, 0.354), (0.691, 0.354), BRASS_DIM, 1.1)
        # boat falls
        self.line((0.649, 0.314), (0.660, 0.330), mix(STEEL_MID, BRASS_DIM, 0.3), 0.9)
        self.line((0.699, 0.314), (0.688, 0.330), mix(STEEL_MID, BRASS_DIM, 0.3), 0.9)

        # safety lockers below deck
        self.rect(0.652, 0.560, 0.690, 0.653, fill=mix(STEEL_DARK, STEEL_MID, 0.45),
                  outline=mix(STEEL_DARK, BRASS_DIM, 0.55), width=1.4)
        self.line((0.671, 0.560), (0.671, 0.653), mix(STEEL_DARK, BRASS_DIM, 0.4), 1.0)
        for dx in (0.669, 0.673):
            self.dot(dx, 0.600, 1.4, mix(STEEL_MID, BRASS_DIM, 0.7))
        self.line((0.656, 0.575), (0.664, 0.575), mix(STEEL_MID, TEAL, 0.4), 1.0)

        # life rings on the bulkhead
        for cy in (0.575, 0.613):
            cx = 0.701
            self.circle(cx, cy, 0.014, fill=None, outline=mix(PAPER, STEEL_MID, 0.35), width=1.4)
            self.circle(cx, cy, 0.007, fill=None, outline=mix(PAPER, STEEL_MID, 0.35), width=1.0)
            for ang in (20, 110, 200, 290):
                a = math.radians(ang)
                self.line((cx + math.cos(a) * 0.007 * H / W, cy + math.sin(a) * 0.007),
                          (cx + math.cos(a) * 0.014 * H / W, cy + math.sin(a) * 0.014),
                          mix(PAPER, STEEL_MID, 0.45), 1.0)

        # fire bucket on a hook
        bx, by = 0.655, 0.530
        self.line((bx, 0.512), (bx, by), mix(STEEL_MID, BRASS_DIM, 0.45), 0.9)
        self.polygon([(bx - 0.008, by), (bx + 0.008, by), (bx + 0.006, by + 0.022),
                      (bx - 0.006, by + 0.022)],
                     fill=mix(RUST, STEEL_DARK, 0.35), outline=mix(RUST, BRASS_DIM, 0.35),
                     width=1.0)
        self.arc(bx, by + 0.002, 0.008, 200, 340, mix(RUST, BRASS_DIM, 0.3), 1.0)

        # rope coil on the floor
        for i, r in enumerate((0.018, 0.012, 0.006)):
            self.ellipse(0.676, 0.644, r, r * W / H * 0.55,
                         fill=None, outline=mix(STEEL_MID, PAPER, 0.30), width=0.9)

    # -- navigation / chart room -------------------------------------------
    def draw_navigation_below(self):
        # chart lockers + rolled charts under the deckhouse
        self.rect(0.720, 0.600, 0.760, 0.652, fill=mix(STEEL_DARK, STEEL_MID, 0.5),
                  outline=mix(STEEL_DARK, BRASS_DIM, 0.5), width=1.2)
        self.line((0.720, 0.626), (0.760, 0.626), mix(STEEL_DARK, BRASS_DIM, 0.4), 1.0)
        for i in range(3):
            self.ellipse(0.726 + i * 0.012, 0.613, 0.005, 0.018,
                         fill=mix(PAPER, STEEL_MID, 0.35),
                         outline=mix(STEEL_DARK, BRASS_DIM, 0.4), width=0.8)
        # binnacle stand
        self.line((0.768, 0.652), (0.768, 0.610), mix(STEEL_MID, BRASS_DIM, 0.5), 1.6)
        self.rect(0.760, 0.590, 0.776, 0.612, fill=mix(STEEL_DARK, STEEL_MID, 0.4),
                  outline=BRASS_DIM, width=1.2)

    def draw_navigation_house(self):
        house = mix(STEEL_MID, STEEL_DARK, 0.35)
        edge = mix(house, BRASS_DIM, 0.7)
        x0, x1, y0, y1 = 0.720, 0.792, 0.302, DECK_Y
        self.rect(x0, y0, x1, y1, fill=house, outline=edge, width=1.6)
        # roof overhang
        self.line((x0 - 0.004, y0), (x1 + 0.004, y0), BRASS_DIM, 2.0)
        self.line((x0 - 0.004, y0 - 0.006), (x1 + 0.004, y0 - 0.006),
                  mix(house, BRASS_DIM, 0.35), 1.0)

        # chart table seen through the windows
        self.rect(0.727, 0.352, 0.762, 0.372, fill=mix(WOOD, STEEL_MID, 0.15),
                  outline=mix(WOOD, BRASS_DIM, 0.4), width=1.0)
        self.ellipse(0.738, 0.358, 0.006, 0.010, fill=mix(PAPER, STEEL_MID, 0.15),
                     outline=mix(STEEL_DARK, BRASS_DIM, 0.5), width=0.9)
        self.line((0.748, 0.358), (0.757, 0.358), mix(PAPER, STEEL_MID, 0.25), 2.0)

        # windows
        panes = [(0.727, 0.743), (0.747, 0.763), (0.767, 0.781)]
        for wx0, wx1 in panes:
            self.rect(wx0, 0.326, wx1, 0.370,
                      fill=mix(house, TEAL, 0.34),
                      outline=BRASS_DIM, width=1.1)
            self.line((wx0 + 0.002, 0.332), (wx1 - 0.002, 0.354),
                      mix(house, PAPER, 0.30), 0.9)
        # door
        self.rect(0.780, 0.344, 0.790, DECK_Y, fill=mix(house, STEEL_DARK, 0.35),
                  outline=BRASS_DIM, width=1.1)
        self.dot(0.783, 0.378, 1.2, mix(STEEL_MID, BRASS_DIM, 0.7))

        # roof skylight + compass binnacle
        self.rect(0.740, 0.294, 0.762, 0.302, fill=mix(house, TEAL, 0.22),
                  outline=BRASS_DIM, width=1.0)
        self.line((0.751, 0.302), (0.751, 0.290), mix(STEEL_MID, BRASS_DIM, 0.6), 1.2)
        self.circle(0.751, 0.286, 0.010, fill=mix(STEEL_DARK, STEEL_MID, 0.5),
                    outline=BRASS_DIM, width=1.4)
        self.circle(0.751, 0.286, 0.006, fill=None, outline=mix(TEAL, BRASS_DIM, 0.35), width=0.9)
        self.line((0.751, 0.280), (0.751, 0.292), mix(BRASS, PAPER, 0.3), 0.9)
        self.line((0.745, 0.286), (0.757, 0.286), mix(BRASS, PAPER, 0.3), 0.9)

        # mast + pennant
        mx, my = 0.704, 0.138
        self.line((mx, DECK_Y - 0.002), (mx, my), mix(STEEL_MID, BRASS_DIM, 0.6), 2.4)
        self.circle(mx, my - 0.006, 0.006, fill=BRASS_DIM)
        self.polygon([(mx + 0.003, my - 0.006), (0.762, my + 0.014), (mx + 0.003, my + 0.034)],
                     fill=TEAL, outline=BRASS, width=1.0)
        # mast bands
        for fy in (0.240, 0.300):
            self.line((mx - 0.005, fy), (mx + 0.005, fy), BRASS_DIM, 1.2)
        # stays
        self.grad_line_bg((mx, my + 0.008), (0.646, DECK_Y), TEAL, 0.22, 1.0)
        self.grad_line_bg((mx, my + 0.012), (0.716, 0.302), TEAL, 0.18, 1.0)

    # -- passenger cabin ----------------------------------------------------
    def draw_cabin_below(self):
        # two berths, a small table and a hanging lamp
        berth = mix(WOOD, PAPER, 0.30)
        for y0, y1 in ((0.586, 0.612), (0.618, 0.644)):
            self.rect(0.808, y0, 0.846, y1, fill=mix(STEEL_DARK, STEEL_MID, 0.45),
                      outline=mix(STEEL_DARK, BRASS_DIM, 0.45), width=1.1)
            self.rect(0.810, y0 + 0.006, 0.844, y1 - 0.006, fill=berth, outline=None)
            self.rect(0.811, y0 + 0.008, 0.818, y1 - 0.010, fill=mix(PAPER, STEEL_MID, 0.2),
                      outline=None)
        self.line((0.807, 0.580), (0.807, 0.650), mix(STEEL_MID, BRASS_DIM, 0.4), 1.2)
        self.line((0.850, 0.470), (0.850, 0.652), mix(STEEL_MID, TEAL, 0.25), 1.0)

        self.rect(0.862, 0.606, 0.884, 0.620, fill=mix(WOOD, STEEL_MID, 0.2),
                  outline=mix(WOOD, BRASS_DIM, 0.35), width=1.0)
        self.line((0.866, 0.620), (0.866, 0.650), mix(STEEL_MID, BRASS_DIM, 0.35), 1.0)
        self.line((0.880, 0.620), (0.880, 0.650), mix(STEEL_MID, BRASS_DIM, 0.35), 1.0)

        # hanging lamp
        lx, ly = 0.858, 0.548
        self.line((lx, 0.470), (lx, ly - 0.014), mix(STEEL_MID, BRASS_DIM, 0.5), 1.0)
        self.polygon([(lx - 0.010, ly - 0.014), (lx + 0.010, ly - 0.014),
                      (lx + 0.006, ly), (lx - 0.006, ly)],
                     fill=mix(BRASS_DIM, PAPER, 0.25), outline=BRASS_DIM, width=0.9)
        self.circle(lx, ly - 0.004, 0.006, fill=mix(PAPER, GLOW, 0.35), outline=None)

        # door in the forward bulkhead
        self.rect(0.900, 0.548, 0.910, 0.652, fill=mix(STEEL_DARK, STEEL_MID, 0.4),
                  outline=mix(STEEL_DARK, BRASS_DIM, 0.5), width=1.1)
        self.dot(0.903, 0.600, 1.3, mix(STEEL_MID, BRASS_DIM, 0.7))

    def draw_cabin_house(self):
        house = mix(STEEL_MID, STEEL_DARK, 0.28)
        edge = mix(house, BRASS_DIM, 0.7)
        x0, x1, y0, y1 = 0.802, 0.906, 0.284, DECK_Y
        self.rect(x0, y0, x1, y1, fill=house, outline=edge, width=1.6)
        # roof + overhang
        self.line((x0 - 0.004, y0), (x1 + 0.004, y0), BRASS_DIM, 2.0)
        self.line((x0 - 0.004, y0 - 0.006), (x1 + 0.004, y0 - 0.006),
                  mix(house, BRASS_DIM, 0.35), 1.0)
        self.rect(0.818, 0.270, 0.844, 0.284, fill=mix(house, TEAL, 0.22),
                  outline=BRASS_DIM, width=1.0)
        for fx in (0.824, 0.838):
            self.line((fx, 0.272), (fx, 0.284), mix(house, BRASS_DIM, 0.4), 0.8)

        # windows with curtains
        windows = [(0.811, 0.827), (0.831, 0.847), (0.851, 0.867), (0.871, 0.887)]
        for wx0, wx1 in windows:
            self.rect(wx0, 0.312, wx1, 0.366, fill=mix(house, TEAL, 0.36),
                      outline=BRASS_DIM, width=1.2)
            self.line((wx0 + 0.0015, 0.318), (wx1 - 0.0015, 0.344),
                      mix(house, PAPER, 0.32), 0.9)
            self.line((wx0 + 0.0015, 0.314), (wx0 + 0.003, 0.364),
                      mix(PAPER, house, 0.30), 0.9)
            self.line((wx1 - 0.003, 0.314), (wx1 - 0.0015, 0.364),
                      mix(PAPER, house, 0.30), 0.9)
        # door + awning
        self.rect(0.889, 0.342, 0.901, DECK_Y, fill=mix(house, STEEL_DARK, 0.35),
                  outline=BRASS_DIM, width=1.1)
        self.dot(0.892, 0.374, 1.3, mix(STEEL_MID, BRASS_DIM, 0.7))
        self.line((0.887, 0.306), (0.903, 0.306), mix(house, PAPER, 0.25), 1.0)
        for fx in (0.890, 0.900):
            self.line((fx, 0.306), (fx, 0.342), mix(house, PAPER, 0.15), 0.8)

        # railing on the cabin roof
        self.line((0.806, 0.278), (0.902, 0.278), mix(TEAL, BRASS_DIM, 0.30), 1.1)
        fx = 0.810
        while fx < 0.900:
            self.line((fx, 0.278), (fx, 0.284), mix(TEAL, BRASS_DIM, 0.30), 0.9)
            fx += 0.016

    # -- bow / stern fittings ----------------------------------------------
    def draw_bow_details(self):
        # chain locker coils
        cx, cy = 0.916, 0.610
        for i, r in enumerate((0.022, 0.016, 0.010, 0.004)):
            self.ellipse(cx, cy, r, r * W / H * 0.6, fill=None,
                         outline=mix(STEEL_MID, BRASS_DIM, 0.35 + i * 0.05), width=1.0)
        # hawse pipe
        self.circle(0.929, 0.520, 0.012, fill=mix(STEEL_DARK, VOID, 0.6),
                    outline=mix(STEEL_DARK, BRASS_DIM, 0.5), width=1.2)
        self.circle(0.929, 0.520, 0.006, fill=None, outline=mix(STEEL_DARK, BRASS_DIM, 0.4),
                    width=1.0)

        # stern ensign staff (small)
        self.line((0.205, DECK_Y), (0.205, 0.300), mix(STEEL_MID, BRASS_DIM, 0.5), 1.8)
        self.polygon([(0.205, 0.304), (0.238, 0.316), (0.205, 0.328)],
                     fill=TEAL, outline=BRASS_DIM, width=0.9)

    def draw_doors(self):
        for fx, fy0, fy1 in ((0.423, 0.556, 0.648), (0.645, 0.560, 0.650),
                             (0.800, 0.556, 0.650)):
            self.rrect(fx - 0.010, fy0, fx + 0.010, fy1, 0.007,
                       fill=mix(STEEL_DARK, STEEL_MID, 0.45),
                       outline=mix(STEEL_MID, BRASS_DIM, 0.6), width=1.2)
            self.line((fx - 0.010, fy0 + 0.024), (fx + 0.010, fy0 + 0.024),
                      mix(STEEL_MID, BRASS_DIM, 0.45), 0.9)
            self.dot(fx + 0.006, (fy0 + fy1) / 2, 1.3, mix(STEEL_MID, BRASS_DIM, 0.75))

    def draw_lamp(self, lx: float, y0: float, y1: float):
        self.line((lx, y0), (lx, y1 - 0.012), mix(STEEL_MID, BRASS_DIM, 0.5), 1.0)
        self.polygon([(lx - 0.008, y1 - 0.012), (lx + 0.008, y1 - 0.012),
                      (lx + 0.005, y1), (lx - 0.005, y1)],
                     fill=mix(BRASS_DIM, PAPER, 0.25), outline=BRASS_DIM, width=0.9)
        self.circle(lx, y1 - 0.004, 0.006, fill=mix(PAPER, GLOW, 0.35), outline=None)

    def draw_lamps(self):
        for lx in (0.286, 0.520, 0.692):
            self.draw_lamp(lx, INNER_TOP + 0.004, 0.452)

    # -- water / deck -------------------------------------------------------
    def draw_water(self):
        # waterline with a soft secondary dash line
        self.grad_line_bg((0.0, WATER_Y), (1.0, WATER_Y), TEAL, 0.24, 1.4)
        self.grad_line_bg((0.0, WATER_Y + 0.009), (1.0, WATER_Y + 0.009), TEAL, 0.10, 1.0)
        # foam ticks near the hull
        for x0, x1, fy in ((0.060, 0.100, 0.671), (0.920, 0.958, 0.668),
                           (0.130, 0.175, 0.679), (0.800, 0.850, 0.681)):
            self.grad_line_bg((x0, fy), (x1, fy), TEAL, 0.22, 1.0)
        # a few current strokes below the hull, kept low-detail for the UI chips
        for x0, x1, fy, a in ((0.10, 0.34, 0.812, 0.10), (0.60, 0.86, 0.822, 0.09),
                              (0.24, 0.44, 0.842, 0.08), (0.66, 0.80, 0.858, 0.07),
                              (0.36, 0.58, 0.875, 0.06)):
            self.grad_line_bg((x0, fy), (x1, fy), TEAL, a, 1.0)

    def draw_deck_edge(self):
        # railing along the deck (drawn before the deckhouses)
        rail = mix(TEAL, BRASS_DIM, 0.30)
        self.line((0.080, 0.386), (0.926, 0.386), rail, 1.2)
        fx = 0.086
        while fx < 0.922:
            self.line((fx, 0.386), (fx, DECK_Y - 0.002), rail, 1.0)
            fx += 0.0155
        # deck planking hint
        self.line((HULL_L, DECK_Y + 0.003), (HULL_R, DECK_Y + 0.003),
                  mix(STEEL_DARK, BRASS_DIM, 0.45), 1.0)

    # -- superstructures ----------------------------------------------------
    def draw_engine_casing(self):
        casing = mix(STEEL_MID, STEEL_DARK, 0.45)
        edge = mix(casing, BRASS_DIM, 0.65)
        x0, x1, y0 = 0.290, 0.408, 0.352
        self.rect(x0, y0, x1, DECK_Y, fill=casing, outline=edge, width=1.5)
        self.line((x0 - 0.004, y0), (x1 + 0.004, y0), BRASS_DIM, 1.8)
        # ventilation louvres
        for i in range(5):
            fy = y0 + 0.010 + i * 0.008
            self.line((x0 + 0.006, fy), (x1 - 0.006, fy),
                      mix(casing, TEAL, 0.35), 0.9)
        # rivets
        for fx in (0.296, 0.320, 0.344, 0.368, 0.392, 0.404):
            self.dot(fx, 0.396, 1.2, mix(casing, BRASS_DIM, 0.6))

    def draw_hatches(self):
        for x0, x1 in ((0.465, 0.540), (0.555, 0.630)):
            # coaming
            self.rect(x0, 0.374, x1, DECK_Y, fill=mix(STEEL_DARK, VOID, 0.45),
                      outline=mix(STEEL_DARK, BRASS_DIM, 0.55), width=1.3)
            # grating
            fx = x0 + 0.010
            while fx < x1 - 0.004:
                self.line((fx, 0.377), (fx, DECK_Y - 0.003),
                          mix(STEEL_DARK, TEAL, 0.30), 0.9)
                fx += 0.0125
            for fy in (0.383, 0.390, 0.397):
                self.line((x0 + 0.003, fy), (x1 - 0.003, fy),
                          mix(STEEL_DARK, TEAL, 0.30), 0.9)
            # corner plates
            for cx in (x0 + 0.003, x1 - 0.003):
                self.dot(cx, 0.377, 1.1, mix(STEEL_DARK, BRASS_DIM, 0.5))
        # cargo boom crutch between hatches
        self.line((0.545, 0.372), (0.545, 0.320), mix(STEEL_MID, BRASS_DIM, 0.45), 1.2)
        self.line((0.540, 0.320), (0.550, 0.320), mix(STEEL_MID, BRASS_DIM, 0.45), 1.0)

    def draw_funnel(self):
        x0, x1 = 0.333, 0.380
        top0, top1 = 0.338, 0.376
        y_base, y_top = 0.352, 0.160
        body = mix(STEEL_DARK, STEEL_MID, 0.55)
        self.polygon([(x0, y_base), (x1, y_base), (top1, y_top), (top0, y_top)],
                     fill=body, outline=mix(body, BRASS_DIM, 0.55), width=1.6)
        # brass bands
        for fy in (0.198, 0.252, 0.306):
            t = (y_base - fy) / (y_base - y_top)
            b0 = x0 + (top0 - x0) * t
            b1 = x1 + (top1 - x1) * t
            self.line((b0 - 0.002, fy), (b1 + 0.002, fy), BRASS_DIM, 2.2)
        # crown
        self.polygon([(top0 - 0.006, y_top), (top1 + 0.006, y_top),
                      (top1 + 0.004, y_top - 0.010), (top0 - 0.004, y_top - 0.010)],
                     fill=mix(body, BRASS_DIM, 0.30), outline=BRASS_DIM, width=1.2)
        # highlight + whistle
        self.line((x0 + 0.008, y_base - 0.01), (top0 + 0.006, y_top + 0.012),
                  mix(body, PAPER, 0.22), 1.4)
        self.line((0.381, 0.268), (0.389, 0.268), BRASS_DIM, 1.6)
        self.circle(0.390, 0.268, 0.006, fill=None, outline=BRASS_DIM, width=1.0)
        # steam puffs (soft, light, drifting forward)
        for i, (px, py, r) in enumerate(((0.352, 0.146, 0.013), (0.366, 0.126, 0.017),
                                        (0.352, 0.106, 0.021), (0.373, 0.088, 0.017))):
            tone = mix(bg_at(py), (204, 212, 206), 0.40 - i * 0.07)
            self.ellipse(px, py, r, r * W / H * 0.92, fill=tone, outline=None)
            self.ellipse(px - r * 0.55, py + r * 0.20, r * 0.58, r * 0.58 * W / H,
                         fill=tone, outline=None)
            self.ellipse(px + r * 0.55, py - r * 0.15, r * 0.52, r * 0.52 * W / H,
                         fill=tone, outline=None)
        # stays
        self.grad_line_bg((0.340, 0.164), (0.312, DECK_Y), TEAL, 0.18, 1.0)
        self.grad_line_bg((0.374, 0.164), (0.402, DECK_Y), TEAL, 0.16, 1.0)

    def draw_deck_fittings(self):
        brass = mix(STEEL_DARK, BRASS_DIM, 0.55)
        # capstan
        cx, cy = 0.252, DECK_Y
        self.rect(cx - 0.012, cy - 0.012, cx + 0.012, cy, fill=mix(STEEL_DARK, STEEL_MID, 0.5),
                  outline=brass, width=1.2)
        self.ellipse(cx, cy - 0.012, 0.010, 0.006, fill=mix(STEEL_MID, BRASS_DIM, 0.5),
                     outline=brass, width=1.0)
        for ang in (15, 75, 135):
            a = math.radians(ang)
            self.line((cx - math.cos(a) * 0.009 * H / W, cy - 0.012 - math.sin(a) * 0.009),
                      (cx + math.cos(a) * 0.009 * H / W, cy - 0.012 + math.sin(a) * 0.009),
                      brass, 1.2)
        # bollards
        for bx in (0.440, 0.636, 0.895):
            self.rect(bx - 0.005, DECK_Y - 0.011, bx + 0.005, DECK_Y,
                      fill=mix(STEEL_DARK, STEEL_MID, 0.4), outline=brass, width=1.0)
            self.line((bx - 0.008, DECK_Y - 0.011), (bx + 0.008, DECK_Y - 0.011), brass, 1.4)
        # gooseneck ventilators
        for vx, sign in ((0.447, 1), (0.641, -1)):
            self.polyline([(vx, DECK_Y - 0.004), (vx, 0.360),
                           (vx + sign * 0.006, 0.350), (vx + sign * 0.014, 0.348)],
                          mix(STEEL_MID, BRASS_DIM, 0.45), 2.0)
            self.ellipse(vx + sign * 0.014, 0.348, 0.008, 0.006,
                         fill=mix(STEEL_MID, BRASS_DIM, 0.35), outline=brass, width=0.9)
        # rope coils on deck
        for rx, ry, r in ((0.238, 0.389, 0.012), (0.628, 0.389, 0.010)):
            for k in (1.0, 0.6, 0.3):
                self.ellipse(rx, ry, r * k, r * k * W / H * 0.6, fill=None,
                             outline=mix(PAPER, bg_at(ry), 0.45), width=0.9)
        # small deck cleats
        for fx in (0.300, 0.452, 0.650, 0.914):
            self.line((fx - 0.004, 0.390), (fx + 0.004, 0.390),
                      mix(STEEL_MID, BRASS_DIM, 0.5), 1.4)

    def draw_rivets(self):
        # deck-line rivets (under the deckhouses, so drawn before them)
        fx = 0.084
        while fx < 0.922:
            self.dot(fx, DECK_Y + 0.007, 1.3, mix(STEEL_DARK, BRASS_DIM, 0.55))
            fx += 0.0175
        # keel rivets
        fx = 0.330
        while fx < 0.590:
            self.dot(fx, KEEL_Y - 0.006, 1.2, mix(COPPER, BRASS_DIM, 0.35))
            fx += 0.019
        # inner cut edge rivets along the bottom
        for fx in (0.200, 0.250, 0.300, 0.360, 0.420, 0.480, 0.540, 0.610, 0.680,
                   0.740, 0.800, 0.850):
            self.dot(fx, inner_bottom_y(fx) + 0.004, 1.15, mix(STEEL_MID, BRASS_DIM, 0.4))

    # -- orchestration ------------------------------------------------------
    def render(self) -> Image.Image:
        self.draw_hull()
        self.draw_rivets()
        self.draw_interior_frames()
        self.draw_bulkheads()
        self.draw_doors()
        self.draw_lamps()
        self.draw_paddle_wheel()
        self.draw_boiler_room()
        self.draw_cargo_holds()
        self.draw_safety_station()
        self.draw_navigation_below()
        self.draw_cabin_below()
        self.draw_bow_details()
        self.draw_water()
        self.draw_deck_edge()
        self.draw_hatches()
        self.draw_engine_casing()
        self.draw_funnel()
        self.draw_navigation_house()
        self.draw_cabin_house()
        self.draw_deck_fittings()
        return self.img


# ---------------------------------------------------------------------------
# final-resolution background & grading
# ---------------------------------------------------------------------------
def water_mult(fy: float) -> float:
    """Darkening factor for the water below the waterline."""
    t = max(0.0, (fy - WATER_Y) / (1.0 - WATER_Y))
    return 1.0 - 0.24 * min(1.0, t * 2.6)


def water_bg_at(fy: float):
    base = bg_at(fy)
    m = water_mult(fy)
    return (int(round(base[0] * m)), int(round(base[1] * m)), int(round(base[2] * m)))


def build_background() -> np.ndarray:
    """Background gradient + blueprint grid + ticks + water hatching (RGB float)."""
    yy = np.arange(H, dtype=np.float32) / (H - 1)
    t = (yy ** 1.15)[:, None]
    top = np.array(BG_TOP, dtype=np.float32)
    bot = np.array(BG_BOT, dtype=np.float32)
    bg = top[None, :] * (1.0 - t) + bot[None, :] * t
    bg = np.repeat(bg[:, None, :], W, axis=1)

    # darker water below the waterline, cooled towards the UI water tone
    mult = np.array([water_mult(float(v)) for v in yy], dtype=np.float32)
    bg *= mult[:, None, None]
    wrow = np.clip((yy - WATER_Y) / (1.0 - WATER_Y), 0.0, 1.0)[:, None, None]
    tint = np.array([5, 18, 24], dtype=np.float32)[None, None, :]
    bg = bg * (1.0 - 0.12 * wrow) + tint * (0.12 * wrow)

    # blueprint grid
    xs = np.arange(W)
    ys = np.arange(H)
    minor_x = (xs % 28 == 0)
    minor_y = (ys % 28 == 0)
    major_x = (xs % 112 == 0)
    major_y = (ys % 112 == 0)
    grid_a = np.zeros((H, W), dtype=np.float32)
    grid_a[minor_y, :] = np.maximum(grid_a[minor_y, :], 0.055)
    grid_a[:, minor_x] = np.maximum(grid_a[:, minor_x], 0.055)
    grid_a[major_y, :] = np.maximum(grid_a[major_y, :], 0.085)
    grid_a[:, major_x] = np.maximum(grid_a[:, major_x], 0.085)

    # edge ticks (top / left / right registration ticks, no labels)
    tick = np.zeros((H, W), dtype=np.float32)
    for x in range(0, W, 28):
        length = 11 if x % 112 == 0 else 5
        tick[0:length, x] = max(tick[0:length, x].max(), 0.16)
    for y in range(0, H, 28):
        length = 11 if y % 112 == 0 else 5
        tick[y, 0:length] = max(tick[y, 0:length].max(), 0.12)
        tick[y, W - length:W] = max(tick[y, W - length:W].max(), 0.12)

    teal = np.array(TEAL, dtype=np.float32)
    grid_a = np.maximum(grid_a, tick)
    bg = bg * (1.0 - grid_a[..., None]) + teal * grid_a[..., None]

    img = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(img)
    # water hatching below the waterline (low detail: slot chips overlay here)
    y = int(round(WATER_Y * H)) + 6
    row = 0
    while y < H:
        if row % 3 != 2:
            base = water_bg_at(y / (H - 1))
            col = mix(base, TEAL, 0.075 if row % 2 else 0.10)
            dash = 20 if row % 2 else 30
            gap = 12
            x = -((row * 17) % (dash + gap))
            while x < W:
                draw.line([(x, y), (min(x + dash, W), y)], fill=col, width=1)
                x += dash + gap
        y += 13
        row += 1

    # blueprint datum lines (hidden by the hull where they cross it) + margin crosses
    for fy, base_fn in ((DECK_Y, bg_at), (WATER_Y, water_bg_at)):
        col = mix(base_fn(fy), TEAL, 0.14)
        x = 0
        while x < W:
            draw.line([(x, fy * H), (min(x + 24, W), fy * H)], fill=col, width=1)
            x += 24 + 14
    cross = mix(bg_at(0.5), TEAL, 0.30)
    for cx, cy in ((0.030 * W, DECK_Y * H), (0.970 * W, DECK_Y * H),
                   (0.030 * W, WATER_Y * H), (0.970 * W, WATER_Y * H)):
        draw.line([(cx - 6, cy), (cx + 6, cy)], fill=cross, width=1)
        draw.line([(cx, cy - 6), (cx, cy + 6)], fill=cross, width=1)
    # faint waterline sheen
    sheen = mix(water_bg_at(WATER_Y), TEAL, 0.10)
    for dy in range(-3, 4):
        draw.line([(0, WATER_Y * H + dy), (W, WATER_Y * H + dy)], fill=sheen, width=1)
    return np.asarray(img, dtype=np.float32)


def apply_vignette(arr: np.ndarray, dither_mask: np.ndarray | None = None) -> np.ndarray:
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    nx = (xx / (W - 1) - 0.5) * 2.0
    ny = (yy / (H - 1) - 0.5) * 2.0
    r2 = nx * nx * 0.92 + ny * ny * 1.10
    v = 1.0 - 0.40 * np.clip(r2, 0.0, 1.9) ** 1.15
    v = np.clip(v, 0.48, 1.0)
    # slight extra darkening towards the bottom band to keep slot chips legible
    band = np.clip((yy / H - 0.70) / 0.30, 0.0, 1.0)
    v = v * (1.0 - 0.16 * band ** 1.4)
    out = arr * v[..., None]
    # ordered dither breaks up banding in the very dark gradient (deterministic).
    # Only the background is dithered: the hull is flat-coloured and compresses well.
    bayer4 = np.array([[0, 8, 2, 10],
                       [12, 4, 14, 6],
                       [3, 11, 1, 9],
                       [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5
    dither = np.tile(bayer4, (H // 4 + 1, W // 4 + 1))[:H, :W] * 0.9
    if dither_mask is not None:
        dither = dither * dither_mask
    out = out + dither[..., None]
    return np.clip(out, 0, 255)


def build_section(out_path: Path) -> tuple[int, int, int]:
    art = SectionArt().render()
    base = build_background()
    art_small = art.resize((W, H), Image.Resampling.LANCZOS)
    canvas = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    canvas.alpha_composite(art_small)
    bg_mask = 1.0 - np.asarray(art_small.getchannel("A"), dtype=np.float32) / 255.0
    out = apply_vignette(np.asarray(canvas.convert("RGB"), dtype=np.float32), bg_mask)
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")
    img.save(out_path, optimize=True)
    return img.size[0], img.size[1], out_path.stat().st_size


# ---------------------------------------------------------------------------
# card thumbnail
# ---------------------------------------------------------------------------
THUMB_SIZE = (640, 360)
THUMB_CROP = (72, 0, 1316, 700)  # 16:9 crop centred on the ship (source 1400x700)


def build_thumbnail(src_path: Path, out_path: Path) -> tuple[int, int, int]:
    src = Image.open(src_path).convert("RGB")
    crop = src.crop(THUMB_CROP).resize(THUMB_SIZE, Image.Resampling.LANCZOS)
    arr = np.asarray(crop).astype(np.float32)
    h, w = arr.shape[:2]

    # The source render sits on a flat studio grey; rebuild the plate in the UI palette.
    border = np.concatenate([
        arr[:3].reshape(-1, 3), arr[-3:].reshape(-1, 3),
        arr[:, :3].reshape(-1, 3), arr[:, -3:].reshape(-1, 3),
    ])
    plate = np.median(border, axis=0)
    bg_mask = (np.abs(arr - plate).max(axis=2) <= 9.0).astype(np.float32)
    # soften the cut so the downscaled ship edge has no grey fringe
    mask_img = Image.fromarray((bg_mask * 255).astype(np.uint8), "L")
    mask_img = mask_img.filter(ImageFilter.GaussianBlur(1.1))
    bg_mask = np.asarray(mask_img).astype(np.float32) / 255.0
    ship_alpha = 1.0 - bg_mask

    # grade the ship to sit in the dark palette without losing its identity
    ship = arr / 255.0
    lum = ship[..., 0] * 0.299 + ship[..., 1] * 0.587 + ship[..., 2] * 0.114
    warm = np.clip((ship[..., 0] - ship[..., 2]) * 1.8, 0.0, 1.0)
    ship = np.power(np.clip(ship, 0, 1), 1.10) * 1.04
    ship = np.clip((ship - 0.015) * 1.06 + 0.015, 0.0, 1.0)
    shadow = np.clip(1.0 - lum * 2.0, 0.0, 1.0)
    ship = ship + np.array([0.006, 0.030, 0.038], dtype=np.float32) * shadow[..., None]
    ship[..., 0] += 0.045 * warm
    ship[..., 1] += 0.012 * warm
    ship[..., 2] -= 0.010 * warm
    ship = np.clip(ship, 0, 1) * 255.0

    # backdrop: UI palette gradient, lifted centre, vignette
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = (np.arange(h, dtype=np.float32) / (h - 1)) ** 1.15
    top = np.array(BG_TOP, dtype=np.float32)
    bot = np.array(BG_BOT, dtype=np.float32)
    plate_img = top[None, None, :] * (1.0 - t[:, None, None]) + bot[None, None, :] * t[:, None, None]
    plate_img = np.repeat(plate_img, w, axis=1)
    r = np.sqrt(((xx / w - 0.5) * 1.05) ** 2 + ((yy / h - 0.5) * 1.25) ** 2)
    plate_img *= (1.0 - 0.34 * np.clip(r, 0, 1.0) ** 1.5)[..., None]
    # soft teal spotlight behind the ship so the silhouette separates from the plate
    glow_r = np.sqrt(((xx / w - 0.52) * 1.45) ** 2 + ((yy / h - 0.60) * 1.85) ** 2)
    glow = np.clip(1.0 - glow_r, 0.0, 1.0) ** 2.0
    plate_img += np.array([8, 24, 26], dtype=np.float32)[None, None, :] * glow[..., None] * 0.85

    out = plate_img * (1.0 - ship_alpha[..., None]) + ship * ship_alpha[..., None]

    # unified vignette to marry ship + plate
    v = 1.0 - 0.34 * np.clip(r / 1.05, 0, 1.0) ** 1.45
    out = out * v[..., None]
    out = np.clip(out, 0, 255).astype(np.uint8)
    img = Image.fromarray(out, "RGB")
    img.save(out_path, optimize=True)
    return img.size[0], img.size[1], out_path.stat().st_size


# ---------------------------------------------------------------------------
# cli
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-root", type=Path, default=Path(__file__).resolve().parents[2],
                        help="Repository root; assets are written under assets/ui/shipyard/.")
    parser.add_argument("--source", type=Path, default=None,
                        help="Source render for the thumbnail "
                             "(default: <repo>/docs/design/screenshots/ironclad_broadside.png).")
    parser.add_argument("--section-only", action="store_true")
    parser.add_argument("--thumb-only", action="store_true")
    args = parser.parse_args()

    out_dir = args.out_root / "assets" / "ui" / "shipyard"
    out_dir.mkdir(parents=True, exist_ok=True)
    section_path = out_dir / "ship_section.png"
    thumb_path = out_dir / "ship_thumb_ironclad.png"
    source = args.source or (args.out_root / "docs/design/screenshots/ironclad_broadside.png")

    if not args.thumb_only:
        w, h, size = build_section(section_path)
        print(f"section  {section_path}  {w}x{h}  {size} bytes")
    if not args.section_only:
        if not source.exists():
            print(f"thumbnail source missing: {source}")
            return 1
        w, h, size = build_thumbnail(source, thumb_path)
        print(f"thumb    {thumb_path}  {w}x{h}  {size} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
