#!/bin/bash
#
# project-docs-sync.sh — sync <project>/{docs,reports}/**/*.md|.pdf and root README.md
#                        into an Obsidian vault, with live inotify watching.
#
# Vault layout (docs and reports segments are both kept):
#   <project>/docs/<rest>     -> Project Docs/<project>/docs/<rest>
#   <project>/reports/<rest>  -> Project Docs/<project>/reports/<rest>
#
# Usage:
#   SOURCE=/path/to/projects DEST=/path/to/vault project-docs-sync.sh
#
# Defaults (override via env):
#   SOURCE="$HOME/projects"
#   DEST="$HOME/Documents/Obsidian Vault/Project Docs"
#
# Requires: inotify-tools (for watch mode). The initial scan works without it.
#

SOURCE="${SOURCE:-$HOME/projects}"
DEST="${DEST:-$HOME/Documents/Obsidian Vault/Project Docs}"

echo "SOURCE=${SOURCE}"
echo "DEST=${DEST}"

# Copy a single eligible file into the vault, preserving <project>/ structure.
sync_one() {
    local file="$1"
    local relative project_path dir_kind rest vault_rel destination

    [ -f "$file" ] || return

    relative="${file#$SOURCE/}"

    # <project>/docs/<rest>     -> Project Docs/<project>/docs/<rest>     (segment kept)
    # <project>/reports/<rest>  -> Project Docs/<project>/reports/<rest>  (segment kept)
    # The split uses the LAST docs|reports segment, so nested dirs like
    # <project>/repo/docs/... behave the same as root-level ones.
    if [[ "$relative" =~ ^(.+)/(docs|reports)/(.*)$ ]]; then
        project_path="${BASH_REMATCH[1]}"
        dir_kind="${BASH_REMATCH[2]}"
        rest="${BASH_REMATCH[3]}"
        vault_rel="$dir_kind/$rest"
    else
        return
    fi

    destination="$DEST/$project_path/$(dirname "$vault_rel")"
    mkdir -p "$destination"

    cp -f "$file" "$destination/$(basename "$vault_rel")"

    echo "$(date '+%Y-%m-%d %H:%M:%S') — copied: $relative"
}

# Copy eligible files from a sync directory (a <project>/docs or <project>/reports dir)
sync_tree_dir() {
    local syncdir="$1"

    [ -d "$syncdir" ] || return

    while IFS= read -r -d '' file; do
        sync_one "$file"
    done < <(
        find "$syncdir" \
            -type f \
            \( -iname '*.md' -o -iname '*.pdf' \) \
            -not -path '*/node_modules/*' \
            -not -path '*/vendor/*' \
            -not -path '*/wp-content/*' \
            -not -path '*/.venv/*' \
            -print0
    )
}

# Copy README.md from a project root
sync_readme() {
    local projectdir="$1"
    local readme="$projectdir/README.md"

    [ -f "$readme" ] || return

    relative="${readme#$SOURCE/}"
    project_path="${relative%/README.md}"

    destination="$DEST/$project_path"
    mkdir -p "$destination"

    cp -f "$readme" "$destination/README.md"

    echo "$(date '+%Y-%m-%d %H:%M:%S') — copied README: $relative"
}

# Initial scan: find all existing docs and reports directories
while IFS= read -r -d '' syncdir; do
    sync_tree_dir "$syncdir"
done < <(
    find "$SOURCE" \
        -type d \
        \( -name docs -o -name reports \) \
        -not -path '*/node_modules/*' \
        -not -path '*/vendor/*' \
        -not -path '*/wp-content/*' \
        -not -path '*/.venv/*' \
        -print0
)

# Initial scan: find README.md files directly inside project directories
while IFS= read -r -d '' readme; do
    # READMEs inside docs/reports dirs are handled by sync_tree_dir above — keep one code path per file.
    case "$readme" in
        */docs/*|*/reports/*)
            continue
            ;;
    esac
    projectdir="$(dirname "$readme")"
    sync_readme "$projectdir"
done < <(
    find "$SOURCE" \
        -type f \
        -name README.md \
        -not -path '*/node_modules/*' \
        -not -path '*/vendor/*' \
        -not -path '*/wp-content/*' \
        -not -path '*/.venv/*' \
        -print0
)

# Watch for changes anywhere under projects.
# Process files inside docs/reports directories and README.md files in project roots.
if command -v inotifywait >/dev/null 2>&1; then
    inotifywait -m -r \
        -e close_write,moved_to \
        --format '%w%f' \
        "$SOURCE" |
    while read -r file; do

        case "$file" in
            */node_modules/*|*/vendor/*|*/wp-content/*|*/.venv/*)
                continue
                ;;
        esac

        # Files inside docs/reports dirs are handled generically below.
        case "$file" in
            */docs/*|*/reports/*)
                ;;
            *)
                # Outside sync dirs the only other thing we sync is a project-root README.md.
                if [[ "$(basename "$file")" == "README.md" ]]; then
                    projectdir="$(dirname "$file")"

                    # Ignore a README inside docs/reports or other nested directories.
                    case "$projectdir" in
                        */docs|*/docs/*|*/reports|*/reports/*)
                            continue
                            ;;
                    esac

                    sync_readme "$projectdir"
                fi
                continue
                ;;
        esac

        # Only markdown and PDF files
        case "$file" in
            *.md|*.MD|*.pdf|*.PDF)
                ;;
            *)
                continue
                ;;
        esac

        sync_one "$file"
    done
else
    echo "inotifywait not found — initial sync done. Install inotify-tools for live watch mode."
fi