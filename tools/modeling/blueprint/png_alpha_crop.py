# -*- coding: utf-8 -*-
# @static-doc
# 作用：对 Blender 输出的 8-bit RGBA PNG 做无第三方依赖的 Alpha 包围框裁切；保留颜色配置块，
# 用确定性的 filter-0 + zlib 重编码覆盖原图，并返回原始画布、内容框、留白框与最终尺寸元数据。
#
# ## 契约与约束
# - 只接受 Blender 线稿管线使用的非交错 RGBA8 PNG；其它 PNG 类型明确报错，不静默转码。
# - 内容像素判据为 `alpha > threshold`；裁切框使用左/上包含、右/下不包含坐标。
# - 写入采用同目录临时文件 + `os.replace`，失败时不破坏已有 PNG。
# @end-static-doc

import binascii
import math
import os
import struct
import zlib


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
COLOR_CHUNKS = {b"cHRM", b"gAMA", b"iCCP", b"sRGB", b"pHYs"}


def _read_chunks(data):
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG file")
    chunks = []
    offset = len(PNG_SIGNATURE)
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload_end = offset + 8 + length
        crc_end = payload_end + 4
        if crc_end > len(data):
            raise ValueError("truncated PNG chunk")
        payload = data[offset + 8:payload_end]
        expected = struct.unpack(">I", data[payload_end:crc_end])[0]
        actual = binascii.crc32(kind + payload) & 0xFFFFFFFF
        if expected != actual:
            raise ValueError("PNG CRC mismatch in %s" % kind.decode("ascii", "replace"))
        chunks.append((kind, payload))
        offset = crc_end
        if kind == b"IEND":
            break
    if not chunks or chunks[-1][0] != b"IEND":
        raise ValueError("PNG has no IEND chunk")
    return chunks


def _chunk(kind, payload):
    crc = binascii.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)


def _paeth(left, above, upper_left):
    estimate = left + above - upper_left
    distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
    return (left, above, upper_left)[distances.index(min(distances))]


def _decode_rgba(chunks):
    ihdr = next((payload for kind, payload in chunks if kind == b"IHDR"), None)
    if ihdr is None or len(ihdr) != 13:
        raise ValueError("PNG has no valid IHDR")
    width, height, depth, color_type, compression, filtering, interlace = struct.unpack(
        ">IIBBBBB", ihdr
    )
    if (depth, color_type, compression, filtering, interlace) != (8, 6, 0, 0, 0):
        raise ValueError(
            "expected non-interlaced RGBA8 PNG, got depth=%d color_type=%d interlace=%d"
            % (depth, color_type, interlace)
        )
    packed = b"".join(payload for kind, payload in chunks if kind == b"IDAT")
    raw = zlib.decompress(packed)
    stride = width * 4
    expected_size = height * (stride + 1)
    if len(raw) != expected_size:
        raise ValueError("unexpected PNG scanline size")
    rows = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        encoded = raw[offset + 1:offset + 1 + stride]
        offset += stride + 1
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
                predictor = _paeth(left, above, upper_left)
            else:
                raise ValueError("unsupported PNG filter: %d" % filter_type)
            decoded[index] = (value + predictor) & 0xFF
        rows.append(bytes(decoded))
        previous = decoded
    return width, height, rows


def _content_bounds(rows, width, threshold):
    left, top, right, bottom = width, len(rows), -1, -1
    for y, row in enumerate(rows):
        for x in range(width):
            if row[x * 4 + 3] > threshold:
                left = min(left, x)
                top = min(top, y)
                right = max(right, x)
                bottom = max(bottom, y)
    if right < left or bottom < top:
        raise ValueError("PNG has no pixels above alpha threshold %d" % threshold)
    return left, top, right + 1, bottom + 1


def _encode_rgba(width, height, rows, preserved_chunks):
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    scanlines = b"".join(b"\x00" + row for row in rows)
    parts = [PNG_SIGNATURE, _chunk(b"IHDR", ihdr)]
    parts.extend(_chunk(kind, payload) for kind, payload in preserved_chunks)
    parts.append(_chunk(b"IDAT", zlib.compress(scanlines, 9)))
    parts.append(_chunk(b"IEND", b""))
    return b"".join(parts)


def crop_png(path, alpha_threshold=8, padding_ratio=0.04):
    """Crop transparent borders in-place and return JSON-serializable metadata."""
    if not 0 <= int(alpha_threshold) <= 254:
        raise ValueError("alpha_threshold must be between 0 and 254")
    if not 0.0 <= float(padding_ratio) <= 0.5:
        raise ValueError("padding_ratio must be between 0.0 and 0.5")
    with open(path, "rb") as handle:
        chunks = _read_chunks(handle.read())
    width, height, rows = _decode_rgba(chunks)
    content = _content_bounds(rows, width, int(alpha_threshold))
    content_width = content[2] - content[0]
    content_height = content[3] - content[1]
    padding = int(math.ceil(max(content_width, content_height) * float(padding_ratio)))
    crop = (
        max(0, content[0] - padding),
        max(0, content[1] - padding),
        min(width, content[2] + padding),
        min(height, content[3] + padding),
    )
    output_width = crop[2] - crop[0]
    output_height = crop[3] - crop[1]
    metadata = {
        "enabled": True,
        "alpha_threshold": int(alpha_threshold),
        "padding_ratio": float(padding_ratio),
        "padding_pixels": padding,
        "source_size": [width, height],
        "content_bounds": list(content),
        "crop_bounds": list(crop),
        "output_size": [output_width, output_height],
    }
    if crop == (0, 0, width, height):
        return metadata
    cropped_rows = [row[crop[0] * 4:crop[2] * 4] for row in rows[crop[1]:crop[3]]]
    preserved = [(kind, payload) for kind, payload in chunks if kind in COLOR_CHUNKS]
    encoded = _encode_rgba(output_width, output_height, cropped_rows, preserved)
    temporary = path + ".crop.tmp"
    try:
        with open(temporary, "wb") as handle:
            handle.write(encoded)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.remove(temporary)
    return metadata
