#!/usr/bin/env python3
"""Pack the CC0 Quaternius male with a subset of Universal Animation Library clips."""
from __future__ import annotations

import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAR = Path("/tmp/cc0/character.glb")
UAL = Path("/tmp/cc0/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb")
OUT = ROOT / "assets/characters/militia_male.glb"

KEEP = [
    "Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop",
    "Crouch_Idle_Loop", "Crouch_Fwd_Loop", "Pistol_Idle_Loop",
    "Pistol_Aim_Neutral", "Pistol_Aim_Up", "Pistol_Shoot", "Pistol_Reload",
    "Hit_Chest", "Hit_Head", "Death01", "Interact", "Punch_Jab",
]


def load_glb(path: Path):
    data = path.read_bytes()
    clen, ctype = struct.unpack_from("<I4s", data, 12)
    if ctype != b"JSON":
        raise SystemExit(f"bad json chunk in {path}")
    js = json.loads(data[20 : 20 + clen])
    off = 20 + clen
    while off % 4:
        off += 1
    blen, btype = struct.unpack_from("<I4s", data, off)
    if btype != b"BIN\x00":
        raise SystemExit(f"bad bin chunk in {path}")
    blob = bytearray(data[off + 8 : off + 8 + blen])
    return js, blob


def read_indices(js, blob, accessor_index):
    acc = js["accessors"][accessor_index]
    view = js["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = acc["count"]
    ctype = acc["componentType"]
    if ctype == 5123:
        fmt, step = "<H", 2
    elif ctype == 5125:
        fmt, step = "<I", 4
    elif ctype == 5121:
        fmt, step = "<B", 1
    else:
        raise SystemExit(f"index type {ctype}")
    return [struct.unpack_from(fmt, blob, start + i * step)[0] for i in range(count)]


def read_positions(js, blob, accessor_index):
    acc = js["accessors"][accessor_index]
    view = js["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or 12
    return [struct.unpack_from("<fff", blob, start + i * stride) for i in range(acc["count"])]


def classify(x, y, _z):
    if y > 1.52 or (abs(x) > 0.62 and 1.15 < y < 1.58):
        return 0
    if y < 0.20:
        return 2
    return 1


def _mat(name, rgb, rough):
    return {
        "name": name,
        "doubleSided": False,
        "pbrMetallicRoughness": {
            "baseColorFactor": rgb + [1.0],
            "metallicFactor": 0.02,
            "roughnessFactor": rough,
        },
    }


def split_body(js, blob):
    mesh = js["meshes"][2]
    prim = mesh["primitives"][0]
    positions = read_positions(js, blob, prim["attributes"]["POSITION"])
    indices = read_indices(js, blob, prim["indices"])
    buckets = [[], [], []]
    for t in range(0, len(indices), 3):
        tri = indices[t : t + 3]
        kinds = [classify(*positions[i]) for i in tri]
        kind = max(set(kinds), key=kinds.count)
        buckets[kind].extend(tri)
    new_prims = []
    for kind, inds in enumerate(buckets):
        if not inds:
            continue
        raw = struct.pack("<" + "H" * len(inds), *inds)
        while len(blob) % 4:
            blob.append(0)
        off = len(blob)
        blob.extend(raw)
        view_i = len(js["bufferViews"])
        js["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(raw), "target": 34963})
        acc_i = len(js["accessors"])
        js["accessors"].append({"bufferView": view_i, "componentType": 5123, "count": len(inds), "type": "SCALAR"})
        dup = dict(prim)
        dup["indices"] = acc_i
        dup["material"] = kind
        new_prims.append(dup)
    mesh["primitives"] = new_prims
    js["materials"] = [
        _mat("Skin", [0.74, 0.56, 0.44], 0.62),
        _mat("Cloth", [0.28, 0.33, 0.22], 0.84),
        _mat("Boots", [0.10, 0.09, 0.08], 0.55),
        _mat("Eyes", [0.12, 0.10, 0.09], 0.35),
        _mat("Brows", [0.18, 0.11, 0.08], 0.8),
    ]
    js["meshes"][0]["primitives"][0]["material"] = 4
    js["meshes"][1]["primitives"][0]["material"] = 3


def copy_anims(char, cblob, ual, ublob):
    name_to_index = {n.get("name"): i for i, n in enumerate(char["nodes"]) if n.get("name")}
    by_name = {a["name"]: a for a in ual["animations"]}
    view_cache = {}
    acc_cache = {}

    def copy_view(view_index):
        if view_index in view_cache:
            return view_cache[view_index]
        view = ual["bufferViews"][view_index]
        start = view.get("byteOffset", 0)
        length = view["byteLength"]
        while len(cblob) % 4:
            cblob.append(0)
        off = len(cblob)
        cblob.extend(ublob[start : start + length])
        view_i = len(char["bufferViews"])
        entry = {"buffer": 0, "byteOffset": off, "byteLength": length}
        if "byteStride" in view:
            entry["byteStride"] = view["byteStride"]
        char["bufferViews"].append(entry)
        view_cache[view_index] = view_i
        return view_i

    def copy_accessor(ai):
        if ai in acc_cache:
            return acc_cache[ai]
        acc = ual["accessors"][ai]
        new_acc = {k: v for k, v in acc.items() if k != "bufferView"}
        new_acc["bufferView"] = copy_view(acc["bufferView"])
        acc_i = len(char["accessors"])
        char["accessors"].append(new_acc)
        acc_cache[ai] = acc_i
        return acc_i

    animations = []
    for name in KEEP:
        src = by_name[name]
        samplers = []
        sampler_map = {}
        channels = []
        for ch in src["channels"]:
            bone = ual["nodes"][ch["target"]["node"]].get("name")
            if bone not in name_to_index:
                continue
            si = ch["sampler"]
            if si not in sampler_map:
                sm = src["samplers"][si]
                sampler_map[si] = len(samplers)
                samplers.append({
                    "input": copy_accessor(sm["input"]),
                    "output": copy_accessor(sm["output"]),
                    "interpolation": sm.get("interpolation", "LINEAR"),
                })
            channels.append({
                "sampler": sampler_map[si],
                "target": {"node": name_to_index[bone], "path": ch["target"]["path"]},
            })
        animations.append({"name": name, "channels": channels, "samplers": samplers})
        print(f"  {name}: {len(channels)} channels")
    char["animations"] = animations


def write_glb(js, blob, path: Path):
    js["buffers"] = [{"byteLength": len(blob)}]
    raw = json.dumps(js, separators=(",", ":")).encode("utf-8")
    while len(raw) % 4:
        raw += b" "
    bin_pad = bytearray(blob)
    while len(bin_pad) % 4:
        bin_pad.append(0)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, 0)
    out += struct.pack("<I4s", len(raw), b"JSON")
    out += raw
    out += struct.pack("<I4s", len(bin_pad), b"BIN\x00")
    out += bin_pad
    struct.pack_into("<I", out, 8, len(out))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(out)
    print(f"wrote {path} ({len(out) / 1024 / 1024:.2f} MB)")


def main():
    char, cblob = load_glb(CHAR)
    ual, ublob = load_glb(UAL)
    split_body(char, cblob)
    copy_anims(char, cblob, ual, ublob)
    write_glb(char, cblob, OUT)


if __name__ == "__main__":
    main()
