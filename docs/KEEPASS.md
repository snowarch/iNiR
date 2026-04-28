# KeePass Integration

The KeePass integration in iNiR provides a secure, fast, and visually integrated way to manage your passwords directly from the shell.

## Architecture

The system consists of three layers:

1.  **Backend Script (`scripts/quickshell-keepass`)**: A robust wrapper around `keepassxc-cli`. It handles the core logic, error reporting, and secure password caching using the system keyring.
2.  **Service (`services/KeePass.qml`)**: A background service that manages the database state (unlocked/locked), handles automated background locking via a timer, and exposes IPC targets.
3.  **UI Panel (`modules/keepass/KeepassPanel.qml`)**: A material-style overlay following the "SnowArch" aesthetic, providing search, entry management, and timer controls.

## Features

### 🔐 Secure Caching
Unlike standard scripts that might save passwords in plain text or volatile files, iNiR uses the **Secret Service API** (`secret-tool`). 
- The vault password is stored in your session keyring (Gnome Keyring or KWallet).
- The cache is automatically cleared when the timer expires or when manually locked.

### ⏳ Smart Timer System
The integration features a persistent background timer:
- **Interactive Slider**: Set the unlock duration (from 1 minute to 4 hours) before unlocking.
- **Title Bar Badge**: A live countdown timer (`MM:SS`) is visible in the title bar when the database is open.
- **Visual Progress**: A subtle progress bar inside the badge shows the remaining time relative to the initial setting.
- **Critical Alerts**: The timer turns **red** when less than 30 seconds remain.
- **Quick Reset**: Click the timer badge in the title bar to instantly reset the time to the maximum duration without re-entering the password.

### 🎨 Integrated UI
- **Auto-Focus**: Opening the panel automatically focuses the password field or the search field.
- **Pill Style**: All UI elements (selections, buttons, list items) use the "pill" shape and colors harmonized with your system theme (`colPrimary`).
- **High Contrast**: Text automatically inverts (`colOnPrimary`) when inside a selected "pill" for maximum readability.
- **Keyboard Friendly**: Fully navigable via keyboard. `Tab` cycles only between inputs and list; `Enter` selects or saves.

## Usage

### Commands
- `inir keepass toggle`: Opens or closes the KeePass panel.
- `inir keepass add`: Opens the panel in "Add Entry" mode, automatically pasting the primary selection into the password field.

### Keyboard shortcuts
Default bindings (from `scripts/lib/ipc-registry.sh`):
- `Super+P`: toggle the panel
- `Super+Ctrl+P`: open the panel in "Add Entry" mode with the primary selection pre-filled

Inside the panel:
- `Enter` on the password field: unlock the vault
- Start typing (in entries tab): focuses the search field
- `Down` / `Up`: navigate the entry list or vault picker list; `Up` at the top of the entry list returns focus to search
- `Enter` on a highlighted entry: open its detail card
- `Enter` again on an open entry: copy the password to the clipboard
- `Enter` on a highlighted vault (picker tab): open the unlock screen for it
- `Left` / `Right`: cycle through the three tabs — picker → entries → add — when the vault is unlocked
- `Tab`: enter the form fields on the create-vault or add-entry tabs (focus starts outside the fields so the arrows remain free for tab cycling)
- **Hold `Alt`**: reveal the selected entry's password while held — releasing hides it again (avoids moving keyboard focus away from the list)
- `Escape`: close the entry detail, or close the panel if no entry is open

### Configuration
Configure the vault location in `~/.config/illogical-impulse/config.json`:

```json
"keepass": {
  "vaultDir": "/path/to/your/vaults"
}
```

- `keepass.vaultDir`: directory containing your `.kdbx` vaults (defaults to `~/.local/share/keepassqs`).

Quickshell hot-reloads the config, so the panel picks up changes on the next toggle.

The picker lists all `.kdbx` files found in that directory, and new vaults can be created from the UI. The word-based generator uses the wordlist from the active UI locale (via `Translation.tr("keepass_wordlist")`).

## Security Model
1.  **Locking**: The database is locked and the keyring cache is cleared immediately when the timer reaches zero or the "Lock" button is pressed.
2.  **Transparency**: Real error messages from `keepassxc-cli` (e.g., "Database locked by another process") are displayed directly in the UI for better diagnostics.
3.  **Clipboard**: Passwords copied to the clipboard are automatically cleared from the `cliphist` history after a short delay (if `cliphist` is active).
