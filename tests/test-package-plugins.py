"""Verify release ZIP boundaries, resources, agents, and tag version stamping."""
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent.parent
module = runpy.run_path(str(ROOT / 'scripts/package-plugins.py'))


class PackagingTests(unittest.TestCase):
    def test_versions(self):
        for tag in ('v1.0.0', '1.0.0', 'v2.1.0-rc.1', 'v2.1.0+build.1'):
            self.assertEqual(module['release_version'](tag), tag.removeprefix('v'))
        for tag in ('v1', 'v01.0.0', '1.0.0-01', 'main', '../1.0.0'):
            with self.assertRaises(ValueError):
                module['release_version'](tag)

    def test_archives(self):
        with tempfile.TemporaryDirectory() as temporary:
            for host in ('claude', 'codex'):
                manifest_path = f'.{host}-plugin/plugin.json'
                original = (ROOT / manifest_path).read_bytes()
                destination = Path(temporary) / f'{host}.zip'
                module['package'](host, destination, 'v2.3.4-rc.1')
                with ZipFile(destination) as archive:
                    names = archive.namelist()
                    self.assertEqual([n for n in names if n.endswith('/plugin.json')], [manifest_path])
                    self.assertEqual(json.loads(archive.read(manifest_path))['version'], '2.3.4-rc.1')
                    self.assertIn('skills/_shared/scripts/status-page.py', names)
                    self.assertIn('skills/run-milestone/references/codex-desktop.md', names)
                    self.assertIn('LICENSE', names)
                    self.assertFalse(any('marketplace.json' in n or n.startswith('.git/') for n in names))
                    assets = {n for n in names if n.startswith('assets/')}
                    self.assertEqual(assets, {'assets/icon.png', 'assets/logo.png'})
                    agents = [n for n in names if n.startswith('agents/')]
                    self.assertEqual(set(agents), {'agents/research-topic.md', 'agents/verify-implementation.md'} if host == 'claude' else set())
                self.assertEqual((ROOT / manifest_path).read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
