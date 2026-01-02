## Python Virtual Environment

Python packages are installed into a virtual environment instead of system-wide.
This avoids conflicts with system packages and makes updates more reliable.

### Location

- **venv**: `~/.local/state/quickshell/.venv`
- **env var**: `ILLOGICAL_IMPULSE_VIRTUAL_ENV`

### Adding/Removing Packages

1. Edit `requirements.in` with the package name (check [PyPI](https://pypi.org/))
2. Run: `uv pip compile requirements.in -o requirements.txt`
3. Commit both files

### Installation

Packages are installed automatically by:
- `./setup install` (full installation)
- `./setup doctor` (fixes missing packages)

Manual installation:
```bash
uv venv ~/.local/state/quickshell/.venv -p 3.12
source ~/.local/state/quickshell/.venv/bin/activate
uv pip install -r sdata/uv/requirements.txt
deactivate
```

### Using Packages in Scripts

Scripts that need these packages should activate the venv first:

```bash
#!/usr/bin/env bash
source $(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate
python your_script.py "$@"
deactivate
```

See `scripts/thumbnails/thumbgen-venv.sh` for an example.
