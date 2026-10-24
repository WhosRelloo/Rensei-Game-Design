"""Checks for the region kit (Task 11): python -I Art/Studio/Regions/test_kit.py [--lua <out.lua>]

Pure Python, no Studio. Prints PASS n / FAIL m. With --lua it also writes a Luau check of the chunks' tag rule
(studio_kit.TAGS_LUA, run with a stand-in CollectionService) against split_tags' answers: run that file in any
Studio place (Edit); it changes nothing and returns "tags rule ok: ..." or the first mismatch."""
import filecmp, json, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "Art", "Studio", "Lindenmoor"))
sys.path.insert(0, HERE)
import studio_kit as SK  # noqa: E402
import kit  # noqa: E402

FAILS, PASSES = [], [0]
TAG_CASES = ["", "A", "A,B", "A,,B", " A , B ", ",A,", "A, ,B", "  ", "A,A"]


def check(name, ok, detail=""):
    if ok:
        PASSES[0] += 1
    else:
        FAILS.append(f"{name}: {detail}")


def raises(fn, *a, **kw):
    try:
        fn(*a, **kw)
    except (ValueError, SystemExit):
        return True
    return False


def same_text(a, b):
    with open(a, encoding="utf-8", newline="") as f, open(b, encoding="utf-8", newline="") as g:
        return f.read().replace("\r\n", "\n") == g.read().replace("\r\n", "\n")


def main(argv):
    # tags: one rule (split on commas, trim, skip empty)
    want = {"": [], "A": ["A"], "A,B": ["A", "B"], "A,,B": ["A", "B"], " A , B ": ["A", "B"], ",A,": ["A"],
            "A, ,B": ["A", "B"], "  ": [], "A,A": ["A", "A"]}
    for s, w in want.items():
        check(f"split_tags({s!r})", SK.split_tags(s) == w, SK.split_tags(s))
    check("split_tags(non-string)", SK.split_tags(None) == [] and SK.split_tags(3) == [])

    # escaping
    check("lua_str plain", SK.lua_str("Testbed") == '"Testbed"')
    check("lua_str quotes and backslashes", SK.lua_str('a"b\\c') == '"a\\"b\\\\c"', SK.lua_str('a"b\\c'))
    check("lua_str control and unicode", SK.lua_str("a\nbé") == '"a\\u{a}b\\u{e9}"', SK.lua_str("a\nbé"))
    check("long_json refuses ]==]", raises(SK.long_json, ["x]==]y"]))
    check("long_json passes normal text", SK.long_json(["a", 1]) == '["a", 1]')

    # material validation
    base = {"name": "T", "materials": {"RG_T_a": {"Material": "Brick", "Color": "aabbcc", "Transparency": 0}},
            "no_collide": ()}
    check("region_mats accepts a good table", not raises(SK.region_mats, base))
    for bad, why in ((dict(base, name="1x"), "a bad region name"), (dict(base, name='T"'), "a quote in the name"),
                     (dict(base, materials={"k": {"Material": "Bricks", "Color": "aabbcc"}}), "an unknown material"),
                     (dict(base, materials={"k": {"Material": "Brick", "Color": "zzz"}}), "a bad colour"),
                     (dict(base, materials={"k": {"Material": "Brick", "Color": "aabbcc", "Transparency": 2}}),
                      "transparency 2"),
                     (dict(base, materials={"k": {"Material": "Brick", "Color": "aabbcc", "PackImage": "rbxassetid://1",
                                                  "StudsPerTile": 0}}), "StudsPerTile 0")):
        check(f"region_mats refuses {why}", raises(SK.region_mats, bad))
    t, v = SK.region_mats(dict(base, materials={"RG_T_p": {"Material": "Cobblestone", "Color": "5c5853",
                                                            "PackImage": "rbxassetid://9", "StudsPerTile": 8}}))
    check("a PackImage entry becomes a variant of the same name",
          v == [{"Name": "RG_T_p", "Base": "Cobblestone", "ColorMap": "rbxassetid://9", "Studs": 8}] and t["RG_T_p"][3] == "RG_T_p", v)
    check("every built-in material is an Enum.Material", all(m[0] in SK.ROBLOX_MATERIALS for m in SK.MATS.values()))

    # KeepMapChildren / MapChild (the top-level "Keep", Lindenmoor's area objects, is not read)
    check("keep_list: KeepMapChildren + --keep, trimmed, no repeats",
          kit.keep_list({"KeepMapChildren": ["Station"]}, " Spawns ,Station,,") == ["Station", "Spawns"])
    check("keep_list: none", kit.keep_list({}, None) == [])
    check("keep_list refuses an empty name", raises(kit.keep_list, {"KeepMapChildren": [""]}, None))
    lind = json.load(open(os.path.join(REPO, "Art", "Regions", "Lindenmoor", "layout.json"), encoding="utf-8"))
    check("Lindenmoor's own Keep (area objects) is ignored", "Keep" in lind and kit.keep_list(lind, None) == [])
    check("map_child defaults to the Region", kit.map_child({}, "Testbed", None, []) == "Testbed")
    check("map_child from the region file", kit.map_child({"MapChild": "TestbedExpansion"}, "Testbed", None, ["Testbed"])
          == "TestbedExpansion")
    check("--map-child wins", kit.map_child({"MapChild": "A"}, "Testbed", "B", []) == "B")
    check("map_child refuses a kept name", raises(kit.map_child, {}, "Testbed", None, ["Testbed"]))
    check("map_child refuses a bad name", raises(kit.map_child, {"MapChild": "Two words"}, "Testbed", None, []))

    # final review I4: the walk-through lists are per region
    check("no_collide: a region_builder region defaults to (Glass, Glow), no kinds",
          kit.no_collide({}, "Testbed") == (("Glass", "Glow"), ()))
    check("no_collide: Lindenmoor defaults to the village's own lists (EdgeStone kind, Tuft, Crop, Vine, Lantern)",
          kit.no_collide(lind, "Lindenmoor") == (SK.NO_COLLIDE, SK.NO_COLLIDE_KINDS)
          and SK.NO_COLLIDE_KINDS == ("EdgeStone",) and all(n in SK.NO_COLLIDE for n in ("Tuft", "Crop", "Vine", "Lantern")))
    check("no_collide: the region file's NoCollide / NoCollideKinds win over the default",
          kit.no_collide({"NoCollide": ["Glass", " Fern "], "NoCollideKinds": ["Hedge"]}, "Lindenmoor") == (("Glass", "Fern"), ("Hedge",)))
    check("no_collide: --no-collide / --no-collide-kinds win over the file, '-' = none",
          kit.no_collide({"NoCollide": ["Glass"]}, "Testbed", "Tuft, Crop", "-") == (("Tuft", "Crop"), ()))
    check("no_collide: an empty NoCollide list = none", kit.no_collide({"NoCollide": []}, "Testbed") == ((), ()))
    check("no_collide refuses a bad list", raises(kit.no_collide, {"NoCollide": "Glass"}, "Testbed")
          and raises(kit.no_collide, {"NoCollide": ["Glass", ""]}, "Testbed") and raises(kit.no_collide, {}, "Testbed", ",,"))
    check("offset: three numbers", kit.offset("4000,0,-12.5") == [4000, 0, -12.5] and kit.offset(None) is None
          and raises(kit.offset, "1,2"))

    # final review I5 / Minor 5: the templates' dry-run keep report, marker check and ChangeHistory recording
    fin = open(kit.TEMPLATES["finish.lua"], encoding="utf-8").read()
    dry = fin[fin.index("if Dry then"):fin.index("-- the real run: every refusal comes before the first change")]
    check("finish: the dry run checks KEEP like the real run and lists would-move / would-keep",
          "pcall(KeepCheck)" in dry and "a real run would move" in dry and "KProblems" in dry
          and "local KProblems, _, _, Map = KeepCheck()" in fin)
    check("finish: the dry run fails a non-empty KEEP checked in another place",
          "#KEEP > 0 and game.PlaceId ~= PLACE_ID" in dry)
    check("finish: the markers' collision / query / touch are checked", "EXPECTED.helpers" in fin and "D.CanQuery" in fin)
    res = open(kit.TEMPLATES["restore.lua"], encoding="utf-8").read()
    for name, src in (("finish", fin), ("restore", res)):
        check(f"{name}: the swap is recorded with ChangeHistoryService",
              "TryBeginRecording" in src and "FinishRecording" in src and src.count("EndRecording()") == 3)

    # bundle_setup: --region / --map-child / --origin set the three lines in the bundle only
    import bundle_setup as BS
    src = BS.setup_source(BS.options(["--region", "Lindenmoor", "--map-child", "LindenmoorExpansion", "--origin", "0,0,0"]))
    check("bundle_setup sets REGION, MAP_CHILD and ORIGIN",
          'local REGION = "Lindenmoor"' in src and 'local MAP_CHILD = "LindenmoorExpansion"' in src
          and "local ORIGIN = Vector3.new(0.0, 0.0, 0.0)" in src and "local ORIGIN = Vector3.zero" not in src)
    check("bundle_setup without options keeps setup.lua as it is", BS.setup_source({}) == BS.read("setup.lua"))
    check("bundle_setup refuses a bad option", raises(BS.options, ["--origin", "1,2"]) and raises(BS.options, ["--map", "X"])
          and raises(BS.options, ["--map-child", "Two words"]))

    with tempfile.TemporaryDirectory() as d:
        # Lindenmoor and the train: the command-line run is unchanged (outputs equal the committed ones)
        for name in ("Lindenmoor", "Train"):
            src = os.path.join(REPO, "Art", "Studio", name)
            tmp = os.path.join(d, name)
            os.makedirs(tmp)
            shutil.copy(os.path.join(src, "layout.json"), tmp)
            SK.main(tmp)
            files = sorted(os.listdir(os.path.join(tmp, "import")))
            ok = all(same_text(os.path.join(tmp, "import", f), os.path.join(src, "import", f)) for f in files)
            cmp = filecmp.dircmp(os.path.join(tmp, "kit"), os.path.join(src, "kit"))
            kit_same = all(same_text(os.path.join(r, f), os.path.join(r.replace(os.path.join(tmp, "kit"), os.path.join(src, "kit")), f))
                           for r, _, fs in os.walk(os.path.join(tmp, "kit")) for f in fs)
            check(f"{name}: import/ outputs unchanged", ok, files)
            check(f"{name}: kit/ outputs unchanged", kit_same and not cmp.left_only, cmp.left_only)
        # the Testbed region run reproduces the committed chunk and expected.json
        tmp = os.path.join(d, "Testbed")
        os.makedirs(tmp)
        shutil.copy(os.path.join(HERE, "Testbed", "layout.json"), tmp)
        mats = json.load(open(os.path.join(REPO, "Art", "Regions", "Testbed", "materials.json"), encoding="utf-8"))
        out = SK.main(tmp, region={"name": "Testbed", "materials": mats, "no_collide": kit.NO_COLLIDE,
                                   "no_collide_kinds": kit.NO_COLLIDE_KINDS})
        for f in ("chunk_01.lua", "expected.json"):
            check(f"Testbed: {f} reproduces", same_text(os.path.join(tmp, "import", f), os.path.join(HERE, "Testbed", "import", f)))
        exp = out["expected"]
        check("Testbed: expected tags", exp["tags"] == {"RenseiLedge": 4, "RenseiNoGrip": 62, "RenseiArea": 1, "RenseiClue": 1,
                                                        "RenseiPost": 2}, exp["tags"])
        check("Testbed: RenseiNoGrip on every Edges part", exp["tagsByGroup"]["RenseiNoGrip"] == {"Edges": exp["groupParts"]["Edges"]})
        check("Testbed: variant parts", exp["variantParts"] == {"RG_Testbed_path": 37}, exp["variantParts"])
        chunk = open(os.path.join(tmp, "import", "chunk_01.lua"), encoding="utf-8").read()
        check("Testbed chunk carries the tag rule", SK.TAGS_LUA in chunk)
        # final review I3: region markers get no collision, queries or touches, except MARKER_ACCESS's tags
        check("Testbed chunk: markers query/touch off", SK.REGION_HELPER_LUA in chunk and SK.HELPER_LUA not in chunk
              and SK.ACCESS_LUA in chunk and "local MARKER_ACCESS = HS:JSONDecode(" in chunk)
        check("Testbed: expected markers (4, none queryable or touchable)",
              exp["helpers"] == {"parts": 4, "query": 0, "touch": 0}, exp.get("helpers"))
        check("MARKER_ACCESS: only RenseiLedge (query) and RenseiStationGate (touch)",
              SK.MARKER_ACCESS == {"RenseiLedge": {"CanQuery": True}, "RenseiStationGate": {"CanTouch": True}})
        check("helper_access: area off, ledge query, gate touch, both",
              SK.helper_access([0] * 13 + [1, "", "RenseiArea"]) == (False, False)
              and SK.helper_access([0] * 13 + [1, "", "RenseiLedge"]) == (True, False)
              and SK.helper_access([0] * 13 + [1, "", " RenseiStationGate "]) == (False, True)
              and SK.helper_access([0] * 13 + [1, "", "RenseiLedge,RenseiStationGate"]) == (True, True))
        lin = open(os.path.join(REPO, "Art", "Studio", "Lindenmoor", "import", "chunk_01.lua"), encoding="utf-8").read()
        trn = open(os.path.join(REPO, "Art", "Studio", "Train", "import", "chunk_01.lua"), encoding="utf-8").read()
        check("Lindenmoor and Train chunks keep the train helper rule (query/touch on)",
              SK.HELPER_LUA in lin and SK.HELPER_LUA in trn and "MARKER_ACCESS" not in lin + trn)
        check("Testbed: the walk-through lists are in expected.json",
              exp["noCollide"] == ["Glass", "Glow"] and exp["noCollideKinds"] == [], (exp.get("noCollide"), exp.get("noCollideKinds")))
        lay_h = json.load(open(os.path.join(tmp, "layout.json"), encoding="utf-8"))
        lay_h["prefabs"][-1]["p"].append([f"Gate", 0, 0, 2, 2, 2, 0, 0, 0, 0, 0, 0, 1, 1, "", "RenseiStationGate"])
        lay_h["prefabs"][-1]["p"].append([f"Ledge", 0, 0, 2, 2, 2, 0, 0, 0, 0, 0, 0, 1, 1, "", "RenseiLedge,RenseiArea"])
        json.dump(lay_h, open(os.path.join(tmp, "layout.json"), "w", encoding="utf-8"))
        e3 = SK.main(tmp, region={"name": "Testbed", "materials": mats, "no_collide": kit.NO_COLLIDE})["expected"]
        check("expected markers count the exceptions", e3["helpers"] == {"parts": 6, "query": 1, "touch": 1}, e3["helpers"])
        shutil.copy(os.path.join(HERE, "Testbed", "layout.json"), tmp)
        # a messy field 16 is counted with the rule
        lay = json.load(open(os.path.join(tmp, "layout.json"), encoding="utf-8"))
        lay["prefabs"][0]["p"][0] = lay["prefabs"][0]["p"][0][:13] + [0, "", " X ,,Y, X"]
        json.dump(lay, open(os.path.join(tmp, "layout.json"), "w", encoding="utf-8"))
        e2 = SK.main(tmp, region={"name": "Testbed", "materials": mats, "no_collide": kit.NO_COLLIDE})["expected"]
        check("a messy field 16 counts each trimmed tag once per part", e2["tags"].get("X") == 1 and e2["tags"].get("Y") == 1
              and "" not in e2["tags"] and " X " not in e2["tags"], e2["tags"])
        # the templates fill completely
        fill = {"{{REGION}}": '"T"', "{{REGION_TEXT}}": "T", "{{PLACE_ID}}": "0", "{{GENERATED}}": '"2026-10-24"',
                "{{GENERATED_TEXT}}": "2026-10-24", "{{EXPECTED}}": "{}", "{{WATER}}": "[]", "{{KEEP}}": "[]", "{{ORIGIN}}": "0, 0, 0",
                "{{MAPCHILD}}": '"T"', "{{MAPCHILD_TEXT}}": "T"}
        for name, path in kit.TEMPLATES.items():
            check(f"{name} template fills every slot", not raises(kit.fill_template, path, fill))
        # a test run (--out, --offset): the scripts go elsewhere, the committed import/ is untouched, everything moves
        before = {f: open(os.path.join(HERE, "Testbed", "import", f), encoding="utf-8").read()
                  for f in os.listdir(os.path.join(HERE, "Testbed", "import"))}
        smoke = os.path.join(d, "smoke")
        o = kit.main(["Testbed", "--place", "109591196441030", "--map-child", "TestbedSmoke", "--keep", "Foundry",
                      "--offset", "4000,0,4000", "--out", smoke, "--date", "2026-10-24"])
        after = {f: open(os.path.join(HERE, "Testbed", "import", f), encoding="utf-8").read()
                 for f in os.listdir(os.path.join(HERE, "Testbed", "import"))}
        sfin = open(os.path.join(smoke, "import", "finish.lua"), encoding="utf-8").read()
        sch = open(os.path.join(smoke, "import", "chunk_01.lua"), encoding="utf-8").read()
        check("--out leaves the committed Testbed import as it was", before == after)
        check("--offset moves the origin (parts and water) and --place / --keep / --map-child reach finish.lua",
              o["origin"] == [4000, 0, 4000] and "local ORIGIN = Vector3.new(4000, 0, 4000)" in sfin
              and "local O = Vector3.new(4000, 0, 4000)" in sch and '"TestbedSmoke"' in sfin and '["Foundry"]' in sfin
              and "109591196441030" in sfin)
        check("--offset without --out is refused", raises(kit.main, ["Testbed", "--offset", "1,2,3"]))

    if "--lua" in argv:
        rows = [[0] * 13 + [0, "", s] for s in TAG_CASES]
        expect = [list(dict.fromkeys(SK.split_tags(s))) for s in TAG_CASES]
        lua = ("-- generated by Art/Studio/Regions/test_kit.py: the chunks' tag rule against split_tags (changes nothing)\n"
               "local HS = game:GetService(\"HttpService\")\n"
               f"local ROWS = HS:JSONDecode([==[{SK.long_json(rows)}]==])\n"
               f"local WANT = HS:JSONDecode([==[{SK.long_json(expect)}]==])\n"
               "for I, P in ipairs(ROWS) do\n"
               "\tlocal Got = {}\n"
               "\tlocal CS = {AddTag = function(_, _, T) if not table.find(Got, T) then table.insert(Got, T) end end}\n"
               "\tlocal Part = nil\n"
               + SK.TAGS_LUA +
               "\tif HS:JSONEncode(Got) ~= HS:JSONEncode(WANT[I]) then\n"
               "\t\treturn (\"tags rule MISMATCH on %q: lua %s, python %s\"):format(P[16], HS:JSONEncode(Got), HS:JSONEncode(WANT[I]))\n"
               "\tend\n"
               "end\n"
               "return \"tags rule ok: \" .. #ROWS .. \" cases agree with split_tags\"\n")
        out = argv[argv.index("--lua") + 1]
        with open(out, "w", encoding="utf-8") as f:
            f.write(lua)
        print("wrote", out)

    for f in FAILS:
        print("FAIL", f)
    print(f"PASS {PASSES[0]} / FAIL {len(FAILS)}")
    return not FAILS


if __name__ == "__main__":
    sys.exit(0 if main(sys.argv[1:]) else 1)
