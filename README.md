# project-docs-sync

Sync every `<project>/docs/**/*.md|.pdf` file and root-level `README.md` from a projects directory into an Obsidian vault — preserving the `Project Docs/<project>/...` structure — with **live file watching** so the vault stays current automatically.

This is the script Hal uses for Adapt Agency project documentation (e.g. `~/projects/leadresponse/docs/` → Obsidian). It's shared via GitHub so any Hermes setup (cloud or laptop) can clone and run it.

## How it works

1. **Initial scan** — walks all `docs/` dirs under `SOURCE`, copies every `.md`/`.pdf` into the vault, preserving structure. Also grabs root-level `README.md` files.
2. **Watch mode** — uses `inotifywait` to auto-sync on every file save (`close_write`) or move, so the vault stays current without re-running anything.
3. **Excludes** — `node_modules`, `vendor`, `wp-content`.

## Requirements

- Bash
- `inotify-tools` **only for live watch mode** (initial sync works without it):
  - Debian/Ubuntu/Mint: `sudo apt install inotify-tools`
  - macOS: `brew install inotify-tools`

## Install & run

```bash
# 1. Clone onto the laptop that holds your projects + Obsidian vault
git clone https://github.com/adaptagency/project-docs-sync.git
cd project-docs-sync

# 2. Run with defaults:
#    SOURCE = ~/projects , DEST = ~/Documents/Obsidian Vault/Project Docs
./project-docs-sync.sh

# Or custom paths:
SOURCE=/path/to/projects DEST="/path/to/Obsidian Vault/Project Docs" ./project-docs-sync.sh
```

The script stays running in watch mode. For a persistent background sync:

```bash
# Run on login
echo "@reboot cd ~/project-docs-sync && SOURCE=~/projects ./project-docs-sync.sh >> ~/project-docs-sync/sync.log 2>&1" | crontab -
```

## Resulting vault layout

```
Obsidian Vault/
└── Project Docs/
    ├── leadresponse/
    │   ├── README.md
    │   ├── build-plan.md
    │   ├── end-to-end-flow.md
    │   └── plans/
    │       └── dashboard-auth-implementation-plan.md
    ├── roktips/
    │   └── ...
    └── <project>/
        └── ...
```

---

*Shared by Hal — Chief of Staff, Adapt Agency*