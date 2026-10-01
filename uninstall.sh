#!/usr/bin/env bash
set -e

# TwinTailLauncher Brazilian Portuguese Language Pack Uninstaller
# Removes pt_BR.json from every detected TwintailLauncher resources/locales directory

FILE="pt_BR.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        -h|--help)
            cat <<'USAGE'
Usage: uninstall.sh [--dry-run] [-h]

Removes pt_BR.json from every detected TwintailLauncher locales directory.

  --dry-run, -n   Show what would be removed without deleting anything.
  -h, --help      Show this help.

Examples:
  curl -fsSL https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/uninstall.sh | bash
  bash <(curl -fsSL https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/uninstall.sh) --dry-run
USAGE
            exit 0
            ;;
        *)
            error "Unknown option: $arg"
            echo "Run with --help for usage."
            exit 1
            ;;
    esac
done

info "TwinTailLauncher pt_BR language uninstaller"
if [ "$DRY_RUN" -eq 1 ]; then
    info "Dry run: no file will be deleted."
fi
info "Looking for ${FILE} in TwintailLauncher locales directories..."

# Candidate locales directories (mirrors install.sh)
CANDIDATES=(
    "/usr/lib/twintaillauncher/resources/locales"
    "/usr/share/twintaillauncher/resources/locales"
    "/usr/local/lib/twintaillauncher/resources/locales"
    "/opt/twintaillauncher/resources/locales"
    "/opt/TwintailLauncher/resources/locales"
    "/var/lib/flatpak/app/app.twintaillauncher.ttl/current/active/files/lib/twintaillauncher/resources/locales"
    "$HOME/.local/share/flatpak/app/app.twintaillauncher.ttl/current/active/files/lib/twintaillauncher/resources/locales"
    "/var/lib/flatpak/app/app.twintaillauncher.ttl/current/active/files/share/twintaillauncher/resources/locales"
)

# Auto-detect via binary location (AUR, deb, etc.)
if command -v twintaillauncher >/dev/null 2>&1; then
    BIN_PATH=$(command -v twintaillauncher)
    BIN_REAL=$(readlink -f "$BIN_PATH" 2>/dev/null || echo "$BIN_PATH")
    BIN_DIR=$(dirname "$BIN_REAL")
    CANDIDATES+=(
        "$BIN_DIR/resources/locales"
        "$BIN_DIR/../lib/twintaillauncher/resources/locales"
        "$BIN_DIR/../share/twintaillauncher/resources/locales"
        "$BIN_DIR/../lib/twintailLauncher/resources/locales"
    )
    info "Found twintaillauncher binary at: $BIN_REAL"
fi

# Also check relative to common binary names (case variations)
for bin in twintaillauncher ttl twintail-launcher TwintailLauncher; do
    if command -v "$bin" >/dev/null 2>&1; then
        p=$(readlink -f "$(command -v "$bin")" 2>/dev/null || command -v "$bin")
        d=$(dirname "$p")
        CANDIDATES+=("$d/resources/locales" "$d/../lib/twintaillauncher/resources/locales")
    fi
done

# Collect directories that actually hold our file
FOUND_FILES=()
for dir in "${CANDIDATES[@]}"; do
    if [ -f "$dir/$FILE" ]; then
        FOUND_FILES+=("$dir/$FILE")
    fi
done

# If still empty, search the filesystem (limited scope to stay fast)
if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    warn "No ${FILE} found via candidates, searching filesystem (this may take a few seconds)..."
    while IFS= read -r pt_file; do
        FOUND_FILES+=("$pt_file")
        info "Found via search: $pt_file"
    done < <(find /usr /opt /var/lib/flatpak "$HOME/.local/share/flatpak" \
        -type f -name "$FILE" -path "*resources/locales*" 2>/dev/null | head -n 20)

    # Fallback: any */resources/locales/pt_BR.json anywhere
    if [ ${#FOUND_FILES[@]} -eq 0 ]; then
        while IFS= read -r pt_file; do
            FOUND_FILES+=("$pt_file")
            info "Found generic locales file: $pt_file"
            break
        done < <(find / -type f -path "*/resources/locales/$FILE" 2>/dev/null | head -n 5)
    fi
fi

if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    ok "Nothing to remove — no ${FILE} found. It seems the language pack is not installed."
    echo ""
    echo "Next steps:"
    echo "  Nothing to do. If you still see Portuguese, restart TwintailLauncher"
    echo "  (tray icon -> Quit) and reopen it."
    exit 0
fi

info "Found ${#FOUND_FILES[@]} installed file(s):"
for f in "${FOUND_FILES[@]}"; do
    echo "  - $f"
done
echo ""

SUCCESS_COUNT=0
for dest_file in "${FOUND_FILES[@]}"; do
    dest_dir=$(dirname "$dest_file")

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] Would remove $dest_file"
        SUCCESS_COUNT=$((SUCCESS_COUNT+1))
        continue
    fi

    info "Removing $dest_file..."
    if [ -w "$dest_dir" ]; then
        if rm -f "$dest_file" 2>/dev/null; then
            ok "Removed $dest_file"
            SUCCESS_COUNT=$((SUCCESS_COUNT+1))
        else
            warn "Failed to remove $dest_file without sudo"
        fi
    else
        if sudo rm -f "$dest_file" 2>/dev/null; then
            ok "Removed $dest_file (via sudo)"
            SUCCESS_COUNT=$((SUCCESS_COUNT+1))
        else
            warn "Failed to remove $dest_file even with sudo"
        fi
    fi

    # Verify
    if [ ! -f "$dest_file" ]; then
        ok "Verified: $dest_file is gone"
    fi
done

echo ""
if [ $SUCCESS_COUNT -gt 0 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        ok "Dry run finished: $SUCCESS_COUNT file(s) would be removed."
    else
        ok "Successfully removed ${FILE} from $SUCCESS_COUNT location(s)!"
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Fully close TwintailLauncher (tray -> Quit) and reopen it"
    echo "  2. Go to Launcher Settings > General > Application language"
    echo "  3. Select another language (English is the default)"
    echo ""
    echo "To verify:"
    echo "  find /usr /opt /var/lib/flatpak \$HOME/.local/share/flatpak -name \"${FILE}\" -path \"*resources/locales*\" 2>/dev/null"
    echo "  # should print nothing"
else
    error "Failed to remove the language pack from any location"
    echo ""
    echo "Manual removal:"
    echo "  1. Locate the file:"
    echo "     find /usr /opt \$HOME -name \"${FILE}\" 2>/dev/null | grep -i twintail"
    echo "  2. Delete it:"
    echo "     sudo rm /path/to/resources/locales/${FILE}"
    exit 1
fi