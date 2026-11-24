import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1] / "skills" / "_shared" / "scripts"
EMPTY = "missing-or-invalid"
PR = {"number": 30, "title": "</script><img src=x>", "branch": "issue/12-scope",
      "checks": "pending", "unresolved": 0}


def issue(number, closed=False, labels=(), deps=()):
    return {"number": number, "title": f"Issue #{number}", "closed": closed,
            "labels": list(labels), "depends_on": list(deps)}


def fixture():
    return {
        "project": {"name": "Test", "repo": "person/test", "base": "main"},
        "milestone": {"title": "M001", "needs_close": True},
        "planned": [], "issues": [issue(12), issue(13, deps=(12,)), issue(14, deps=(20,))],
        "prs": [], "external_blockers": {"20": True}, "finding_items": {},
        "last_meeting": None,
    }


class StatusTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.snapshot = self.root / ".project" / "status.json"
        self.page = self.root / "STATUS.html"

    def cmd(self, script, *args, payload=None):
        return subprocess.run([sys.executable, str(SCRIPTS / script), str(self.root), *args],
                              input=json.dumps(payload) if payload is not None else None,
                              capture_output=True, encoding="utf-8", check=False)

    def mutate(self, op, data, rev=None, success=True):
        r = self.cmd("status-snapshot.py", op, "-", "--expect", rev or self.rev(), payload=data)
        self.assertEqual(r.returncode == 0, success, r.stderr)
        return r

    def rev(self):
        return self.cmd("status-snapshot.py", "revision").stdout.strip()

    def read(self):
        return json.loads(self.snapshot.read_text(encoding="utf-8"))

    def test_incremental_pr_lifecycle_and_blockers(self):
        self.mutate("replace", fixture(), EMPTY)
        meta = self.read()["_status"]
        self.assertEqual(self.read()["next"]["command"], "/sdd-workflow:implement-issue 12")
        self.mutate("patch", {"prs": [PR]})
        self.assertEqual(self.read()["issues"][0]["state"], "in-review")
        self.assertIsNone(self.read()["next"])
        rev = self.rev()
        self.mutate("patch", {"prs": [PR]})
        self.assertEqual(self.rev(), rev)
        self.mutate("patch", {"prs": [{**PR, "checks": "passing"}]})
        self.assertEqual(self.read()["next"]["skill"], "merge-pr")
        self.mutate("patch", {"remove_prs": [30]})
        self.assertFalse(self.read()["issues"][0]["closed"])
        self.mutate("patch", {"issues": [issue(12, closed=True)], "external_blockers": {"20": False}})
        state = self.read()
        self.assertEqual(state["_status"]["last_full_refresh"], meta["last_full_refresh"])
        self.assertEqual([(i["number"], i["state"]) for i in state["issues"]],
                         [(12, "closed"), (13, "ready"), (14, "ready")])
        self.assertEqual(state["milestone"]["closed"], 1)

    def test_milestone_transition_and_findings(self):
        self.mutate("replace", fixture())
        self.mutate("patch", {"remove_prs": [100], "finding_upserts": {"findings-1.md": "Critical title"}})
        self.assertEqual(self.read()["next"]["skill"], "project-meeting")
        self.mutate("patch", {"remove_findings": ["findings-1.md"], "milestone": None,
                              "issues": [], "external_blockers": {}, "last_meeting": "2026-11-24"})
        self.assertEqual(self.read()["next"]["skill"], "kick-off")
        self.mutate("patch", {"planned": ["M002"]})
        self.assertEqual(self.read()["next"]["skill"], "create-spec-issues")
        self.mutate("patch", {"planned": [], "milestone": {"title": "M002", "needs_close": True},
                              "issues": [issue(21)], "external_blockers": {}})
        self.assertEqual(self.read()["milestone"]["total"], 1)
        self.assertEqual(self.read()["next"]["command"], "/sdd-workflow:implement-issue 21")
        self.assertEqual(self.read()["last_meeting"], "2026-11-24")

    def test_revision_protects_valid_data_from_stale_and_invalid_writes(self):
        self.mutate("replace", fixture())
        rev = self.rev()
        self.mutate("patch", {"issues": [issue(12, labels=["needs-decision"])], "refresh_needed": True}, rev)
        original = self.snapshot.read_bytes()
        self.mutate("replace", fixture(), rev, False)
        self.mutate("patch", {"prs": [{**PR, "checks": "unknown"}]}, success=False)
        self.mutate("patch", {"milestone": None}, success=False)
        incomplete = fixture()
        del incomplete["finding_items"]
        self.mutate("replace", incomplete, success=False)
        self.assertEqual(self.snapshot.read_bytes(), original)
        self.assertTrue(self.read()["_status"]["refresh_needed"])
        self.mutate("replace", fixture())
        self.assertFalse(self.read()["_status"]["refresh_needed"])

    def test_simultaneous_deltas_cannot_clobber_each_other(self):
        self.mutate("replace", fixture())
        rev = self.rev()
        cmd = [sys.executable, str(SCRIPTS / "status-snapshot.py"), str(self.root),
               "patch", "-", "--expect", rev]
        a, b = [subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, text=True) for _ in range(2)]
        try:
            a.stdin.write(json.dumps({"prs": [PR]}))
            b.stdin.write(json.dumps({"finding_upserts": {"finding": None}}))
            for proc in (a, b):
                proc.stdin.close()
                proc.stdin = None
            for proc in (a, b):
                proc.communicate(timeout=15)
            self.assertEqual(sorted([a.returncode, b.returncode]), [0, 1])
            state = self.read()
            self.assertTrue(bool(state["prs"]) ^ bool(state["finding_items"]))
        finally:
            for proc in (a, b):
                if proc.poll() is None:
                    proc.kill()
                    proc.communicate()

    def test_render_from_saved_and_supplied_json_and_preserve_on_error(self):
        self.mutate("replace", fixture())
        self.mutate("patch", {"prs": [PR]})
        r = self.cmd("status-page.py", "--snapshot")
        self.assertEqual(r.returncode, 0, r.stderr)
        page = self.page.read_bytes()
        self.assertIn(b"\\u003c/script\\u003e", page)
        self.assertNotIn(b"</script><img", page)
        self.assertIn(b"Last full refresh:", page)
        self.snapshot.write_text("broken", encoding="utf-8")
        self.assertEqual(self.rev(), EMPTY)
        self.assertNotEqual(self.cmd("status-page.py", "--snapshot").returncode, 0)
        self.assertEqual(self.page.read_bytes(), page)
        self.mutate("patch", {"prs": [PR]}, success=False)
        self.assertEqual(self.snapshot.read_text(encoding="utf-8"), "broken")
        self.mutate("replace", fixture())
        original = self.snapshot.read_bytes()
        self.assertEqual(self.cmd("status-page.py", payload={"project": {"name": "From stdin"}}).returncode, 0)
        self.assertIn(b"From stdin", self.page.read_bytes())
        file = self.root / "report.json"
        file.write_text('{"project":{"name":"From file"}}', encoding="utf-8")
        self.assertEqual(self.cmd("status-page.py", str(file)).returncode, 0)
        self.assertIn(b"From file", self.page.read_bytes())
        self.assertEqual(self.snapshot.read_bytes(), original)
        self.assertIn("/.project/status.json.lock", (self.root / ".gitignore").read_text())


if __name__ == "__main__":
    unittest.main()
