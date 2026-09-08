# TwinTailLauncher Brazilian Portuguese Language Pack 🇧🇷

Brazilian Portuguese (`pt_BR`) translation for [TwintailLauncher](https://github.com/TwintailTeam/TwintailLauncher) — a multi-platform launcher for anime games.

> **pt_BR** baseado em `en_US.json` (stable) com 466 chaves, 100% de paridade. Testado em Linux (Wayland/KDE) com `target/debug/resources/locales/pt_BR.json` e `storage.db` `app_lang = pt_BR`.

---

## 🚀 One-liner Installation / Instalação com um comando

**Via curl + bash (recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/install.sh | bash
```

**Alternative (bash process substitution):**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/install.sh)
```

**Via wget:**
```bash
wget -qO- https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/install.sh | bash
```

The script will:
1. Download `pt_BR.json` to `/tmp/pt_BR.json` and validate JSON.
2. Auto-detect TwintailLauncher installation (`en_US.json` locations):
   - `/usr/lib/twintaillauncher/resources/locales`
   - `/usr/share/twintaillauncher/resources/locales`
   - `/opt/twintaillauncher/resources/locales`
   - Flatpak: `/var/lib/flatpak/app/app.twintaillauncher.ttl/.../resources/locales` and `~/.local/share/flatpak/...`
   - Auto-detect via `which twintaillauncher` and `find /usr /opt -name "en_US.json" | grep -i twintail`
3. Copy `pt_BR.json` with `sudo` if needed, set `644` permissions.
4. Print next steps (restart launcher → Settings → Language).

> O script via `curl` baixa o `pt_BR.json`, busca o TwintailLauncher instalado na máquina (deb/flatpak/AUR/binário) e coloca o arquivo na pasta correta (`resources/locales`).

---

## 📋 Manual Installation / Instalação Manual

If the auto-installer fails or you prefer manual:

```bash
# 1. Download
curl -fsSL https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/pt_BR.json -o /tmp/pt_BR.json
# or
wget -qO /tmp/pt_BR.json https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/pt_BR.json

# 2. Validate (optional)
python3 -m json.tool /tmp/pt_BR.json > /dev/null && echo "JSON ok"

# 3. Find your locales dir
find /usr /opt $HOME -name "en_US.json" 2>/dev/null | grep -i twintail
# Example results:
# /usr/lib/twintaillauncher/resources/locales/en_US.json
# /var/lib/flatpak/app/app.twintaillauncher.ttl/current/active/files/lib/twintaillauncher/resources/locales/en_US.json

# 4. Copy (replace <path> with your result)
sudo cp /tmp/pt_BR.json /usr/lib/twintaillauncher/resources/locales/pt_BR.json
sudo chmod 644 /usr/lib/twintaillauncher/resources/locales/pt_BR.json

# For Flatpak user install:
cp /tmp/pt_BR.json ~/.local/share/flatpak/app/app.twintaillauncher.ttl/current/active/files/lib/twintaillauncher/resources/locales/pt_BR.json

# 5. Restart TwintailLauncher
```

Then: **Launcher Settings → General → Application language → Português (Brasil)**

---

## 🔄 After Installation

1. Fully close TwintailLauncher (tray → Quit).
2. Reopen → `Launcher Settings` should show `Configurações do Launcher` if pt_BR is selected.
3. If language doesn't appear, verify:
   ```bash
   ls -lh /usr/lib/twintaillauncher/resources/locales/pt_BR.json
   ls -lh /var/lib/flatpak/app/app.twintaillauncher.ttl/current/active/files/lib/twintaillauncher/resources/locales/pt_BR.json
   sqlite3 ~/.local/share/twintaillauncher/storage.db "SELECT app_lang FROM settings WHERE id=1;"
   # should be pt_BR after you select it in UI
   ```

---

## 🗑️ Uninstallation / Desinstalação

```bash
# Find and remove
find /usr /opt /var/lib/flatpak $HOME/.local/share/flatpak -name "pt_BR.json" -path "*twintail*resources/locales*" 2>/dev/null
# Then
sudo rm /usr/lib/twintaillauncher/resources/locales/pt_BR.json
# or for flatpak
rm ~/.local/share/flatpak/app/app.twintaillauncher.ttl/current/active/files/lib/twintaillauncher/resources/locales/pt_BR.json
```

Select another language in Launcher Settings to revert.

---

## 📦 Contents

```
/pt_BR.json   # 539 lines, 466 keys, based on en_US.json (stable)
/install.sh   # auto-installer via curl + find + sudo cp
/README.md    # this file
```

- `display_name`: `Português (Brasil)` (`metadata.code: pt_BR`)
- Placeholders preserved: `{install_name}`, `{speed}`, `{count}`, `{size}`, `{runner_version}`, etc.
- Technical terms kept: Runner, Prefix, MangoHUD, Gamemode, Gamescope, SteamLinuxRuntime, XXMI, DiscordRPC
- Validated: `python3 -m json.tool pt_BR.json` and key-parity check vs `en_US.json`

Tested: `pnpm build` + `cargo check` (900 crates, 11m27s) + `pnpm tauri dev` on Wayland/KDE — window shows `Configurações do Launcher` correctly.

---

## 🛠️ Development / Desenvolvimento

```bash
# Validate JSON
python3 -m json.tool pt_BR.json > /dev/null && echo "ok"
# Check key parity vs en_US (if you have original)
python3 -c "import json; en=json.load(open('en_US.json')); pt=json.load(open('pt_BR.json')); \
def flat(d,p=''): return {p+k:v if not isinstance(v,dict) else flat(v,p+k+'.') for k,v in d.items() for _ in [0]}\
# simpler: use script in repo to compare"
```

Contributions for fixes/improvements to pt_BR are welcome via PR.

---

## 📄 License

Same as [TwintailLauncher](https://github.com/TwintailTeam/TwintailLauncher/blob/stable/LICENSE) (check upstream). This translation is provided as community contribution, no affiliation.

---

## 🔗 Links

- Upstream: https://github.com/TwintailTeam/TwintailLauncher
- Issues for translation: https://github.com/zonaro/TwinTailLauncher-br-lang/issues
- Raw file: https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/pt_BR.json

**One-liner again:**
```bash
curl -fsSL https://raw.githubusercontent.com/zonaro/TwinTailLauncher-br-lang/main/install.sh | bash
```
