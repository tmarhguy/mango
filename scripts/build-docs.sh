#!/usr/bin/env bash
# Build the static technical manual with Asciidoctor.
# No dependency installation happens here; install Asciidoctor first:
#   macOS:  brew install asciidoctor
#   Linux:  sudo apt-get install -y asciidoctor   (or: gem install asciidoctor)
#   Other:  gem install asciidoctor
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SRC="$REPO_ROOT/docs/index.adoc"
OUT_DIR="$REPO_ROOT/build/docs"
OUT_FILE="$OUT_DIR/index.html"

# Resolve Asciidoctor safe-mode paths relative to this project, not the caller.
cd "$REPO_ROOT"

if ! command -v asciidoctor >/dev/null 2>&1; then
  echo "error: asciidoctor not found on PATH." >&2
  echo "Install it first:" >&2
  echo "  macOS:  brew install asciidoctor" >&2
  echo "  Debian/Ubuntu: sudo apt-get install -y asciidoctor" >&2
  echo "  RubyGems (any OS with Ruby): gem install asciidoctor" >&2
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "error: missing source $SRC" >&2
  exit 1
fi

mkdir -p "$OUT_DIR/theme" "$OUT_DIR/images"

# Version stamp, RISC-V-spec style ("Version <sha>, <date>" under the
# title). Derived from git at build time; falls back to the build date
# outside a git checkout. Pure Asciidoctor revision attributes.
REVDATE="$(git -C "$REPO_ROOT" log -1 --format=%cs 2>/dev/null || date +%F)"
REVNUM="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unversioned)"

python3 "$REPO_ROOT/scripts/prepare-docs.py" head
DOCINFO_DIR="$(mktemp -d "$REPO_ROOT/docs/theme/.docinfo.XXXXXX")"
trap 'rm -rf "$DOCINFO_DIR"' EXIT
cp "$OUT_DIR/theme/docinfo.html" "$DOCINFO_DIR/docinfo.html"

# Single-page manual. docinfo=shared + docinfodir pulls docs/theme/docinfo.html
# (CSS/JS injection) without editing generated HTML afterwards.
asciidoctor \
  --failure-level WARN \
  --backend html5 \
  --safe-mode safe \
  --attribute docinfo=shared \
  --attribute docinfodir="$DOCINFO_DIR" \
  --attribute revdate="$REVDATE" \
  --attribute revnumber="$REVNUM" \
  --out-file "$OUT_FILE" \
  "$SRC"

# Theme assets live next to the HTML so relative paths in docinfo.html resolve.
for asset in docs.css nav.js search.js; do
  cp "$REPO_ROOT/docs/theme/$asset" "$OUT_DIR/theme/$asset"
done

# Figures referenced via :imagesdir: images.
if [ -d "$REPO_ROOT/docs/images" ]; then
  cp -R "$REPO_ROOT/docs/images/." "$OUT_DIR/images/"
fi

# Demo GIF: single source of truth is media/demo/; stage it next to the
# figures so image::sealion-demo.gif[] resolves in the built manual.
if [ -f "$REPO_ROOT/media/demo/sealion-demo.gif" ]; then
  cp "$REPO_ROOT/media/demo/sealion-demo.gif" "$OUT_DIR/images/sealion-demo.gif"
fi

python3 "$REPO_ROOT/scripts/prepare-docs.py" page
python3 "$REPO_ROOT/scripts/export-docs-template.py"

echo "Built $OUT_FILE"
