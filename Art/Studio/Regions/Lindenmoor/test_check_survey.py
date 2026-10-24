"""Tests for check_survey.py: hand-made surveys in a temporary directory, run through the real checker.
python -I Art/Studio/Regions/Lindenmoor/test_check_survey.py"""
import copy, json, os, subprocess, sys, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CHECKER = os.path.join(HERE, "check_survey.py")
SITE_NAMES = ["BurnedLaboratory", "AshPit", "FrozenStation", "FrozenChamber", "CrackedFootbridge", "UnstableQuarry",
              "SilentObservatory", "GaleFloor", "SilentForge", "ForgeFloor", "FoundryYard", "LedgeCourse", "Wall",
              "Wall", "Curve", "Hill", "Step", "TrainingGround"]


def child(name, x=0, z=0, half=5, parts=10, cls="Model"):
    return {"Name": name, "Class": cls, "Parts": parts, "Pivot": [x, 0, z],
            "Box": [[x - half, 0, z - half], [x + half, 10, z + half]]}


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
        "Retire": [],
        "Spawns": [],
        "GroundInInfill": 0,
    }


class CheckSurvey(unittest.TestCase):
    def run_checker(self, survey):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "survey.json")
            with open(p, "w", encoding="utf-8") as f:
                json.dump(survey, f)
            r = subprocess.run([sys.executable, "-I", CHECKER, p], capture_output=True, text=True)
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
        s = good()  # Wall (practice yard, pad 50) spread to 120 x 120: radius 84.9
        s["MapChildren"] = [c for c in s["MapChildren"] if c["Name"] != "Wall"] + [child("Wall", 0, 0, 60)]
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: res_practice_yard: footprint radius 84.9 > pad 50", out)

    def test_missing_site_fails(self):
        s = good()
        s["MapChildren"] = [c for c in s["MapChildren"] if c["Name"] != "FoundryYard"]
        code, out = self.run_checker(s)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL: res_foundry_graybox: none of", out)

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
