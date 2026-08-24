#!/bin/bash
#
# Undo install.sh: put the stock idle service back and stop using the effect.
# The commands in ~/.local/bin are left alone -- delete them yourself if wanted.

set -euo pipefail

PLUGIN_DIR="$HOME/.config/omarchy/plugins"
HOOK="$HOME/.config/omarchy/hooks/post-update.d/resync-idle-clone.hook"

echo "Clearing the effect selection..."
# The stock idle service never reads this file, and the custom screensaver
# falls back to the random rotation when it is missing -- so removing it is the
# one operation that is honest in every configuration.
rm -f "$HOME/.local/state/omarchy/current/screensaver.name"

echo "Restoring the stock idle service..."
for candidate in "$PLUGIN_DIR"/*.idle; do
  [[ -f $candidate/manifest.json ]] || continue
  grep -q '"clonedFrom": *"omarchy.idle"' "$candidate/manifest.json" || continue
  # Re-enabling the packaged plugin is what actually restores stock behaviour;
  # the clone is then just an unused directory.
  omarchy plugin enable omarchy.idle >/dev/null 2>&1 || true
  omarchy plugin disable "$(basename "$candidate")" >/dev/null 2>&1 || true
  echo "  disabled $(basename "$candidate"), re-enabled omarchy.idle"
done

echo "Removing the post-update hook..."
rm -f "$HOOK" && echo "  done"

cat <<'DONE'

Stock screensaver restored.

Left in place on purpose:
  ~/.local/bin/omarchy-*                      (delete if you want them gone)
  ~/.config/omarchy/branding/screensaver.txt  (a .bak.<stamp> sits beside it)
  ~/.config/omarchy/plugins/<user>.idle       (now disabled)
DONE
