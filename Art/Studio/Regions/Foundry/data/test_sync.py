"""Checks for the Foundry data sync tool (Foundry data plan, Task 1): python -I Art/Studio/Regions/Foundry/data/test_sync.py

Pure Python, no Studio. Prints PASS n / FAIL m and exits 1 on any failure.
- the long-bracket level is the smallest that the text can't close early;
- a generated bundle's SRC round-trips (parsed back out of the bundle, its norm_hash equals the repo file's);
- the bundle carries the header, the NormHash function and the PATH/CLASS/LABEL/CREATE/BACKUP/WANT line;
- every manifest Repo file exists, Labels are unique, and every pair is well formed;
- norm_hash matches a value Studio returned (Ye's TownsfolkClient, 2026-10-24);
- --check for a place lists only the pairs whose Places include it (fixture manifest, fake Studio runner).
Task 2 (Ruling 20) adds the sync.py hardening checks:
- (a) a bundle refuses while this place's PlayLock is set, before it changes anything; a Foundry --run first asks
  Ye's PlayLock and runs no bundle unless it is nil;
- (b) a lone CR left after CRLF normalisation is refused at generation;
- (c) a script a bundle creates carries FoundryDataAdd = true;
- (d) --check echoes the raw rbxc output when no line parses;
- (e) an empty --only refuses;
- (f) dumphelper.lua has MODE = "install" | "remove", and both refuse while Play runs.
"""
import io, json, os, re, sys, tempfile
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
sys.path.insert(0, HERE)

FAILS, PASSES = [], [0]


def check(name, ok, detail=""):
    if ok:
        PASSES[0] += 1
    else:
        FAILS.append(f"{name}: {detail}")


def parse_src(bundle_text):
    """The SRC literal's body, read back the way Luau reads it (the opening bracket's first newline dropped)."""
    m = re.search(r"^local SRC = \[(=*)\[\n", bundle_text, re.M)
    if not m:
        return None
    close = "]" + m.group(1) + "]"
    end = bundle_text.find(close, m.end())
    return None if end < 0 else bundle_text[m.end():end]


def boot_body(src):
    """QuestService.Boot's text (its function line to the first `end` at column 0), or None."""
    m = re.search(r"^function QuestService\.Boot\(\)\n(.*?)^end\n", src, re.M | re.S)
    return m.group(0) if m else None


def boot_order(src):
    """(ok, why): Boot waits for the snapshot before it upgrades (Ruling 2); its data poll runs until the player leaves,
    with no try cap (Task 3, Ruling 23: a slow profile load must not leave a stale state frozen for the session); and
    it warns once, at DATA_NOTICE polls, as a notice (Minor 9). Comment lines don't count."""
    body = boot_body(src)
    if body is None:
        return False, "no function QuestService.Boot()"
    code = "\n".join(l for l in body.split("\n") if not l.lstrip().startswith("--"))
    w, u = code.find("WaitForSnapshot("), code.find("UpgradeAll(")
    if not (0 <= w < u):
        return False, f"WaitForSnapshot at {w}, UpgradeAll at {u}"
    if re.search(r"\bfor\s+\w+\s*=", code) or re.search(r"\brepeat\b", code):
        return False, "a counted (numeric for / repeat) loop: the data poll must run until the player leaves"
    loop = code.find("while Player.Parent ~= nil do")
    if not (w < loop < u):
        return False, "no `while Player.Parent ~= nil do` poll loop between WaitForSnapshot and UpgradeAll"
    notice = code.find("== DATA_NOTICE then", loop)
    if notice < 0 or code.find("warn(", notice) < 0:
        return False, "no one-time warn (`== DATA_NOTICE then` ... `warn(`) inside the poll loop"
    return True, ""


def main():
    try:
        import sync
    except ImportError as e:
        print(f"PASS 0 / FAIL 1\n- import sync: {e}")
        return 1

    # 1. long-bracket level
    check("level ]] and ]=]", sync.bracket_level("a ]] b ]=] c") == 2, sync.bracket_level("a ]] b ]=] c"))
    check("level plain", sync.bracket_level("print(1)\n") == 0, sync.bracket_level("print(1)\n"))
    # a text ending in "]" would close early at level 0 ("x]" + "]]" reads as "x" + "]]")
    check("level trailing ]", sync.bracket_level("x]") == 1, sync.bracket_level("x]"))

    # 2. manifest
    manifest = sync.load_manifest()
    pairs = manifest["Pairs"]
    labels = [p["Label"] for p in pairs]
    check("labels unique", len(labels) == len(set(labels)), sorted(l for l in labels if labels.count(l) > 1))
    for p in pairs:
        check(f"{p['Label']} repo exists", os.path.isfile(os.path.join(REPO, p["Repo"])), p["Repo"])
        check(f"{p['Label']} keys", set(p) == {"Label", "Studio", "Class", "Repo", "Places", "Create"}, sorted(p))
        check(f"{p['Label']} places", p["Places"] and set(p["Places"]) <= {"ye", "foundry"}, p["Places"])
        check(f"{p['Label']} class", p["Class"] in ("ModuleScript", "Script", "LocalScript"), p["Class"])
        check(f"{p['Label']} path", len(p["Studio"].split("/")) >= 2 and p["Studio"].split("/")[-1], p["Studio"])
    check("pair count foundry", len(sync.pairs_for(manifest, "foundry")) == 53, len(sync.pairs_for(manifest, "foundry")))
    check("pair count ye", len(sync.pairs_for(manifest, "ye")) == 50, len(sync.pairs_for(manifest, "ye")))

    # 3. norm_hash against Studio's value
    with open(os.path.join(REPO, "Art/Studio/Regions/TownsfolkClient.lua"), "rb") as f:
        h = sync.norm_hash(f.read())
    check("norm_hash TownsfolkClient", h == "6809:893158121:758120550", h)

    # 4. bundles round-trip, and carry the contract
    out = tempfile.mkdtemp(prefix="test_sync_")
    for p in pairs:
        path = sync.write_bundle(p, out)
        with open(path, encoding="utf-8", newline="") as f:
            text = f.read()
        with open(os.path.join(REPO, p["Repo"]), "rb") as f:
            want = sync.norm_hash(f.read())
        body = parse_src(text)
        got = None if body is None else sync.norm_hash(body.encode("utf-8"))
        check(f"{p['Label']} round-trip", got == want, f"{got} vs {want}")
        check(f"{p['Label']} no CR", "\r" not in text, "bundle has CR")
        check(f"{p['Label']} header", text.startswith(
            f"-- generated by Art/Studio/Regions/Foundry/data/sync.py from {p['Repo']} ("), text[:120])
        check(f"{p['Label']} NormHash", "local function NormHash(S)" in text, "")
        line = (f'local PATH, CLASS, LABEL, CREATE, BACKUP, WANT = "{p["Studio"]}", "{p["Class"]}", '
                f'"{p["Label"]}", {"true" if p["Create"] else "false"}, "Pre-FoundryData_2026-10-24", "{want}"')
        check(f"{p['Label']} params", line in text, line)

    # 5. --check is per place (fixture manifest; a fake Studio answers every label it is asked about)
    fx = {"Pairs": [
        {"Label": "Only.Ye", "Studio": "ServerStorage/OnlyYe", "Class": "ModuleScript",
         "Repo": "Art/Studio/Regions/TownsfolkClient.lua", "Places": ["ye"], "Create": False},
        {"Label": "Only.Foundry", "Studio": "ServerStorage/OnlyFoundry", "Class": "ModuleScript",
         "Repo": "Art/Studio/Regions/TownsfolkClient.lua", "Places": ["foundry"], "Create": False},
    ]}
    fxpath = os.path.join(out, "fixture_manifest.json")
    with open(fxpath, "w", encoding="utf-8") as f:
        json.dump(fx, f)
    for place, mine, other in (("ye", "Only.Ye", "Only.Foundry"), ("foundry", "Only.Foundry", "Only.Ye")):
        asked = []

        def fake(place_id, bundle_path, _asked=asked):
            with open(bundle_path, encoding="utf-8") as f:
                src = f.read()
            got = re.findall(r'\{"([^"]+)", "[^"]*", "[^"]*"\}', src)
            _asked.extend(got)
            return "\n".join(f"{l}\t6809:893158121:758120550" for l in got)

        buf = io.StringIO()
        with redirect_stdout(buf):
            code = sync.main(["--place", place, "--check", "--manifest", fxpath, "--out", out], runner=fake)
        text = buf.getvalue()
        check(f"check {place} asks only its pair", asked == [mine], asked)
        check(f"check {place} lists its pair", f"{mine} SAME" in text, text)
        check(f"check {place} omits the other", other not in text, text)
        check(f"check {place} totals", "SAME 1 / DIFFER 0 / MISSING 0" in text, text)
        check(f"check {place} exit 0", code == 0, code)

    # 6. --check counts DIFFER/MISSING and exits 1
    def fake2(place_id, bundle_path):
        return "Only.Ye\tMISSING"
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = sync.main(["--place", "ye", "--check", "--manifest", fxpath, "--out", out], runner=fake2)
    check("check missing", "Only.Ye MISSING" in buf.getvalue() and "SAME 0 / DIFFER 0 / MISSING 1" in buf.getvalue(),
          buf.getvalue())
    check("check missing exit 1", code == 1, code)

    def fake3(place_id, bundle_path):
        return "Only.Ye\t1:2:3"
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = sync.main(["--place", "ye", "--check", "--manifest", fxpath, "--out", out], runner=fake3)
    check("check differ", "Only.Ye DIFFER 1:2:3 vs 6809:893158121:758120550" in buf.getvalue(), buf.getvalue())
    check("check differ exit 1", code == 1, code)

    # 7. a label for the other place is refused by --only
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = sync.main(["--place", "ye", "--only", "Only.Foundry", "--manifest", fxpath, "--out", out], runner=fake)
    check("only other place refused", code == 2, (code, buf.getvalue()))

    # ===== Task 2 (Ruling 20): sync.py hardening =====
    one = pairs[0]
    text = sync.bundle_text(one)
    body = text[text.find("local SRC = ["):]
    body = body[body.find("\n" + "]" + "=" * sync.bracket_level(sync.repo_text(one)) + "]\n"):]  # after SRC

    # (a) a bundle refuses while this place's PlayLock is set, before it changes anything
    lock_at = body.find('GetAttribute("PlayLock")')
    check("a: bundle reads PlayLock", lock_at >= 0, "no PlayLock read in the bundle body")
    for marker in ("Instance.new(CLASS)", "S.Source = SRC", "Copy.Parent = Dir", "Root.Parent = SS"):
        at = body.find(marker)
        check(f"a: PlayLock refusal before {marker}", 0 <= lock_at < at, (lock_at, at))
    check("a: PlayLock refusal returns REFUSED", re.search(r'PlayLock"\)\s*\n?\s*if [A-Za-z]+ ~= nil then return "REFUSED "', body) is not None,
          "no 'if <lock> ~= nil then return \"REFUSED \"' after the read")

    # (a) for Foundry, --run first asks Ye's PlayLock and refuses (running no bundle) unless it is nil
    def fake_run(answers):
        seen = []

        def runner(place_id, bundle_path):
            name = os.path.basename(bundle_path)
            seen.append((place_id, name))
            if name == "lock_ye.lua":
                return answers["ye_lock"]
            if name.startswith("sync_"):
                with open(bundle_path, encoding="utf-8") as f:
                    lab = re.search(r'^local PATH, CLASS, LABEL, CREATE, BACKUP, WANT = "[^"]*", "[^"]*", "([^"]+)"', f.read(), re.M).group(1)
                return "synced " + lab
            with open(bundle_path, encoding="utf-8") as f:
                got = re.findall(r'\{"([^"]+)", "[^"]*", "[^"]*"\}', f.read())
            return "\n".join(f"{l}\t6809:893158121:758120550" for l in got)
        return runner, seen

    for ans, want_code, want_sync in (("PlayLock=Ye:task2", 2, False), ("Target is not reachable", 2, False),
                                      ("PlayLock=nil", 0, True)):
        runner, seen = fake_run({"ye_lock": ans})
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = sync.main(["--place", "foundry", "--only", "Only.Foundry", "--run", "--manifest", fxpath, "--out", out],
                             runner=runner)
        synced = any(n.startswith("sync_") for _, n in seen)
        check(f"a: foundry run with Ye {ans!r} exit", code == want_code, (code, buf.getvalue()))
        check(f"a: foundry run with Ye {ans!r} syncs={want_sync}", synced == want_sync, seen)
        check(f"a: foundry run asks Ye first ({ans!r})", seen and seen[0] == (sync.PLACES["ye"], "lock_ye.lua"), seen)
        if not want_sync:
            check(f"a: foundry refusal says why ({ans!r})", "REFUSED" in buf.getvalue() and "PlayLock" in buf.getvalue(),
                  buf.getvalue())
    runner, seen = fake_run({"ye_lock": "PlayLock=nil"})
    with redirect_stdout(io.StringIO()):
        sync.main(["--place", "ye", "--only", "Only.Ye", "--run", "--manifest", fxpath, "--out", out], runner=runner)
    check("a: a ye run doesn't ask Ye's lock separately (its bundle reads it)",
          all(n != "lock_ye.lua" for _, n in seen) and any(n.startswith("sync_") for _, n in seen), seen)

    # (b) a lone CR left after CRLF normalisation is refused at generation
    for name, data, bad in (("lone CR", b"a = 1\r\nb = 2\rc = 3\n", True), ("CRLF only", b"a = 1\r\nb = 2\r\n", False),
                            ("trailing lone CR", b"a = 1\r", True)):
        fpath = os.path.join(out, "cr_fixture.lua")
        with open(fpath, "wb") as f:
            f.write(data)
        fp = {"Label": "Fx.CR", "Studio": "ServerStorage/FxCR", "Class": "ModuleScript", "Repo": fpath,
              "Places": ["ye"], "Create": False}
        try:
            sync.bundle_text(fp)
            raised = None
        except (ValueError, SystemExit) as e:
            raised = str(e)
        check(f"b: {name} refused={bad}", (raised is not None) == bad, raised)
        if bad:
            check(f"b: {name} refusal names the file", raised is not None and "cr_fixture.lua" in raised, raised)

    # (c) a created script carries FoundryDataAdd = true, set before it is parented; only created scripts get it
    mark = 'S:SetAttribute("FoundryDataAdd", true)'
    check("c: one marker in the bundle", body.count(mark) == 1, body.count(mark))
    new_at, mark_at, par_at = body.find("S = Instance.new(CLASS)"), body.find(mark), body.find("S.Parent = Node")
    check("c: marker between create and parent", 0 <= new_at < mark_at < par_at, (new_at, mark_at, par_at))

    # (d) --check echoes the raw rbxc output when no line parses
    def fake_raw(place_id, bundle_path):
        return "error: Studio said something unexpected"
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = sync.main(["--place", "ye", "--check", "--manifest", fxpath, "--out", out], runner=fake_raw)
    check("d: raw output echoed", "error: Studio said something unexpected" in buf.getvalue(), buf.getvalue())
    check("d: raw output still exits 1", code == 1, code)
    buf = io.StringIO()
    with redirect_stdout(buf):
        sync.main(["--place", "ye", "--check", "--manifest", fxpath, "--out", out], runner=fake)
    check("d: no raw echo when lines parse", "raw" not in buf.getvalue().lower(), buf.getvalue())

    # (e) an empty --only refuses, running nothing
    for only in ("", " , ", ","):
        runner, seen = fake_run({"ye_lock": "PlayLock=nil"})
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = sync.main(["--place", "ye", "--only", only, "--run", "--manifest", fxpath, "--out", out], runner=runner)
        check(f"e: --only {only!r} refused", code == 2 and not seen, (code, seen, buf.getvalue()))

    # (f) dumphelper.lua has MODE = "install" | "remove"; both refuse while Play runs; remove destroys both names
    with open(os.path.join(HERE, "dumphelper.lua"), encoding="utf-8") as f:
        dh = f.read()
    modes = re.findall(r'^local MODE = "([a-z]+)"', dh, re.M)
    check("f: one MODE line, install", modes == ["install"], modes)
    code_dh = "\n".join(l for l in dh.split("\n") if not l.lstrip().startswith("--"))
    run_at = code_dh.find("IsRunning()")
    rem_at = code_dh.find('MODE == "remove"')
    check("f: the Play refusal comes before the remove branch", 0 <= run_at < rem_at, (run_at, rem_at))
    check("f: the Play refusal comes before any Destroy", 0 <= run_at < code_dh.find(":Destroy()"), run_at)
    rem = code_dh[rem_at:]
    check("f: remove destroys LMQuestDump_TEMP and LMQuestDump",
          '"LMQuestDump_TEMP"' in rem and '"LMQuestDump"' in rem and ":Destroy()" in rem, rem[:300])
    check("f: remove returns before installing", rem.find("return") < rem.find('Instance.new("Script")'), rem[:300])
    check("f: an unknown MODE is refused", re.search(r'MODE ~= "install" then return "REFUSED', code_dh) is not None, "")

    # ===== Task 2 fix round 1 (Ruling 22): QuestService.Boot's order, read from the repo file =====
    with open(os.path.join(REPO, "Scripts/ServerScriptService/QuestService.lua"), encoding="utf-8") as f:
        qs = f.read().replace("\r\n", "\n")
    ok, why = boot_order(qs)
    check("boot: WaitForSnapshot before UpgradeAll, uncapped poll, one-time notice", ok, why)
    # the check can fail: the two calls swapped, and the warn removed
    body = boot_body(qs) or ""
    swapped = qs.replace(body, body.replace("WaitForSnapshot(", "\0").replace("UpgradeAll(", "WaitForSnapshot(")
                                     .replace("\0", "UpgradeAll(")) if body else qs
    check("boot: a swapped order is caught", not boot_order(swapped)[0], "the check passed a swapped Boot")
    nowarn = qs.replace(body, re.sub(r"\n\s*warn\([^\n]*", "", body)) if body else qs
    check("boot: a missing give-up warn is caught", not boot_order(nowarn)[0], "the check passed a Boot without warn")
    # Task 3 (Ruling 23): a capped poll (Task 2's counted loop) and a warn on every poll are caught too
    capped = qs.replace(body, body.replace("while Player.Parent ~= nil do", "for _ = 1, DATA_NOTICE do")) if body else qs
    check("boot: a capped poll loop is caught", capped != qs and not boot_order(capped)[0], "the check passed a capped Boot")
    everypoll = qs.replace(body, body.replace("== DATA_NOTICE then", "> 0 then")) if body else qs
    check("boot: a warn on every poll is caught", everypoll != qs and not boot_order(everypoll)[0],
          "the check passed a Boot that warns on every poll")

    print(f"PASS {PASSES[0]} / FAIL {len(FAILS)}")
    for f in FAILS:
        print("-", f)
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
