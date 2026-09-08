#!/usr/bin/env bash
set -e

# TwinTailLauncher Brazilian Portuguese Language Pack Installer
# Downloads pt_BR.json and installs it into the TwintailLauncher resources

REPO="zonaro/TwinTailLauncher-br-lang"
FILE="pt_BR.json"
URL="https://raw.githubusercontent.com/${REPO}/main/${FILE}"
TMP_FILE="/tmp/${FILE}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

info "TwinTailLauncher pt_BR language installer"
info "Downloading ${FILE} from ${URL}..."

if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "$URL" -o "$TMP_FILE"; then
        error "Failed to download ${FILE} via curl"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if ! wget -qO "$TMP_FILE" "$URL"; then
        error "Failed to download ${FILE} via wget"
        exit 1
    fi
else
    error "curl or wget is required but not found. Please install curl."
    exit 1
fi

if [ ! -s "$TMP_FILE" ]; then
    error "Downloaded file is empty"
    exit 1
fi

# Validate JSON
if command -v python3 >/dev/null 2>&1; then
    if ! python3 -m json.tool "$TMP_FILE" >/dev/null 2>&1; then
        error "Downloaded file is not valid JSON"
        exit 1
    fi
elif command -v jq >/dev/null 2>&1; then
    if ! jq empty "$TMP_FILE" >/dev/null 2>&1; then
        error "Downloaded file is not valid JSON (jq)"
        exit 1
    fi
fi

ok "Downloaded and validated ${FILE} ($(wc -c < "$TMP_FILE") bytes)"

# Candidate locales directories
CANDIDATES=(
    "/usr/lib/twintaillauncher/resources/locales"
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

FOUND_DIRS=()
for dir in "${CANDIDATES[@]}"; do
    # Expand $HOME already done; check if en_US.json exists (indicator of correct dir)
    if [ -f "$dir/en_US.json" ] && [ -d "$dir" ]; then
        # Deduplicate
        if [[ ! " ${FOUND_DIRS[*]} " =~ " ${dir} " ]]; then
            FOUND_DIRS+=("$dir")
        fi
    elif [ -d "$dir" ]; then
        # If directory exists but no en_US, still consider but lower priority later
        :
    fi
done

# If still empty, do a filesystem search (limited to /usr and /opt to avoid slowness)
if [ ${#FOUND_DIRS[@]} -eq 0 ]; then
    warn "No locales directory found via candidates, searching filesystem (this may take a few seconds)..."
    while IFS= read -r en_file; do
        dir=$(dirname "$en_file")
        if [[ ! " ${FOUND_DIRS[*]} " =~ " ${dir} " ]]; then
            FOUND_DIRS+=("$dir")
            info "Found via search: $dir"
        fi
    done < <(find /usr /opt /var/lib/flatpak -type f -name "en_US.json" 2>/dev/null | grep -i -E "twintail|ttl" | head -n 10)

    # Fallback: search any en_US.json under locales named path if no twintail match
    if [ ${#FOUND_DIRS[@]} -eq 0 ]; then
        while IFS= read -r en_file; do
            dir=$(dirname "$en_file")
            # Heuristic: check if parent contains twintail launcher strings or is under resources/locales
            if [[ "$dir" == *"/resources/locales"* ]]; then
                FOUND_DIRS+=("$dir")
                info "Found generic locales dir: $dir"
                break
            fi
        done < <(find / -type f -path "*/resources/locales/en_US.json" 2>/dev/null | head -n 5)
    fi
fi

if [ ${#FOUND_DIRS[@]} -eq 0 ]; then
    error "Could not find TwintailLauncher installation."
    echo ""
    echo "Tried candidates:"
    for c in "${CANDIDATES[@]}"; do
        echo "  - $c"
    done
    echo ""
    echo "Manual installation:"
    echo "  1. Locate your TwintailLauncher installation (where en_US.json lives):"
    echo "     find /usr /opt \$HOME -name \"en_US.json\" 2>/dev/null | grep -i twintail"
    echo "  2. Copy the file:"
    echo "     sudo cp \"$TMP_FILE\" \"/path/to/resources/locales/pt_BR.json\""
    echo "  3. Restart TwintailLauncher and select Português (Brasil) in Settings > Language"
    exit 1
fi

info "Found ${#FOUND_DIRS[@]} locales directory(ies):"
for d in "${FOUND_DIRS[@]}"; do
    echo "  - $d"
done
echo ""

SUCCESS_COUNT=0
for dest_dir in "${FOUND_DIRS[@]}"; do
    dest_file="$dest_dir/$FILE"
    info "Installing to $dest_file..."

    if [ -w "$dest_dir" ]; then
        if cp "$TMP_FILE" "$dest_file" 2>/dev/null; then
            chmod 644 "$dest_file" 2>/dev/null || true
            ok "Installed to $dest_file (no sudo needed)"
            SUCCESS_COUNT=$((SUCCESS_COUNT+1))
        else
            warn "Failed to copy to $dest_file without sudo"
        fi
    else
        if sudo cp "$TMP_FILE" "$dest_file" 2>/dev/null; then
            sudo chmod 644 "$dest_file" 2>/dev/null || true
            ok "Installed to $dest_file (via sudo)"
            SUCCESS_COUNT=$((SUCCESS_COUNT+1))
        else
            warn "Failed to copy to $dest_file even with sudo"
            # Try with sudo mkdir -p if dir missing
            if sudo mkdir -p "$dest_dir" 2>/dev/null && sudo cp "$TMP_FILE" "$dest_file" 2>/dev/null; then
                sudo chmod 644 "$dest_file" 2>/dev/null || true
                ok "Created $dest_dir and installed"
                SUCCESS_COUNT=$((SUCCESS_COUNT+1))
            fi
        fi
    fi

    # Verify
    if [ -f "$dest_file" ]; then
        ok "Verified: $dest_file exists ($(wc -c < "$dest_file") bytes)"
    fi
done

echo ""
if [ $SUCCESS_COUNT -gt 0 ]; then
    ok "Successfully installed pt_BR.json to $SUCCESS_COUNT location(s)!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart TwintailLauncher (fully close from tray if needed)"
    echo "  2. Go to Launcher Settings > General > Application language"
    echo "  3. Select \"Português (Brasil)\" and restart if prompted"
    echo ""
    echo "To verify:"
    echo "  ls -lh \"${FOUND_DIRS[0]}/pt_BR.json\" && cat \"${FOUND_DIRS[0]}/pt_BR.json\" | head -n 5"
else
    error "Failed to install to any location"
    exit 1
fi

# Cleanup? Keep tmp for debugging, but remove after success optional
# rm -f "$TMP_FILE"
