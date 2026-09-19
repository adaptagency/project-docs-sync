Hi Antonina 👋

Here's a quick setup guide to get your project docs syncing into your Obsidian vault. It's a small script that watches your projects folder and automatically copies any `docs/` and `reports/` files plus root `README.md` into your vault.

## What you'll need

- **GitHub** — a personal account with a classic PAT (Settings → Developer settings → Personal access tokens → Tokens (classic), give it `repo` scope)
- **Git** on your laptop — `git --version` to check; if missing, install it
- **inotify-tools** (Linux only — for auto-watch mode):
  - Ubuntu/Mint: `sudo apt install inotify-tools`
  - macOS: the script works without watch mode
- **Obsidian vault** — wherever you keep it

## 1. Clone the sync tool

```bash
git clone https://github.com/adaptagency/project-docs-sync.git
cd project-docs-sync
```

## 2. Set up your projects folder → GitHub

This is the key workflow — your cloud Hermes can only edit things that are on GitHub:

```bash
# In each of your project folders, init git and push to GitHub:
cd ~/projects/my-project
git init
git add -A
git commit -m "Initial commit"
gh repo create my-project --public --source=. --remote=origin --push
# (or create the repo on github.com first, then:)
# git remote add origin https://github.com/YOUR_USERNAME/my-project.git
# git push -u origin main
```

## 3. Run the sync script

```bash
# Default: watches ~/projects/ → copies docs into ~/Documents/Obsidian Vault/Project Docs/
./project-docs-sync.sh

# Custom paths if your folders are different:
SOURCE=~/my-projects DEST="~/My Obsidian/Project Docs" ./project-docs-sync.sh
```

The script stays running. Every time you edit a `docs/` file, it copies to your vault automatically.

## 4. The round-trip workflow

```
Your laptop:  edit projects/ → git push → GitHub
                                            ↓
Cloud Hermes: git pull → works → git push
                                            ↓
Your laptop:  git pull → sync script mirrors docs into Obsidian
```

## 5. Make it start on boot (Linux)

```bash
echo "@reboot cd ~/project-docs-sync && SOURCE=~/projects ./project-docs-sync.sh >> ~/project-docs-sync/sync.log 2>&1" | crontab -
```

---

That's it. Any questions, Steve or Hal can help.

— Hal, Chief of Staff, Adapt Agency