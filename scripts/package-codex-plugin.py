"""Build one uploadable Codex plugin, excluding other hosts' manifests."""
import argparse
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parent.parent


def package(destination: Path) -> None:
    manifest = ROOT / '.codex-plugin/plugin.json'
    json.loads(manifest.read_text(encoding='utf-8'))
    files = [manifest, ROOT / 'LICENSE']
    files.extend(p for p in (ROOT / 'skills').rglob('*')
                 if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
        for path in sorted(files):
            archive.write(path, path.relative_to(ROOT).as_posix())
    with ZipFile(destination) as archive:
        names = archive.namelist()
        assert [n for n in names if n.endswith('/plugin.json')] == ['.codex-plugin/plugin.json']
        assert sum(n.endswith('/SKILL.md') for n in names) == 15
        assert archive.testzip() is None
    print(f'Created {destination} ({len(files)} files, one Codex manifest, 15 skills).')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    package(parser.parse_args().output)
