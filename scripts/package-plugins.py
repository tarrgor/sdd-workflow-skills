"""Build isolated Claude and Codex plugin archives with a release-tag version."""
import argparse
import json
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parent.parent
SEMVER = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?')


def release_version(tag: str) -> str:
    version = tag.removeprefix('v')
    if not SEMVER.fullmatch(version):
        raise ValueError(f'Expected a semantic version tag such as v1.0.0: {tag}')
    return version


def package(host: str, destination: Path, version: str | None = None, root: Path = ROOT) -> None:
    if host not in ('claude', 'codex'):
        raise ValueError(f'Unknown plugin host: {host}')
    manifest_path = Path(f'.{host}-plugin/plugin.json')
    manifest = json.loads((root / manifest_path).read_text(encoding='utf-8'))
    if version is not None:
        manifest['version'] = release_version(version)
    files = [root / 'LICENSE']
    files.extend(p for p in (root / 'skills').rglob('*')
                 if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
    files.extend((root / 'assets').glob('*.png'))
    if host == 'claude':
        files.extend((root / 'agents').glob('*.md'))
    destination.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
        archive.writestr(manifest_path.as_posix(), json.dumps(manifest, indent=2) + '\n')
        for path in sorted(files):
            archive.write(path, path.relative_to(root).as_posix())
    with ZipFile(destination) as archive:
        names = archive.namelist()
        if [n for n in names if n.endswith('/plugin.json')] != [manifest_path.as_posix()]:
            raise ValueError('Archive must contain exactly one plugin manifest')
        expected = {p.relative_to(root).as_posix() for p in (root / 'skills').glob('*/SKILL.md')}
        if not expected or not expected.issubset(names) or archive.testzip() is not None:
            raise ValueError('Archive is corrupt or missing skills')
    print(f'Created {destination} ({len(names)} files, {len(expected)} skills).')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    version = release_version(args.tag)
    for host in ('claude', 'codex'):
        package(host, args.output_dir / f'sdd-workflow-{host}-{version}.zip', version)
