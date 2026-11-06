"""Build one uploadable Codex plugin, excluding other hosts' manifests."""
import argparse
from pathlib import Path
import runpy

package_plugin = runpy.run_path(str(Path(__file__).with_name('package-plugins.py')))['package']


def package(destination: Path) -> None:
    package_plugin('codex', destination)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    package(parser.parse_args().output)
