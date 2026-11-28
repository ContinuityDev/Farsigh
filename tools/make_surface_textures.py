#!/usr/bin/env python3
"""Write small RGBA surface maps used by the compound (stucco, wood, roof, chain, leaf)."""
import math
import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "surfaces")


def write_png(path, w, h, rgba):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + rgba[y * w * 4 : (y + 1) * w * 4] for y in range(h))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png)


def noise(x, y):
    n = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
    return n - math.floor(n)


def stucco(w=256, h=256):
    buf = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            n = noise(x * 0.15, y * 0.15)
            n2 = noise(x * 0.05 + 3.0, y * 0.05)
            v = int(max(0, min(255, 168 + n * 70 + n2 * 28 - 20)))
            # Occasional pit
            if noise(x * 0.4, y * 0.4) > 0.92:
                v = int(v * 0.72)
            i = (y * w + x) * 4
            buf[i : i + 4] = bytes((v, v, v, 255))
    return buf


def wood(w=256, h=256):
    buf = bytearray(w * h * 4)
    for y in range(h):
        plank = y // 32
        seam = (y % 32) < 2
        for x in range(w):
            grain = noise(x * 0.08 + plank * 4.0, y * 0.9)
            knot = noise(x * 0.02 + plank, 2.0)
            v = 150 + grain * 55 + knot * 20
            if seam:
                v = 55
            # Staggered end joint
            joint_x = (40 + plank * 37) % w
            if abs((x - joint_x + w) % w) < 2 and not seam:
                v = 70
            v = int(max(0, min(255, v)))
            i = (y * w + x) * 4
            buf[i : i + 4] = bytes((v, int(v * 0.92), int(v * 0.78), 255))
    return buf


def roof(w=256, h=256):
    buf = bytearray(w * h * 4)
    row_h = 18
    for y in range(h):
        row = y // row_h
        local = y % row_h
        shift = 16 if row % 2 else 0
        for x in range(w):
            sx = (x + shift) % w
            edge = local < 2 or (sx % 28) < 2
            v = 92 + noise(x * 0.2, y * 0.2) * 30
            if edge:
                v = 38
            v = int(max(0, min(255, v)))
            i = (y * w + x) * 4
            buf[i : i + 4] = bytes((v, v, int(v * 0.96), 255))
    return buf


def chain(w=128, h=128):
    buf = bytearray(w * h * 4)
    period = 10
    for y in range(h):
        for x in range(w):
            d1 = (x + y) % period
            d2 = (x - y) % period
            wire = d1 < 2 or d2 < 2
            a = 230 if wire else 0
            v = 210 if wire else 0
            i = (y * w + x) * 4
            buf[i : i + 4] = bytes((v, v, v, a))
    return buf


def leaf(w=128, h=128):
    buf = bytearray(w * h * 4)
    cx = (w - 1) * 0.5
    cy = (h - 1) * 0.5
    blobs = [
        (0.0, 0.05, 0.62, 1.0),
        (0.22, -0.16, 0.40, 0.9),
        (-0.24, -0.10, 0.38, 0.88),
        (0.02, 0.28, 0.36, 0.82),
        (-0.16, 0.18, 0.28, 0.75),
        (0.18, 0.16, 0.26, 0.75),
    ]
    for y in range(h):
        for x in range(w):
            u = (x - cx) / cx
            v = (y - cy) / cy
            cover = 0.0
            for bx, by, rad, amp in blobs:
                d = math.hypot((u - bx) / 1.05, (v - by) / 1.12)
                if d < rad:
                    cover = max(cover, amp * (1.0 - d / rad))
            edge = abs(math.sin(u * 18.0 + v * 11.0) * math.cos(u * 9.0 - v * 13.0))
            if cover < 0.28 and edge > 0.7:
                cover = 0.0
            a = 255 if cover > 0.12 else 0
            shade = int(max(0, min(255, 140 + cover * 110)))
            i = (y * w + x) * 4
            buf[i : i + 4] = bytes((shade, shade, shade, a))
    return buf


def main():
    os.makedirs(OUT, exist_ok=True)
    write_png(os.path.join(OUT, "stucco.png"), 256, 256, stucco())
    write_png(os.path.join(OUT, "wood.png"), 256, 256, wood())
    write_png(os.path.join(OUT, "roof.png"), 256, 256, roof())
    write_png(os.path.join(OUT, "chainlink.png"), 128, 128, chain())
    write_png(os.path.join(OUT, "leaf.png"), 128, 128, leaf())
    print("wrote", OUT)


if __name__ == "__main__":
    main()
