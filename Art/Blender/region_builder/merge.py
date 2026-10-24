"""Greedy rectangle merge of equal-keyed cells, as ground.lua v4 merges its slabs. No bpy; standard library only."""


def rects(cells, max_span=40):
    """cells: {(i, k): key}. Returns [(i0, k0, w, d, key)] covering every cell exactly once.

    Scans rows (k, then i), extends the width along i while the key matches, then the depth along k while the
    whole row of that width matches, each up to max_span cells."""
    if max_span < 1:
        raise ValueError("max_span must be at least 1")
    used = set()
    out = []
    for k0, i0 in sorted((k, i) for i, k in cells):
        if (i0, k0) in used:
            continue
        key = cells[(i0, k0)]

        def same(i, k):
            return (i, k) not in used and (i, k) in cells and cells[(i, k)] == key

        w = 1
        while w < max_span and same(i0 + w, k0):
            w += 1
        d = 1
        while d < max_span and all(same(i, k0 + d) for i in range(i0, i0 + w)):
            d += 1
        for i in range(i0, i0 + w):
            for k in range(k0, k0 + d):
                used.add((i, k))
        out.append((i0, k0, w, d, key))
    return out
