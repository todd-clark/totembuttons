"""Bundle the addon behind its original WoW entry point."""
import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ADDON = Path(__file__).resolve().parents[1] / "TotemButtons"


def bundle():
    toc = (ADDON / "TotemButtons.toc").read_text()
    modules = [line for line in toc.splitlines() if line.endswith(".lua")]
    assert modules[-1] == "TotemButtons.lua"
    assert set(modules) == {path.name for path in ADDON.glob("*.lua")}

    chunks = ["local addonName, addon = ...\naddon = addon or {}\n"]
    for filename in modules[:-1]:
        source = (ADDON / filename).read_text()
        chunks.append(f"\n-- {filename}\ndo\n    local function loadModule(...)\n{source}    end\n    loadModule(addonName, addon)\nend\n")
    entry = (ADDON / modules[-1]).read_text()
    declaration = "local addonName, addon = ...\n"
    assert entry.startswith(declaration)
    chunks.append("\n-- TotemButtons.lua\n" + entry[len(declaration):])
    toc = "\n".join(line for line in toc.splitlines() if line not in modules[:-1]) + "\n"
    return {
        "TotemButtons.toc": toc.encode(),
        "TotemButtons.lua": "".join(chunks).encode(),
        "Icon.tga": (ADDON / "Icon.tga").read_bytes(),
        "HighlightBorder.tga": (ADDON / "HighlightBorder.tga").read_bytes(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--install", type=Path, help="Directory of the installed addon")
    args = parser.parse_args()

    files = bundle()
    with ZipFile(args.archive, "w", ZIP_DEFLATED) as archive:
        for name, content in files.items():
            archive.writestr(f"TotemButtons/{name}", content)
    with ZipFile(args.archive) as archive:
        assert archive.testzip() is None
        for name, content in files.items():
            assert archive.read(f"TotemButtons/{name}") == content
    if args.install:
        for name, content in files.items():
            (args.install / name).write_bytes(content)
        assert all((args.install / name).read_bytes() == data for name, data in files.items())


if __name__ == "__main__":
    main()
