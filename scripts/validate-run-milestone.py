"""Guard the tested Claude coordinator text while allowing isolated Codex routing.

Baselines: main at 984bcd2269cce2f10df897c8aae4345ba1e7695d.
This checks compatibility, not the runtime behavior of a prose skill.
"""

import hashlib
from pathlib import Path
import sys


START = "<!-- codex-run-milestone:start -->\n"
END = "<!-- codex-run-milestone:end -->\n\n"
BASELINES = {
    "skills/run-milestone/SKILL.md":
        "0142a0420d117f7b08a7e03f44905c8684515c04d8087ce762328ae6f69f4dc4",
    "skills/_shared/runtime-adapters.md":
        "b8c79cb244a0f3665d9ddb8fcec51b6b0dfd00bb5486e7636293d4b3834173c9",
}


def validate(root: Path) -> list[str]:
    errors = []
    for relative, expected in BASELINES.items():
        try:
            text = (root / relative).read_text(encoding="utf-8")
            if relative.endswith("SKILL.md"):
                text = text.split("---", 2)[2]  # Discovery metadata may name both hosts.
            if text.count(START) != 1 or text.count(END) != 1:
                raise ValueError("expected one delimited Codex-only routing block")
            before, rest = text.split(START)
            routing, after = rest.split(END)
            if "Codex desktop" not in routing:
                raise ValueError("routing block must identify the Codex desktop host")
            actual = hashlib.sha256((before + after).encode("utf-8")).hexdigest()
            if actual != expected:
                errors.append(f"{relative}: tested Claude coordinator text changed")
        except (OSError, ValueError, IndexError) as exc:
            errors.append(f"{relative}: {exc}")

    reference = root / "skills/run-milestone/references/codex-desktop.md"
    if not reference.is_file():
        errors.append("Missing Codex desktop coordinator reference")
    return errors


if __name__ == "__main__":
    errors = validate(Path(__file__).resolve().parent.parent)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        raise SystemExit(1)
    print("Claude milestone loop and runtime mappings match the tested baseline.")
