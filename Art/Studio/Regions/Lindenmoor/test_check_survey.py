"""Tests for check_survey.py: hand-made surveys in a temporary directory, run through the real checker.
python -I Art/Studio/Regions/Lindenmoor/test_check_survey.py"""
import copy, json, math, os, subprocess, sys, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CHECKER = os.path.join(HERE, "check_survey.py")
LAYOUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "Regions", "Lindenmoor", "layout.json"))
sys.path.insert(0, HERE)
import pad_layout  # noqa: E402
SITE_NAMES = ["BurnedLaboratory", "AshPit", "FrozenStation", "FrozenChamber", "CrackedFootbridge", "UnstableQuarry",
              "SilentObservatory", "GaleFloor", "SilentForge", "ForgeFloor", "FoundryYard", "LedgeCourse", "Wall",
              "Wall", "Curve", "Hill", "Step", "TrainingGround"]


def child(name, x=0, z=0, half=5, parts=10, cls="Model"):
    return {"Name": name, "Class": cls, "Parts": parts, "Pivot": [x, 0, z],
            "Box": [[x - half, 0, z - half], [x + half, 10, z + half]]}


def layout(arena_radius=50):
    """The real layout, plus res_test_arena (Ruling 5) if Task 2 hasn't added it yet."""
    with open(LAYOUT, encoding="utf-8") as f:
        L = json.load(f)
    if not any(lm["Id"] == "res_test_arena" for lm in L["Landmarks"]):
        L["Landmarks"].append({"Id": "res_test_arena", "Kind": "lindenmoor.reserve", "At": [0, 0],
                               "Radius": arena_radius})
    return L


def set_radius(L, pad, r):
    for lm in L["Landmarks"]:
        if lm["Id"] == pad:
            lm["Radius"] = r
    return L


def big_wall(s):
    """Grow the first Wall to 120 x 120 (the second stays)."""
    i = next(i for i, c in enumerate(s["MapChildren"]) if c["Name"] == "Wall")
    s["MapChildren"][i] = child("Wall", 0, 0, 60)
    return s


def good():
    kids = [child("Lindenmoor", 0, -650, 300), child("Ground", 0, -650, 300), child("HalvardsAdit", 400, -660, 100),
            child("Baseplate", 0, 0, 1024, 1, "Part"), child("AlchemistSpawns")]
    kids += [child(n) for n in SITE_NAMES]
    return {
        "Parts": 31998,
        "Baseplate": {"Pos": [0, -8, 0], "Size": [2048, 16, 2048]},
        "MapChildren": kids,
        "Areas": [{"AreaName": "Lindenmoor", "Top": "Lindenmoor", "Box": [[-300, -10, -950], [300, 90, -350]]},
                  {"AreaName": "Burned Lab", "Top": "BurnedLaboratory", "Box": [[-5, 0, -5], [5, 10, 5]]}],
        "Arrivals": [{"Point": "RoadStart", "Path": "Workspace.World.Map.Lindenmoor.NorthRoad.RoadStart"},
                     {"Point": "Platform", "Path": "Workspace.World.Map.Lindenmoor.Station.Platform"}],
        "Trainers": [{"DialogueId": "trainer_" + e, "Path": "Workspace.World.NPCs.Alchemy Trainers." + e,
                      "Pivot": [0, 3, 0]} for e in ("flame", "ice", "earth", "wind", "metal")],
        "Retire": [{"Path": "World.Map.Lindenmoor.NorthRoad"}, {"Path": "World.Map.Lindenmoor.HubRoad"},
                   {"Path": "World.Map.Lindenmoor.Station.BufferStop", "Pivot": [-270, 9.6, -369]}],
        "Spawns": [],
        "AlchemistSpawns": [{"Name": n, "Pos": [2, 1, 2]} for n in
                            ("FieldAlchemist_BurnedLab", "FrostAlchemist_FrozenStation",
                             "StoneAlchemist_CrackedFootbridge", "GaleAlchemist_SilentObservatory",
                             "WardAlchemist_SilentForge")],
        "GroundInInfill": 0,
    }


class CheckSurvey(unittest.TestCase):
    def run_checker(self, survey, layout=layout()):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "survey.json")
            with open(p, "w", encoding="utf-8") as f:
                json.dump(survey, f)
            args = [sys.executable, "-I", CHECKER, p]
            if layout is not None:
                lp = os.path.join(d, "layout.json")
                with open(lp, "w", encoding="utf-8") as f:
                    json.dump(layout, f)
                args += ["--layout", lp]
            r = subprocess.run(args, capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr

    def test_good_survey_passes(self):
        code, out = self.run_checker(good())
        self.assertEqual(code, 0, out)
        self.assertIn("FAIL 0", out)

    def test_unknown_child_and_budget_fail(self):
        s = good()
        s["MapChildren"].append(child("Foo"))
        s["Parts"] = 50000
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: unclassified map child Foo", out)
        self.assertIn("FAIL: budget 50000", out)
        self.assertIn("FAIL 2", out)

    def test_baseplate_moved_fails(self):
        s = good()
        s["Baseplate"]["Pos"] = [0, -10, 0]
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: baseplate", out)

    def test_missing_baseplate_fails(self):
        s = good()
        del s["Baseplate"]
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: baseplate at None", out)

    def test_infill_cells(self):
        sys.path.insert(0, HERE)
        import check_survey
        runs = check_survey.infill_runs()
        cells = sum((r[2] - r[1]) // 4 for r in runs)
        self.assertEqual(cells, 10863)  # of 41,349 cells in the Infill rect; the rest are Keep
        for x0, z0, z1 in runs:
            self.assertTrue(-392 <= x0 < 532 and -1004 <= z0 < z1 <= -288)

    def test_ground_in_infill_fails(self):
        s = good()
        s["GroundInInfill"] = 3
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: 3 Ground parts in Infill cells", out)

    def test_overlap_of_different_volume_is_info(self):
        s = good()  # overlaps the layout's Training Field box (x -260..-40, z -270..-100) and is smaller
        s["Areas"].append({"AreaName": "Yard", "Top": "Lindenmoor", "Box": [[-100, 0, -200], [-60, 20, -150]]})
        code, out = self.run_checker(s)
        self.assertEqual(code, 0, out)
        self.assertIn("INFO: village area Yard", out)
        self.assertIn("INFO 1", out)

    def test_overlap_of_equal_volume_fails(self):
        s = good()  # the Training Field's own box, copied: a tie smallest-wins can't break
        s["Areas"].append({"AreaName": "Twin", "Top": "Ground", "Box": [[-260, -10, -270], [-40, 90, -100]]})
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: village area Twin overlaps new area Training Field with equal volume", out)

    def test_relocated_site_area_may_overlap(self):
        s = good()  # a trial site's own area inside a new area is fine (not a village top)
        s["Areas"].append({"AreaName": "Site", "Top": "LedgeCourse", "Box": [[-100, 0, -200], [-60, 20, -150]]})
        code, out = self.run_checker(s)
        self.assertEqual(code, 0, out)
        self.assertIn("INFO 0", out)

    def test_pad_too_small_fails(self):
        s = good()  # one Wall grows to 120 x 120, so the arena block (alone on its pad) is 120 x 120: radius 84.9
        big_wall(s)
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: res_test_arena: pad 50 too small: needed radius 84.9; needed + 6 = 90.9", out)
        self.assertNotIn("res_practice_yard", out)

    def test_arrange_two_pieces(self):
        r = pad_layout.arrange([{"Name": "A", "Size": [10, 10]}, {"Name": "B", "Size": [10, 10]}])
        self.assertEqual(r["slots"], {"A": [-7.0, 0.0], "B": [7.0, 0.0]})
        self.assertAlmostEqual(r["radius"], 13.0)  # combined AABB 24 x 10: half of a 26-stud diagonal
        r = pad_layout.arrange([{"Name": "A", "Size": [30, 20]}], gap=4)
        self.assertEqual(r["slots"], {"A": [0.0, 0.0]})
        self.assertAlmostEqual(r["radius"], 18.0277, places=3)

    def test_test_arena_is_one_block(self):
        kids = [child("LedgeCourse", -200, 240, 20), child("Wall", 0, 46, 10), child("Wall", 54, 0, 4, 1, "Part"),
                child("Curve", 50, 50, 40), child("Hill", -60, -24, 25), child("Step", -44, 16, 8),
                child("TrainingGround", 38, -21, 2)]
        got = pad_layout.pad_pieces(kids)["res_practice_yard"]
        self.assertEqual([p["Name"] for p in got], ["LedgeCourse"])
        got = pad_layout.pad_pieces(kids)["res_test_arena"]
        self.assertEqual([p["Name"] for p in got], ["TestArena"])
        arena = got[0]
        self.assertEqual(sorted(arena["Members"]), ["Curve", "Hill", "Step", "TrainingGround", "Wall"])
        self.assertEqual(arena["Size"], [175, 139])  # union x -85..90, z -49..90: its internal layout kept
        self.assertEqual(arena["Center"], [2.5, 20.5])
        self.assertEqual(pad_layout.arrange(got)["slots"], {"TestArena": [0.0, 0.0]})

    def test_pad_radius_comes_from_layout(self):
        L = set_radius(layout(), "res_practice_yard", 5)  # the good survey's LedgeCourse (10 x 10) needs 7.1
        code, out = self.run_checker(good(), L)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: res_practice_yard: pad 5 too small: needed radius 7.1", out)
        L = set_radius(layout(), "res_test_arena", 100)  # now the 84.9 arena fits
        s = good()
        big_wall(s)
        code, out = self.run_checker(s, L)
        self.assertEqual(code, 0, out)

    def test_missing_pad_landmark_fails(self):
        L = layout()
        L["Landmarks"] = [lm for lm in L["Landmarks"] if lm["Id"] != "res_test_arena"]
        code, out = self.run_checker(good(), L)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: res_test_arena not in the layout's landmarks (or has no Radius); needed radius 7.1; "
                      "needed + 6 = 13.1", out)
        self.assertIn("FAIL 1", out)

    def test_usage_without_args(self):
        r = subprocess.run([sys.executable, "-I", CHECKER], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertIn("python -I check_survey.py <survey.json>", r.stdout)

    def test_presence(self):
        for drop, msg in (("Curve", "map child Curve: found 0, expected 1"),
                          ("Ground", "map child Ground: found 0, expected 1"),
                          ("AlchemistSpawns", "map child AlchemistSpawns: found 0, expected 1")):
            s = good()
            s["MapChildren"] = [c for c in s["MapChildren"] if c["Name"] != drop]
            code, out = self.run_checker(s)
            self.assertEqual(code, 1, out)
            self.assertIn("FAIL: " + msg, out)
        s = good()  # only one Wall left
        i = next(i for i, c in enumerate(s["MapChildren"]) if c["Name"] == "Wall")
        del s["MapChildren"][i]
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: map child Wall: found 1, expected 2", out)

    def test_retire(self):
        s = good()
        s["Retire"] = [r for r in s["Retire"] if "HubRoad" not in r["Path"]]
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: Retire: World.Map.Lindenmoor.HubRoad found 0 times", out)
        s = good()  # the wrong buffer stop (the one at z -891 must stay)
        s["Retire"][2]["Pivot"] = [-270, 9.6, -891]
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: Retire: 0 BufferStops near", out)
        s = good()
        s["Retire"].append(copy.deepcopy(s["Retire"][2]))
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: Retire: 2 BufferStops near", out)

    def test_area_outside_map_is_info(self):
        s = good()
        s["Areas"].append({"AreaName": "Stray", "Top": "", "Path": "Workspace.Stray",
                           "Box": [[900, 0, 900], [910, 10, 910]]})
        code, out = self.run_checker(s)
        self.assertEqual(code, 0, out)
        self.assertIn("INFO: area Stray is not under World.Map", out)

    def test_part_box_preferred(self):
        c = child("FoundryYard", 0, 0, 50)
        c["PartBox"] = [[-10, 0, -20], [10, 5, 20]]
        got = pad_layout.pad_pieces([c])["res_foundry_graybox"]
        self.assertEqual(got[0]["Size"], [20, 40])
        self.assertEqual(got[0]["Center"], [0.0, 0.0])

    def test_spawn_slots_ward_alchemist(self):
        # measured in Ye 2026-10-24: SilentForge, ForgeFloor and WardAlchemist_SilentForge
        kids = [{"Name": "SilentForge", "Box": [[182, 0, 300], [226, 21.4, 336]]},
                {"Name": "ForgeFloor", "Box": [[241.3, 0, 279.8], [314.3, 10, 352.8]]}]
        pieces = pad_layout.pad_pieces(kids)
        sp = [{"Name": "WardAlchemist_SilentForge", "Pos": [290.5, 0.5, 409.4]}]
        # site slot x = -(44 + 4 + 73) / 2 + 22 = -38.5; offset (86.5, 91.4) -> (48.0, 91.4), 103.2 out
        e = pad_layout.spawn_slots(sp, pieces, {"res_silent_forge": 76.7})["WardAlchemist_SilentForge"]
        self.assertEqual((e["Site"], e["Pad"], e["Pulled"]), ("SilentForge", "res_silent_forge", True))
        self.assertAlmostEqual(math.hypot(*e["Offset"]), 76.7 - 8, places=1)
        self.assertAlmostEqual(e["Offset"][1] / e["Offset"][0], 91.4 / 48.0, places=2)  # same direction
        e = pad_layout.spawn_slots(sp, pieces, {"res_silent_forge": 120})["WardAlchemist_SilentForge"]
        self.assertFalse(e["Pulled"])
        self.assertEqual(e["Offset"], [48.0, 91.4])

    def test_spawn_names_map_to_sites(self):
        for n, site in (("FieldAlchemist_BurnedLab", "BurnedLaboratory"), ("FrostAlchemist_FrozenStation", "FrozenStation"),
                        ("StoneAlchemist_CrackedFootbridge", "CrackedFootbridge"),
                        ("GaleAlchemist_SilentObservatory", "SilentObservatory"),
                        ("WardAlchemist_SilentForge", "SilentForge"), ("Foo", None), ("X_Nowhere", None)):
            self.assertEqual(pad_layout.spawn_site(n), site)

    def test_spawn_checks(self):
        s = good()
        s["AlchemistSpawns"].append({"Name": "OddAlchemist_Nowhere", "Pos": [0, 0, 0]})
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: alchemist spawn OddAlchemist_Nowhere: no site for its name", out)
        s = good()  # far from its site: pulled in, reported as INFO, still passes
        s["AlchemistSpawns"][4]["Pos"] = [300, 1, 400]
        code, out = self.run_checker(s)
        self.assertEqual(code, 0, out)
        self.assertIn("INFO: alchemist spawn WardAlchemist_SilentForge pulled in to 37.0 on res_silent_forge", out)
        s = good()
        del s["AlchemistSpawns"]
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: survey has no AlchemistSpawns children", out)

    def test_missing_site_fails(self):
        s = good()
        s["MapChildren"] = [c for c in s["MapChildren"] if c["Name"] != "FoundryYard"]
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: res_foundry_graybox: blocks not found: ['FoundryYard']", out)

    def test_arrivals(self):
        s = good()
        s["Arrivals"].append(copy.deepcopy(s["Arrivals"][0]))
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: RoadStart arrivals", out)
        s = good()
        s["Arrivals"][0]["Path"] = "Workspace.World.Map.Lindenmoor.Travel.RoadStart"
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        s = good()
        s["Arrivals"].pop()
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: Platform arrivals 0", out)

    def test_trainers(self):
        s = good()
        s["Trainers"].pop()
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: trainers found: 4", out)
        s = good()
        s["Trainers"][0]["Path"] = "Workspace.World.Map.Hub.Flame"
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("not in World.NPCs", out)


if __name__ == "__main__":
    unittest.main()
