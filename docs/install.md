# Mango — Installation & Setup

![platform](https://img.shields.io/badge/platform-macOS_|_Linux_|_Windows-2563EB?style=for-the-badge)
![python](https://img.shields.io/badge/python-3.9+-3776AB?style=for-the-badge)

Install Mango, its Python environment, and optional system tools. After this, run `mango` from a terminal.

Already installed? **[Interface Guide](mango-ui.md)**

---

## Table of Contents

- [Quick start](#quick-start)
- [Setup script](#setup-script)
- [What you need](#what-you-need)
- [Step-by-step setup](#step-by-step-setup)
- [Verify your install](#verify-your-install)
- [Add Mango to your PATH](#add-mango-to-your-path)
- [Platform notes](#platform-notes)
- [What each tool needs](#what-each-tool-needs)
- [Troubleshooting](#troubleshooting)
- [Related](#related)

---

## Quick start

**One-liner** (installs to `~/.local/share/mango`, then runs offline):

```bash
curl -fsSL https://raw.githubusercontent.com/tmarhguy/tools/main/setup.sh | bash -s -- --yes --link
```

**From a clone:**

```bash
git clone https://github.com/tmarhguy/tools.git
cd tools
./setup.sh
```

`setup.sh` creates the venv, installs Python packages, makes scripts executable, can install `ffmpeg`, runs `mango doctor` on first install, and can put every command on your PATH. **Re-runs skip pip and doctor when nothing changed** — typically under half a second.

Non-interactive: `./setup.sh --yes`

---

## Setup script

[`setup.sh`](../setup.sh) automates the full install.

| Mode | Command |
|------|---------|
| **One-liner** | `curl -fsSL https://raw.githubusercontent.com/tmarhguy/tools/main/setup.sh \| bash` |
| **From clone** | `./setup.sh` |
| **Non-interactive** | `./setup.sh --yes` |
| **Re-run (fast)** | `./setup.sh` — skips pip/doctor when deps unchanged |
| **Force dependency check** | `./setup.sh --doctor` |
| **Pull latest + setup** | `./setup.sh --update` |
| **Skip ffmpeg prompt** | `./setup.sh --no-ffmpeg` |
| **Add to PATH** | `./setup.sh --link` (installs all commands to `~/.local/bin`) |

**Install location:** `~/.local/share/mango` (override with `MANGO_INSTALL_DIR`)

---

## What you need

| Requirement | Used for |
|-------------|----------|
| **Python 3.9+** | PDF, image, and developer tools |
| **pip + venv** | Isolated Python packages |
| **ffmpeg** | Video → GIF, compress video, extract audio, trim |
| **gifsicle** *(optional)* | GIF optimization (auto-built into `.tools/` on first run if missing) |
| **Ghostscript** *(optional)* | `compress-pdf` only |

Developer tools (JSON, CSV, base64, hashes) need **Python only**.

---

## Step-by-step setup

Manual install if you are not using `setup.sh`:

### 1. Clone

```bash
git clone https://github.com/tmarhguy/tools.git
cd tools
```

### 2. Virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate          # macOS / Linux
# .venv\Scripts\activate           # Windows
```

Re-activate with `source .venv/bin/activate` in each new terminal.

### 3. Python packages

```bash
pip install -r requirements.txt
```

Installs **Pillow**, **pypdf**, **pdf2docx**, and **pymupdf**.

### 4. System tools

**ffmpeg** (video & audio):

```bash
brew install ffmpeg                # macOS
sudo apt install ffmpeg            # Ubuntu / Debian
winget install Gyan.FFmpeg         # Windows
```

**Ghostscript** (optional — `compress-pdf` only):

```bash
brew install ghostscript           # macOS
sudo apt install ghostscript       # Linux
winget install Artifex.GhostScript # Windows
```

### 5. Run

```bash
./mango              # interactive hub
./mango doctor       # dependency check
```

How the hub works: **[mango-ui.md](mango-ui.md)**

---

## Verify your install

```bash
./mango doctor
```

Checks Python, the venv, pip packages, and system commands, and prints **fix commands** for anything missing.

```
  ✔ Python: Python 3.x.x (.venv/bin/python)
  ✔ Virtual env: .../tools/.venv
  ✔ Python package: Pillow
  ✔ Command: ffmpeg
```

Full test suite (lint, unit, browse, smoke):

```bash
./tests/run.sh           # everything
./tests/run.sh --quick   # skip smoke
./tests/smoke.sh         # smoke only
```

You should see `All requested tests passed.` Details: [tests/README.md](../tests/README.md)

---

## Add Mango to your PATH

So `mango` (and `format-json`, `merge-pdf`, …) work from any directory.

```bash
./setup.sh --link --yes
```

That installs wrappers to `~/.local/bin` and adds it to your shell config. Open a new terminal:

```bash
mango
format-json data.json
```

**Manual PATH** (from a clone):

```bash
export PATH="$PATH:/path/to/tools/bin"
```

**Skip global install:**

```bash
./setup.sh --no-link          # don't install to ~/.local/bin
./setup.sh --link --no-path   # install commands but don't edit shell config
```

---

## Uninstall

```bash
mango uninstall
mango uninstall --purge       # wrappers + ~/.local/share/mango, no prompts
mango uninstall --keep-data   # remove PATH commands only
```

From a clone (same script):

```bash
./uninstall.sh
./uninstall.sh --yes
./uninstall.sh --purge
```

That removes every Mango wrapper under `~/.local/bin` (including ones pointed at a git clone), strips the PATH block from your shell config, and can delete the offline install at `~/.local/share/mango`.

**Fresh production reinstall test:**

```bash
mango uninstall --purge
hash -r
curl -fsSL https://raw.githubusercontent.com/tmarhguy/mango/main/setup.sh | bash -s -- --yes --link
mango doctor
```

---

## Platform notes

### macOS

- Install [Homebrew](https://brew.sh) if you don't have it.
- `brew install python ffmpeg ghostscript`

### Linux (Debian / Ubuntu)

```bash
sudo apt update
sudo apt install python3 python3-venv python3-pip ffmpeg ghostscript
```

### Windows

- Install Python from [python.org](https://www.python.org/downloads/) (check **Add to PATH**).
- Use `winget` for ffmpeg and Ghostscript (see [What you need](#what-you-need)).
- Activate the venv with `.venv\Scripts\activate` in PowerShell or CMD.

---

## What each tool needs

| Category | Tools | Dependencies |
|----------|-------|----------------|
| **Video & Audio** | GIF, compress, extract audio, trim | `ffmpeg` (+ `gifsicle` for GIF optimization) |
| **Image** | compress, convert, strip EXIF | Python + `Pillow` |
| **PDF** | merge, split, rotate, jpg→pdf | Python + `pypdf` |
| **PDF** | PDF → Word | Python + `pdf2docx` |
| **PDF** | PDF → JPG | Python + `pymupdf` |
| **PDF** | compress | Ghostscript (`gs`) — optional; other PDF tools do not need it |
| **Developer** | JSON, CSV, base64, hash | Python 3 stdlib only |

Flags for a given tool: `./bin/<tool> --help`

---

## Troubleshooting

**Setup script fails on `curl | bash`**

Ensure `git` and `python3` are installed, then:

```bash
curl -fsSL https://raw.githubusercontent.com/tmarhguy/tools/main/setup.sh | bash -s -- --yes
```

**`mango doctor` reports a missing Python package**

```bash
./setup.sh --yes
# or:
source .venv/bin/activate
pip install -r requirements.txt
```

**`ffmpeg` not found**

Install via your package manager (see [Platform notes](#platform-notes)), then `./mango doctor`.

**`Permission denied` when running `./mango`**

```bash
chmod +x mango bin/*
```

**PDF → Word produces garbled output**

Works best on **text-based** PDFs. Scanned/image PDFs need OCR (not yet supported).

**Mango says "interactive terminal UI" and exits**

Run `./mango` directly in a terminal — not piped, and not from a non-TTY environment.

---

## Related

- [mango-ui.md](mango-ui.md) — menus, file browser, conversion flow
- [Readme.md](../Readme.md) — overview and full tool list
- [setup.sh](../setup.sh) — automated install script
