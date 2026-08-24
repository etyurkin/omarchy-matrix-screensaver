#!/bin/bash
#
# Install the omarchy-matrix screensaver on an Omarchy system.
#
# Everything lands in user-owned locations; nothing under /usr/share/omarchy is
# touched, so an `omarchy update` will not clobber it.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BRANDING_DIR="$HOME/.config/omarchy/branding"
HOOK_DIR="$HOME/.config/omarchy/hooks/post-update.d"
PLUGIN_DIR="$HOME/.config/omarchy/plugins"
STOCK_IDLE="/usr/share/omarchy/shell/plugins/services/idle"

say() { printf '  %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v omarchy >/dev/null || die "this is not an Omarchy system"
command -v python3 >/dev/null || die "python3 is missing"
# ttfx ships in Omarchy's base packages; the launcher and effect picker require
# it, so treat its absence as the broken install it indicates.
command -v ttfx >/dev/null || die "ttfx is missing -- omarchy pkg add ttfx"

stamp=$(date +%s)

echo "Installing commands..."
mkdir -p "$BIN_DIR"
for f in "$REPO_DIR"/bin/*; do
  name=$(basename "$f")
  [[ -e $BIN_DIR/$name ]] && cp -a "$BIN_DIR/$name" "$BIN_DIR/$name.bak.$stamp"
  install -m 755 "$f" "$BIN_DIR/$name"
  say "$name"
done

echo "Installing the corrected wordmark..."
mkdir -p "$BRANDING_DIR"
if [[ -e $BRANDING_DIR/screensaver.txt ]]; then
  cp -a "$BRANDING_DIR/screensaver.txt" "$BRANDING_DIR/screensaver.txt.bak.$stamp"
  say "backed up your existing screensaver.txt"
fi
install -m 644 "$REPO_DIR/branding/screensaver.txt" "$BRANDING_DIR/screensaver.txt"

echo "Redirecting the idle service..."
# Omarchy hardcodes the screensaver launcher in the idle plugin, does not expose
# it in shell.json, and /usr/share/omarchy/bin outranks ~/.local/bin on PATH --
# so cloning the plugin is the only supported way to point it somewhere else.
clone=""
for candidate in "$PLUGIN_DIR"/*.idle; do
  [[ -f $candidate/manifest.json ]] || continue
  grep -q '"clonedFrom": *"omarchy.idle"' "$candidate/manifest.json" && clone="$candidate" && break
done
if [[ -z $clone ]]; then
  omarchy plugin clone omarchy.idle >/dev/null
  for candidate in "$PLUGIN_DIR"/*.idle; do
    [[ -f $candidate/manifest.json ]] || continue
    grep -q '"clonedFrom": *"omarchy.idle"' "$candidate/manifest.json" && clone="$candidate" && break
  done
fi
[[ -n $clone ]] || die "could not clone omarchy.idle"

if [[ -d $STOCK_IDLE ]]; then
  sed 's/\bomarchy-launch-screensaver\b/omarchy-launch-custom-screensaver/g' \
    "$STOCK_IDLE/Service.qml" >"$clone/Service.qml"
  grep -q omarchy-launch-custom-screensaver "$clone/Service.qml" ||
    die "upstream idle service changed shape; apply the launcher swap by hand"
fi
say "$(basename "$clone")"

echo "Installing the post-update hook..."
mkdir -p "$HOOK_DIR"
install -m 755 "$REPO_DIR/hooks/post-update.d/resync-idle-clone.hook" "$HOOK_DIR/"
say "resync-idle-clone.hook"

echo "Selecting the effect..."
omarchy-screensaver-set omarchy-matrix >/dev/null
say "omarchy-matrix"

cat <<'DONE'

Done. It runs at your screensaver idle timeout (idle.screensaver in
~/.config/omarchy/shell.json). To see it now:

    omarchy-launch-custom-screensaver force

To go back:  omarchy-screensaver-set random
DONE
