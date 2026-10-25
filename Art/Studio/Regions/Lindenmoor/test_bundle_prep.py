"""Tests for bundle_prep.py's freshness rule (Foundry Yard plan Task 9, Ruling 38).

python -I Art/Studio/Regions/Lindenmoor/test_bundle_prep.py

prep_ye.lua's undo reads no pad data (it moves everything back by its LindenmoorPrepFrom marks), so a
`prep <out> undo` bundle builds even while pads.json is stale; an apply bundle (and the test bundle) still refuses.
The stale case is made, not assumed: the test runs bundle_prep.py from a temporary copy of this folder whose pads.json
records a wrong hash for one input, so the committed pads.json and every output stay untouched (all output goes to the
temporary folder).
Prints PASS n / FAIL n; exits 1 on any failure.
"""
import json, os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PASSES, FAILS = [0], []


def check(name, ok, detail=""):
    if ok:
        PASSES[0] += 1
    else:
        FAILS.append(name)
        print("FAIL %s: %s" % (name, detail))


def run(folder, *args):
    r = subprocess.run([sys.executable, "-I", os.path.join(folder, "bundle_prep.py")] + list(args),
                       capture_output=True, text=True)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def main():
    with tempfile.TemporaryDirectory() as d:
        # bundle_prep.py resolves the repo as four folders up from itself: keep that depth
        folder = os.path.join(d, "a", "b", "c", "d")
        os.makedirs(folder)
        for name in ("bundle_prep.py", "prep_ye.lua", "test_prep.lua", "pads.json"):
            shutil.copy(os.path.join(HERE, name), folder)
        with open(os.path.join(folder, "pads.json"), encoding="utf-8") as f:
            pads = json.load(f)
        inputs = pads.get("Inputs") or {}
        check("pads.json records its inputs", bool(inputs), "no Inputs")
        # a stale pads.json: every recorded input hash is wrong (the inputs don't exist under the temp root either)
        pads["Inputs"] = {k: "0" * 64 for k in inputs} or {"Art/none.json": "0" * 64}
        with open(os.path.join(folder, "pads.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(pads, f, indent=1)

        out_u = os.path.join(d, "undo.lua")
        code, text = run(folder, "prep", out_u, "undo")
        check("an undo bundle builds while pads.json is stale", code == 0 and os.path.exists(out_u), text)
        body = open(out_u, encoding="utf-8").read() if os.path.exists(out_u) else ""
        check("the undo bundle is MODE undo", 'local MODE = "undo"' in body)
        check("the undo bundle still inlines pads.json (prep_ye.lua needs PADS_JSON to start)",
              "local PADS_JSON = [==[" in body and "local PADS_HASH = " in body)

        out_a = os.path.join(d, "apply.lua")
        code, text = run(folder, "prep", out_a, "apply")
        check("an apply bundle refuses while pads.json is stale", code != 0 and "stale" in text and not os.path.exists(out_a), text)
        out_t = os.path.join(d, "test.lua")
        code, text = run(folder, "test", out_t)
        check("the test bundle refuses while pads.json is stale", code != 0 and "stale" in text and not os.path.exists(out_t), text)
    print("PASS %d / FAIL %d" % (PASSES[0], len(FAILS)))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
