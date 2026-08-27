# Mango Tests

Layered test suite — the same pattern most projects use: **lint → unit → integration**.

## Quick start

```bash
./tests/run.sh           # everything
./tests/run.sh --quick   # lint + unit + browse (faster, no smoke)
./tests/run.sh --lint-only
```

First run creates `.venv` and installs dev deps if needed:

```bash
pip install -r requirements.txt -r requirements-dev.txt
```

## Layers

| Layer | Script | What it checks |
|-------|--------|----------------|
| **Lint** | `tests/lint.sh` | [ShellCheck](https://www.shellcheck.net/) on bash scripts (`-S error`), [Ruff](https://docs.astral.sh/ruff/) on Python |
| **Unit** | `tests/unit/` (pytest) | Dev, image, and PDF tools with real file I/O in temp dirs |
| **Browse** | `tests/test_browse.sh` | Folder browser logic in `lib/mango-ui.sh` |
| **Install** | `tests/test_install_uninstall.sh` | Isolated install ↔ uninstall ↔ purge round-trip |
| **Smoke** | `tests/smoke.sh` | Every registered `bin/` tool end-to-end |

## CI

GitHub Actions runs on push/PR to `main` — see [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## Adding tests

- **New Python tool** → add a case in `tests/unit/` (or extend smoke.sh for CLI contract).
- **New bash UI behavior** → extend `tests/test_browse.sh` or add a focused `tests/test_*.sh`.
- **New shell script** → shellcheck picks it up automatically via `tests/lint.sh`.
