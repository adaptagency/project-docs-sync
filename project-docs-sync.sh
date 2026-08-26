#!/bin/bash
#
# project-docs-sync.sh — sync <project>/docs/**/*.md|.pdf and root README.md
#                        into an Obsidian vault, with live inotify watching.
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

# Copy eligible files from a docs directory
sync_docs() {
    local docsdir="$1"

    [ -d "$docsdir" ] || return

    while IFS= read -r -d '' file; do
        relative="${file#$SOURCE/}"
        project_path="${relative%%/docs/*}"
        docs_relative="${relative#*/docs/}"

        destination="$DEST/$project_path/$(dirname "$docs_relative")"
        mkdir -p "$destination"

        cp -f "$file" "$destination/$(basename "$docs_relative")"

        echo "$(date '+%Y-%m-%d %H:%M:%S') — copied: $relative"
    done < <(
        find "$docsdir" \
            -type f \
            \( -iname '*.md' -o -iname '*.pdf' \) \
            -not -path '*/node_modules/*' \
            -not -path '*/vendor/*' \
            -not -path '*/wp-content/*' \
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

# Initial scan: find all existing docs directories
while IFS= read -r -d '' docsdir; do
    sync_docs "$docsdir"
done < <(
    find "$SOURCE" \
        -type d \
        -name docs \
        -not -path '*/node_modules/*' \
        -not -path '*/vendor/*' \
        -not -path '*/wp-content/*' \
        -print0
)

# Initial scan: find README.md files directly inside project directories
while IFS= read -r -d '' readme; do
    projectdir="$(dirname "$readme")"
    sync_readme "$projectdir"
done < <(
    find "$SOURCE" \
        -type f \
        -name README.md \
        -not -path '*/node_modules/*' \
        -not -path '*/vendor/*' \
        -not -path '*/wp-content/*' \
        -print0
)

# Watch for changes anywhere under projects.
# Process files inside docs directories and README.md files in project roots.
if command -v inotifywait >/dev/null 2>&1; then
    inotifywait -m -r \
        -e close_write,moved_to \
        --format '%w%f' \
        "$SOURCE" |
    while read -r file; do

        case "$file" in
            */node_modules/*|*/vendor/*|*/wp-content/*)
                continue
                ;;
        esac

        # README.md directly inside a project directory
        if [[ "$(basename "$file")" == "README.md" ]]; then

            projectdir="$(dirname "$file")"

            # Ignore a README inside docs or other nested directories.
            case "$projectdir" in
                */docs|*/docs/*)
                    continue
                    ;;
            esac

            sync_readme "$projectdir"
            continue
        fi

        # Markdown and PDF files inside docs directories
        case "$file" in
            *.md|*.MD|*.pdf|*.PDF)
                ;;
            *)
                continue
                ;;
        esac

        case "$file" in
            */docs/*)
                ;;
            *)
                continue
                ;;
        esac

        relative="${file#$SOURCE/}"
        project_path="${relative%%/docs/*}"
        docs_relative="${relative#*/docs/}"

        destination="$DEST/$project_path/$(dirname "$docs_relative")"
        mkdir -p "$destination"

        cp -f "$file" "$destination/$(basename "$docs_relative")"

        echo "$(date '+%Y-%m-%d %H:%M:%S') — copied: $relative"
    done
else
    echo "inotifywait not found — initial sync done. Install inotify-tools for live watch mode."
fi