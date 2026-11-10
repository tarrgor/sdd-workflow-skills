"""Regression checks for metadata rejected by the Codex upload dialog."""
import copy
import json
from pathlib import Path
import runpy
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
validate = runpy.run_path(str(ROOT / 'scripts/validate-plugin.py'))['validate']


class PluginValidationTests(unittest.TestCase):
    def test_upload_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('.claude-plugin', '.codex-plugin', 'skills', 'agents'):
                shutil.copytree(ROOT / name, root / name)
            path = root / '.codex-plugin/plugin.json'
            original = json.loads(path.read_text())
            self.assertEqual(validate(root), [])
            cases = [
                ('version',), ('author',), ('author', 'name'),
                ('interface', 'longDescription'), ('interface', 'capabilities'),
                ('interface', 'category'),
            ]
            for keys in cases:
                for mode in ('missing', 'blank', 'wrong-type'):
                    with self.subTest(field='.'.join(keys), mode=mode):
                        manifest = copy.deepcopy(original)
                        target = manifest
                        for key in keys[:-1]:
                            target = target[key]
                        if mode == 'missing':
                            del target[keys[-1]]
                        else:
                            target[keys[-1]] = '   ' if mode == 'blank' else 12
                        path.write_text(json.dumps(manifest))
                        self.assertTrue(validate(root))
            path.write_text(json.dumps(original))
            self.assertEqual(validate(root), [])


if __name__ == '__main__':
    unittest.main()
