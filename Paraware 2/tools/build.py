"""Bundle the editable source and original logo into the single-file release."""
import argparse
import base64
from pathlib import Path
import textwrap

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--check", action="store_true", help="Verify the committed release matches the source")
args = parser.parse_args()
source = (ROOT / "src/Paraware.lua").read_text(encoding="utf-8")
marker = "-- EMBEDDED_LOGO_DATA\n"
if source.count(marker) != 1:
    raise SystemExit("Expected exactly one embedded-logo marker in src/Paraware.lua")
start, _, end = source.partition(marker)
asset = base64.b64encode((ROOT / "assets/paraware-logo.png").read_bytes()).decode("ascii")
logo = "embeddedLogo = [[\n" + "\n".join(textwrap.wrap(asset, 120)) + "\n]]\n"
bundle = (start + logo + end).encode("utf-8")
output = ROOT / "Paraware.lua"
if args.check:
    if not output.exists() or output.read_bytes() != bundle:
        raise SystemExit("Paraware.lua is out of date. Run python3 tools/build.py and commit the result.")
    print("PASS: committed Paraware.lua matches source and embedded logo")
else:
    output.write_bytes(bundle)
    print("Built Paraware.lua")
