#!/usr/bin/env python3
"""Clothed militia: peasant clothes + superhero head + buzz cut, on the UAL skeleton."""
from __future__ import annotations

import io
import json
import struct
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/militia_male.glb"
OUTFITS = Path("/tmp/cc0/outfits.zip")
BASE = Path("/tmp/cc0/basechars.zip")
ANIMS = ROOT / "assets/characters/militia_male.glb"
PEASANT = "Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits/"
SUPER = "Universal Base Characters[Standard]/Base Characters/Godot - UE/"
HAIR = "Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/"


def load_glb(path: Path):
    data = path.read_bytes()
    clen, ctype = struct.unpack_from("<I4s", data, 12)
    js = json.loads(data[20 : 20 + clen])
    off = 20 + clen
    while off % 4:
        off += 1
    blen, btype = struct.unpack_from("<I4s", data, off)
    blob = bytearray(data[off + 8 : off + 8 + blen])
    return js, blob


def load_gltf_zip(z: zipfile.ZipFile, gltf_path: str, bin_name: str | None = None):
    js = json.loads(z.read(gltf_path))
    folder = gltf_path.rsplit("/", 1)[0] + "/"
    uri = js["buffers"][0].get("uri")
    if bin_name:
        uri = bin_name
    blob = bytearray(z.read(folder + uri))
    return js, blob, folder


def png_bytes(im: Image.Image, size: int) -> bytes:
    im = im.convert("RGBA")
    im.thumbnail((size, size), Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def align(blob: bytearray) -> None:
    while len(blob) % 4:
        blob.append(0)


class Copier:
    def __init__(self, dst_js, dst_blob, src_js, src_blob):
        self.dst_js = dst_js
        self.dst_blob = dst_blob
        self.src_js = src_js
        self.src_blob = src_blob
        self.views = {}
        self.accs = {}

    def copy_view(self, view_index: int) -> int:
        if view_index in self.views:
            return self.views[view_index]
        view = self.src_js["bufferViews"][view_index]
        start = view.get("byteOffset", 0)
        length = view["byteLength"]
        align(self.dst_blob)
        off = len(self.dst_blob)
        self.dst_blob.extend(self.src_blob[start : start + length])
        entry = {"buffer": 0, "byteOffset": off, "byteLength": length}
        if "byteStride" in view:
            entry["byteStride"] = view["byteStride"]
        if "target" in view:
            entry["target"] = view["target"]
        idx = len(self.dst_js["bufferViews"])
        self.dst_js["bufferViews"].append(entry)
        self.views[view_index] = idx
        return idx

    def copy_accessor(self, ai: int) -> int:
        if ai in self.accs:
            return self.accs[ai]
        acc = self.src_js["accessors"][ai]
        new_acc = {k: v for k, v in acc.items() if k != "bufferView"}
        if "bufferView" in acc:
            new_acc["bufferView"] = self.copy_view(acc["bufferView"])
        idx = len(self.dst_js["accessors"])
        self.dst_js["accessors"].append(new_acc)
        self.accs[ai] = idx
        return idx


def read_scalar(js, blob, ai):
    acc = js["accessors"][ai]
    view = js["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or {5121: 1, 5123: 2, 5125: 4}[acc["componentType"]]
    ctype = acc["componentType"]
    fmt = {5121: "<B", 5123: "<H", 5125: "<I"}[ctype]
    step = struct.calcsize(fmt)
    out = []
    for i in range(acc["count"]):
        out.append(struct.unpack_from(fmt, blob, start + i * max(stride, step))[0])
    return out


def read_joints_weights(js, blob, prim):
    jai = prim["attributes"]["JOINTS_0"]
    wai = prim["attributes"]["WEIGHTS_0"]
    jacc = js["accessors"][jai]
    wacc = js["accessors"][wai]
    jview = js["bufferViews"][jacc["bufferView"]]
    wview = js["bufferViews"][wacc["bufferView"]]
    jstart = jview.get("byteOffset", 0) + jacc.get("byteOffset", 0)
    wstart = wview.get("byteOffset", 0) + wacc.get("byteOffset", 0)
    jstride = jview.get("byteStride") or 4
    wstride = wview.get("byteStride") or 16
    jfmt = {5121: "<4B", 5123: "<4H"}[jacc["componentType"]]
    joints = []
    weights = []
    for i in range(jacc["count"]):
        joints.append(struct.unpack_from(jfmt, blob, jstart + i * jstride))
        weights.append(struct.unpack_from("<4f", blob, wstart + i * wstride))
    return joints, weights


def head_indices(js, blob, prim) -> list[int]:
    """Triangles whose strongest influence is the head or neck."""
    joints, weights = read_joints_weights(js, blob, prim)
    # Universal rig: neck_01 = 5, Head = 6.
    keep_bones = {5, 6}
    indices = read_scalar(js, blob, prim["indices"])
    out = []
    for t in range(0, len(indices), 3):
        tri = indices[t : t + 3]
        hit = False
        for vi in tri:
            js_ = joints[vi]
            ws = weights[vi]
            bone = js_[max(range(4), key=lambda k: ws[k])]
            if bone in keep_bones and ws[max(range(4), key=lambda k: ws[k])] > 0.45:
                hit = True
                break
        if hit:
            out.extend(tri)
    return out


def add_index_buffer(js, blob, indices: list[int]) -> int:
    raw = struct.pack("<" + "I" * len(indices), *indices)
    align(blob)
    off = len(blob)
    blob.extend(raw)
    view_i = len(js["bufferViews"])
    js["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(raw), "target": 34963})
    acc_i = len(js["accessors"])
    js["accessors"].append({
        "bufferView": view_i,
        "componentType": 5125,
        "count": len(indices),
        "type": "SCALAR",
    })
    return acc_i


def add_mesh_node(js, mesh_name: str, prims: list, skin: int = 0) -> None:
    mi = len(js["meshes"])
    js["meshes"].append({"name": mesh_name, "primitives": prims})
    ni = len(js["nodes"])
    js["nodes"].append({"name": mesh_name, "mesh": mi, "skin": skin})
    js["scenes"][0]["nodes"].append(ni)


def embed_png(js, blob, png: bytes, name: str) -> int:
    align(blob)
    off = len(blob)
    blob.extend(png)
    view_i = len(js["bufferViews"])
    js["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(png)})
    ii = len(js["images"])
    js["images"].append({"mimeType": "image/png", "name": name, "bufferView": view_i})
    return ii


def write_glb(js, blob, path: Path) -> None:
    js["buffers"] = [{"byteLength": len(blob)}]
    raw = json.dumps(js, separators=(",", ":")).encode("utf-8")
    while len(raw) % 4:
        raw += b" "
    align(blob)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, 0)
    out += struct.pack("<I4s", len(raw), b"JSON")
    out += raw
    out += struct.pack("<I4s", len(blob), b"BIN\x00")
    out += blob
    struct.pack_into("<I", out, 8, len(out))
    path.write_bytes(out)
    print(f"wrote {path} ({len(out) / 1024 / 1024:.2f} MB)")


def copy_anims(char, cblob, ual, ublob) -> None:
    name_to_index = {n.get("name"): i for i, n in enumerate(char["nodes"]) if n.get("name")}
    view_cache = {}
    acc_cache = {}

    def copy_view(view_index):
        if view_index in view_cache:
            return view_cache[view_index]
        view = ual["bufferViews"][view_index]
        start = view.get("byteOffset", 0)
        length = view["byteLength"]
        align(cblob)
        off = len(cblob)
        cblob.extend(ublob[start : start + length])
        entry = {"buffer": 0, "byteOffset": off, "byteLength": length}
        if "byteStride" in view:
            entry["byteStride"] = view["byteStride"]
        char["bufferViews"].append(entry)
        view_cache[view_index] = len(char["bufferViews"]) - 1
        return view_cache[view_index]

    def copy_accessor(ai):
        if ai in acc_cache:
            return acc_cache[ai]
        acc = ual["accessors"][ai]
        new_acc = {k: v for k, v in acc.items() if k != "bufferView"}
        new_acc["bufferView"] = copy_view(acc["bufferView"])
        char["accessors"].append(new_acc)
        acc_cache[ai] = len(char["accessors"]) - 1
        return acc_cache[ai]

    animations = []
    for src in ual["animations"]:
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
        animations.append({"name": src["name"], "channels": channels, "samplers": samplers})
        print(f"  {src['name']}: {len(channels)} channels")
    char["animations"] = animations


def main() -> None:
    oz = zipfile.ZipFile(OUTFITS)
    bz = zipfile.ZipFile(BASE)
    peasant, pblob, _ = load_gltf_zip(oz, PEASANT + "Male_Peasant.gltf")
    super_js, sblob, _ = load_gltf_zip(bz, SUPER + "Superhero_Male_FullBody.gltf")
    hair_js, hblob, _ = load_gltf_zip(bz, HAIR + "Hair_Buzzed.gltf")

    # Drop the huge normal maps. Clothes and skin stay on albedo + roughness.
    # Peasant arms already use MI_Regular_Male (material 1) for bare skin.
    peasant["images"] = []
    cloth_alb = embed_png(peasant, pblob, png_bytes(Image.open(io.BytesIO(oz.read(PEASANT + "T_Peasant_BaseColor.png"))), 1024), "cloth")
    cloth_orm = embed_png(peasant, pblob, png_bytes(Image.open(io.BytesIO(oz.read(PEASANT + "T_Peasant_ORM.png"))), 512), "cloth_orm")
    arm_skin = embed_png(peasant, pblob, png_bytes(Image.open(io.BytesIO(oz.read(PEASANT + "T_Regular_Male_Dark_BaseColor.png"))), 512), "arm_skin")
    arm_rough = embed_png(peasant, pblob, png_bytes(Image.open(io.BytesIO(oz.read(PEASANT + "T_Regular_Male_Roughness.png"))), 256), "arm_rough")
    face_png = png_bytes(Image.open(io.BytesIO(bz.read(SUPER + "T_Superhero_Male_Dark.png"))), 512)
    face_img = embed_png(peasant, pblob, face_png, "face")
    face_rough = embed_png(peasant, pblob, png_bytes(Image.open(io.BytesIO(bz.read(SUPER + "T_Superhero_Male_Roughness.png"))), 256), "face_rough")
    eye_img = embed_png(peasant, pblob, bz.read(SUPER + "T_Eye_Brown.png"), "eye")
    hair_img = embed_png(peasant, pblob, png_bytes(Image.open(io.BytesIO(bz.read(HAIR + "T_Hair_1_BaseColor.png"))), 256), "hair")
    peasant["textures"] = [{"source": i} for i in range(8)]
    peasant["materials"] = [
        {
            "name": "Cloth",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 0},
                "metallicRoughnessTexture": {"index": 1},
            },
        },
        {
            "name": "Skin",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 2},
                "metallicRoughnessTexture": {"index": 3},
                "metallicFactor": 0.0,
            },
        },
        {
            "name": "Face",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 4},
                "metallicRoughnessTexture": {"index": 5},
                "metallicFactor": 0.0,
            },
        },
        {
            "name": "Eyes",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 6},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.25,
            },
        },
        {
            "name": "Hair",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 7},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.7,
            },
        },
    ]
    _ = (cloth_alb, cloth_orm, arm_skin, arm_rough, face_img, face_rough, eye_img, hair_img)

    body = super_js["meshes"][2]
    prim = body["primitives"][0]
    kept = head_indices(super_js, sblob, prim)
    print(f"head triangles {len(kept) // 3}")
    copier = Copier(peasant, pblob, super_js, sblob)
    attrs = {k: copier.copy_accessor(v) for k, v in prim["attributes"].items()}
    add_mesh_node(peasant, "HeadSkin", [{
        "attributes": attrs,
        "indices": add_index_buffer(peasant, pblob, kept),
        "material": 2,
        "mode": 4,
    }])
    # Eyes and eyebrows, full meshes.
    for mesh_i, mat_i, label in ((1, 2, "Eyes"), (0, 3, "Eyebrows")):
        mesh = super_js["meshes"][mesh_i]
        # Eyebrows should use the hair/brow texture if they were hair material; mesh 0 is eyebrows using hair mat.
        use_mat = 3 if label == "Eyes" else 4
        prims = []
        sub = Copier(peasant, pblob, super_js, sblob)
        for sp in mesh["primitives"]:
            prims.append({
                "attributes": {k: sub.copy_accessor(v) for k, v in sp["attributes"].items()},
                "indices": sub.copy_accessor(sp["indices"]),
                "material": use_mat,
                "mode": sp.get("mode", 4),
            })
        add_mesh_node(peasant, label, prims)
        _ = mat_i

    hair_mesh = hair_js["meshes"][0]
    hcopier = Copier(peasant, pblob, hair_js, hblob)
    hprims = []
    for sp in hair_mesh["primitives"]:
        hprims.append({
            "attributes": {k: hcopier.copy_accessor(v) for k, v in sp["attributes"].items()},
            "indices": hcopier.copy_accessor(sp["indices"]),
            "material": 4,
            "mode": sp.get("mode", 4),
        })
    add_mesh_node(peasant, "Hair", hprims)

    anim_js, anim_blob = load_glb(ANIMS)
    copy_anims(peasant, pblob, anim_js, anim_blob)
    write_glb(peasant, pblob, OUT)


if __name__ == "__main__":
    main()
