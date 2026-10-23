# -*- coding: utf-8 -*-
# @static-doc
# 作用：蓝图生成器可复现端到端测试；临时生成蒸汽船 GLB，经外层批处理调用 Blender 后台渲染，
# 校验三张 2048 RGBA PNG、透明像素、模型尺寸和三视图元数据，不依赖 Godot。
# @end-static-doc

import argparse
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib


def _parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blender", required=True)
    parser.add_argument("--keep-output", action="store_true")
    return parser


def _run(command):
    completed = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, encoding="utf-8", errors="replace", check=False)
    if completed.returncode != 0:
        raise AssertionError("command failed (%d):\n%s" % (completed.returncode, completed.stdout))
    return completed.stdout


def _png_info(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError("not a PNG: %s" % path)
    width, height, depth, color_type = struct.unpack(">IIBB", data[16:26])
    chunks = []
    offset = 8
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        if kind == b"IDAT":
            chunks.append(payload)
        offset += 12 + length
    return width, height, depth, color_type, zlib.decompress(b"".join(chunks))


def _alpha_extrema(width, height, raw):
    stride = width * 4
    previous = bytearray(stride)
    minimum, maximum = 255, 0
    offset = 0
    for _row in range(height):
        filter_type = raw[offset]
        encoded = raw[offset + 1:offset + 1 + stride]
        offset += 1 + stride
        decoded = bytearray(stride)
        for index, value in enumerate(encoded):
            left = decoded[index - 4] if index >= 4 else 0
            above = previous[index]
            upper_left = previous[index - 4] if index >= 4 else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                estimate = left + above - upper_left
                distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
                predictor = (left, above, upper_left)[distances.index(min(distances))]
            else:
                raise AssertionError("unsupported PNG filter %d" % filter_type)
            decoded[index] = (value + predictor) & 0xFF
        alpha = decoded[3::4]
        minimum = min(minimum, min(alpha))
        maximum = max(maximum, max(alpha))
        previous = decoded
    return minimum, maximum


def main():
    args = _parser().parse_args()
    here = Path(__file__).resolve().parent
    workspace = here.parents[3]
    test_root = workspace / ".design" / "blueprint_tests"
    test_root.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix="sn-blueprint-test-", dir=str(test_root)))
    try:
        fixture = root / "fixture_ship.glb"
        output = root / "blueprint"
        _run([args.blender, "-b", "-P", str(here / "create_fixture.py"), "--", str(fixture)])
        _run([
            sys.executable, str(here.parent / "blueprint_batch.py"),
            "--blender", args.blender, "--input", str(fixture), "--output", str(output),
            "--views", "side,top,iso", "--detail", "normal", "--resolution", "2048",
        ])
        cropped_sizes = {}
        for view in ("side", "top", "iso"):
            width, height, depth, color_type, pixels = _png_info(output / (view + ".png"))
            assert 0 < width <= 2048 and 0 < height <= 2048
            assert (width, height) != (2048, 2048), "%s was not cropped" % view
            assert (depth, color_type) == (8, 6)
            assert _alpha_extrema(width, height, pixels) == (0, 255), \
                "%s must contain both transparent background and opaque lines" % view
            cropped_sizes[view] = [width, height]
        metadata = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
        assert metadata["orientation"] == {"forward_axis": "+X", "up_axis": "+Z"}
        assert list(metadata["views"]) == ["iso", "side", "top"]
        for view in ("side", "top", "iso"):
            assert metadata["views"][view]["render_resolution"] == [2048, 2048]
            assert metadata["views"][view]["resolution"] == cropped_sizes[view]
            crop = metadata["views"][view]["crop"]
            assert crop["enabled"] is True
            assert crop["source_size"] == [2048, 2048]
            assert crop["output_size"] == cropped_sizes[view]
            assert crop["padding_pixels"] > 0
        assert all(value > 0.0 for value in metadata["model"]["dimensions"])
        assert metadata["model"]["mesh_object_count"] == 4
        summary = json.loads((output / "batch_summary.json").read_text(encoding="utf-8"))
        assert summary["succeeded"] == 1 and summary["failed"] == 0

        blend_output = root / "blend_blueprint"
        _run([
            sys.executable, str(here.parent / "blueprint_batch.py"),
            "--blender", args.blender, "--input", str(fixture.with_suffix(".blend")),
            "--output", str(blend_output), "--views", "side", "--detail", "simple",
            "--resolution", "512",
        ])
        blend_meta = json.loads((blend_output / "metadata.json").read_text(encoding="utf-8"))
        assert blend_meta["source"]["extension"] == ".blend"
        assert (blend_output / "side.png").is_file()

        uncropped_output = root / "uncropped_blueprint"
        _run([
            sys.executable, str(here.parent / "blueprint_batch.py"),
            "--blender", args.blender, "--input", str(fixture),
            "--output", str(uncropped_output), "--views", "side", "--detail", "simple",
            "--resolution", "256", "--no-crop",
        ])
        no_crop_meta = json.loads((uncropped_output / "metadata.json").read_text(encoding="utf-8"))
        assert no_crop_meta["views"]["side"]["crop"]["enabled"] is False
        assert no_crop_meta["views"]["side"]["resolution"] == [256, 256]

        isolation_input = root / "isolation_input"
        isolation_input.mkdir()
        shutil.copy2(fixture, isolation_input / fixture.name)
        (isolation_input / "broken.glb").write_bytes(b"not a glb")
        isolation_output = root / "isolation_output"
        isolated = subprocess.run([
            sys.executable, str(here.parent / "blueprint_batch.py"),
            "--blender", args.blender, "--input", str(isolation_input),
            "--output", str(isolation_output), "--views", "side", "--detail", "simple",
            "--resolution", "256",
        ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8",
           errors="replace", check=False)
        assert isolated.returncode == 1, isolated.stdout
        isolation_summary = json.loads((isolation_output / "batch_summary.json").read_text(encoding="utf-8"))
        assert isolation_summary["succeeded"] == 1 and isolation_summary["failed"] == 1
        print("BLUEPRINT_SMOKE_OK %s" % output)
        if args.keep_output:
            print("BLUEPRINT_SMOKE_KEPT %s" % root)
            return 0
    finally:
        if not args.keep_output:
            shutil.rmtree(root, ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
