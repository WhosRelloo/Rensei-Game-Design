"""Style kits (spec 2026-10-23 §3.3): building and landmark generators, one module per region style.

A layout names a piece "<kit>.<piece>": a district's Style ("railtown.house") or a landmark's Kind
("railtown.practice_court"). piece(name) returns the kit module, the piece's entry and whether it is a style
(a building: (root, rng, w, d, storeys) -> parts) or a landmark ((root, rng) -> parts). Blender only: the kits build
with lindenmoor.core's primitives. bind(palette) gives every kit the region's materials before a stage builds."""
from . import railtown

KITS = {"railtown": railtown}


def bind(palette):
    for k in KITS.values():
        k.bind(palette)


def piece(name):
    """(kit module, entry, "style" | "landmark") for "<kit>.<piece>"; raises ValueError for an unknown name."""
    kit, _, p = str(name).partition(".")
    mod = KITS.get(kit)
    if mod is None:
        raise ValueError(f"unknown kit {kit!r} in {name!r} (kits: {', '.join(KITS)})")
    if p in mod.STYLES:
        return mod, mod.STYLES[p], "style"
    if p in mod.LANDMARKS:
        return mod, mod.LANDMARKS[p], "landmark"
    raise ValueError(f"{name!r}: {kit} has no piece {p!r} (styles: {', '.join(mod.STYLES)}; "
                     f"landmarks: {', '.join(mod.LANDMARKS)})")


def kit_of(layout):
    """The region's kit: its first district's or landmark's kit, else railtown (under-route tunnels use it)."""
    for item in list(layout.get("Districts") or []) + list(layout.get("Landmarks") or []):
        name = item.get("Style") or item.get("Kind") or ""
        if name.partition(".")[0] in KITS:
            return KITS[name.partition(".")[0]]
    return railtown
