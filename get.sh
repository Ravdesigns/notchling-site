#!/bin/bash
# Notchling installer.  curl -fsSL https://notchling.zopcloud.zop.dev/get.sh | bash
# curl does not quarantine what it fetches, so this skips the Gatekeeper warning.
set -euo pipefail
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# Count this install. The one-liner never loads the page, so this is the only way
# it shows up in the tally. Capped at two seconds and allowed to fail: it cannot
# hang the install and cannot break it. (A backgrounded subshell was tried first
# and never fired — the parent exits before it connects.)
curl -fsS -m 2 -X POST "https://notchling.vercel.app/api/hit?e=install" </dev/null >/dev/null 2>&1 || true

echo "▸ downloading Notchling…"
curl -fsSL "https://notchling.zopcloud.zop.dev/Notchling.zip" -o "$TMP/Notchling.zip"
echo "  sha256 $(shasum -a 256 "$TMP/Notchling.zip" | cut -d' ' -f1)"
unzip -q "$TMP/Notchling.zip" -d "$TMP"
[ -d "$TMP/Notchling/Notchling.app" ] || { echo "✗ that archive didn't contain Notchling.app"; exit 1; }

# /Applications is not writable for every account, so fall back rather than fail
DEST=/Applications
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

# stage the copy first, then swap it in: if anything goes wrong you still have the
# app you started with, and ditto (not cp) is what preserves a bundle intact
STAGE="$DEST/.Notchling.app.incoming"
rm -rf "$STAGE"
ditto "$TMP/Notchling/Notchling.app" "$STAGE"
pkill -x Notchling 2>/dev/null || true
rm -rf "$DEST/Notchling.app"
mv "$STAGE" "$DEST/Notchling.app"

# LaunchServices can still be holding the bundle we just replaced, which makes an
# immediate `open` fail with -600. Give it a beat, re-register, then fall back to
# launching the binary directly so an upgrade never ends with nothing running.
sleep 1
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
if ! open "$DEST/Notchling.app" 2>/dev/null; then
  [ -x "$LSREG" ] && "$LSREG" -f "$DEST/Notchling.app" >/dev/null 2>&1 || true
  sleep 1
  open "$DEST/Notchling.app" 2>/dev/null || "$DEST/Notchling.app/Contents/MacOS/Notchling" >/dev/null 2>&1 &
fi
echo "Done 🐣  Installed to $DEST. Look at your notch, and drag a file toward it."
