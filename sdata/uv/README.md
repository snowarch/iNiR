## Python Virtual Environment

Python packages are installed into a virtual environment instead of system-wide.
This avoids conflicts with system packages and makes updates more reliable.

### Location

- **venv**: `~/.local/state/quickshell/.venv`
- **env var**: `INIR_VENV` (legacy: `ILLOGICAL_IMPULSE_VIRTUAL_ENV`)

### Adding/Removing Packages

1. Edit `requirements.in` with the package name (check [PyPI](https://pypi.org/)).
2. Mirror the direct runtime constraint in `requirements.txt`.
3. Keep unrelated package versions unchanged unless that upgrade is part of the task.

`requirements.txt` is intentionally a direct minimum-version list, not a transitive
lock file. Do not run `uv pip compile` over it as routine maintenance: that rewrites
the file into a full resolved graph and can upgrade unrelated runtime packages.

### Installation

Packages are installed automatically by:
- `./setup install` (full installation)
- `./setup update` (upgrades any package below its minimum)
- `./setup doctor` (fixes missing packages and ones below their minimum)

When a script starts relying on a newer API of a package, raise that package's minimum
here in the same change: an existing venv keeps whatever version it has until a floor
says otherwise.

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
source $(eval echo ${INIR_VENV:-$ILLOGICAL_IMPULSE_VIRTUAL_ENV})/bin/activate
python your_script.py "$@"
deactivate
```

See `scripts/thumbnails/thumbgen-venv.sh` for an example.
