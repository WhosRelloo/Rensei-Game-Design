"""Run the read-only Ye survey end to end:  python -I Art/Studio/Regions/Lindenmoor/run_survey.py

1. runs survey_ye.lua in Ye (Edit) through the bridge, which writes ServerStorage.LMSurvey;
2. reads LMSurvey back in 25k-character chunks (the bridge prints only 30k), cut on UTF-8 character boundaries;
3. writes ye_survey.json next to this file;
4. destroys ServerStorage.LMSurvey and checks it is gone.
It then prints a one-line summary; run check_survey.py ye_survey.json to check it. Never touches any other Studio.

python -I run_survey.py --seam
    runs the same read-only survey but writes only its SeamHeights and SeamNewTops (Ruling 21) to seam_survey.json,
    leaving ye_survey.json (the pre-import baseline that check_survey.py and make_pads.py read) untouched. It also
    reports whether GroundFootprint still matches the stored one.
"""
import json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
RBXC = os.path.join(REPO, "Art", "Tools", "rbxc.py")
STUDIO = "placeId: 106992859583940"  # Ye
SURVEY = os.path.join(HERE, "survey_ye.lua")
OUT = os.path.join(HERE, "ye_survey.json")
CHUNK = 25000
SEAM_OUT = os.path.join(HERE, "seam_survey.json")
SEAM_NOTE = ("Ruling 21 seam measurement, read-only, taken in Ye after the import by survey_ye.lua through run_survey.py "
             "--seam. SeamHeights: [cx, cz, y, hits, ring] for footprint cells within 2 cells of a non-footprint cell, "
             "y = Ye's real top (rays filtered to World.Map.Ground + HalvardsAdit; -999 = fewer than 3 of 5 rays hit). "
             "SeamNewTops: [cx, cz, y] for non-footprint cells bordering the footprint, against "
             "World.Map.LindenmoorExpansion.Ground. Cells are 4-stud world cells by their min corner.")

READ = """local v = game:GetService("ServerStorage"):FindFirstChild("LMSurvey")
if not v then return "@@ERR@@no LMSurvey" end
local s, a = v.Value, %d
local b = math.min(a + %d - 1, #s)
while b < #s and bit32.band(string.byte(s, b + 1), 0xC0) == 0x80 do b -= 1 end -- don't split a UTF-8 character
return "@@" .. #s .. "@@" .. (b + 1) .. "@@" .. string.sub(s, a, b) .. "@@END@@"
"""
CLEAN = """local ss = game:GetService("ServerStorage")
local v = ss:FindFirstChild("LMSurvey")
if v then v:Destroy() end
return "@@LMSurvey=" .. tostring(ss:FindFirstChild("LMSurvey")) .. "@@"
"""


def luau(code_or_path, tmp):
    path = code_or_path
    if not os.path.exists(code_or_path):
        path = os.path.join(tmp, "snippet.lua")
        with open(path, "w", encoding="utf-8") as f:
            f.write(code_or_path)
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    r = subprocess.run([sys.executable, "-I", RBXC, "luau", STUDIO, "Edit", "@" + path],
                       capture_output=True, text=True, encoding="utf-8", env=env, timeout=900)
    if r.returncode != 0 or "(isError)" in r.stdout:
        raise SystemExit(f"bridge error:\n{r.stdout}\n{r.stderr}")
    return r.stdout


def main():
    with tempfile.TemporaryDirectory() as tmp:
        try:
            first = luau(SURVEY, tmp)
            if "LMSurvey written" not in first:
                raise SystemExit("survey did not run: " + first.strip()[:500])
            parts, a, total = [], 1, None
            while total is None or a <= total:
                out = luau(READ % (a, CHUNK), tmp)
                m = re.search(r"@@(\d+)@@(\d+)@@(.*)@@END@@", out, re.S)
                if not m:
                    raise SystemExit("bad chunk: " + out.strip()[:500])
                total, a = int(m.group(1)), int(m.group(2))
                parts.append(m.group(3))
            text = "".join(parts)
            if len(text.encode("utf-8")) != total:
                raise SystemExit(f"read {len(text.encode('utf-8'))} bytes, expected {total}")
            data = json.loads(text)
        finally:
            gone = luau(CLEAN, tmp)
        if "@@LMSurvey=nil@@" not in gone:
            raise SystemExit("LMSurvey was not removed: " + gone.strip()[:300])
    if sys.argv[1:] == ["--seam"]:
        with open(OUT, encoding="utf-8") as f:
            same = json.load(f).get("GroundFootprint") == data.get("GroundFootprint")
        seam = {"Note": SEAM_NOTE, "SeamHeights": data["SeamHeights"], "SeamNewTops": data["SeamNewTops"]}
        with open(SEAM_OUT, "w", encoding="utf-8", newline="\n") as f:
            json.dump(seam, f, separators=(",", ":"))
            f.write("\n")
        print(f"seam_survey.json written: {len(seam['SeamHeights'])} Ye seam cells, {len(seam['SeamNewTops'])} new seam "
              f"cells; GroundFootprint unchanged: {same}; LMSurvey removed")
        return
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print(f"ye_survey.json written ({total} bytes in {len(parts)} chunk(s)); Parts {data['Parts']}, "
          f"{len(data['MapChildren'])} map children, GroundInInfill {data['GroundInInfill']}; LMSurvey removed")


if __name__ == "__main__":
    main()
