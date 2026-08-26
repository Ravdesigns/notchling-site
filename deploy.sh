#!/bin/bash
# Deploy the standalone Notchling site.
#
# It lives on its OWN Vercel project and its OWN hostname (notchling.vercel.app)
# because Product Hunt will not accept a second launch that shares a domain with
# an existing one — crew-deskmates.vercel.app already belongs to Crew's listing.
#
# Nothing here reaches into the Deskmates store: assets, the zip and get.sh are
# all local, so this folder is the whole site.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

# The published size and sha must always describe the zip actually being shipped,
# so they are injected from the file rather than typed by hand.
ZIP="$SRC/Notchling.zip"
if [ -f "$ZIP" ]; then
  SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
  KB=$(( $(stat -f%z "$ZIP") / 1024 ))
  python3 - "$SHA" "$KB" "$SRC/index.html" <<'PYEOF'
import re, sys, pathlib
sha, kb, path = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])
s = path.read_text()
s = re.sub(r'(id="zipsha"[^>]*>)sha256 [^<]*', lambda m: m.group(1) + "sha256 " + sha, s)
s = re.sub(r'(id="dlsize"[^>]*>)\d+ KB', lambda m: m.group(1) + kb + " KB", s)
s = re.sub(r'(id="herosize"[^>]*>)\d+ KB', lambda m: m.group(1) + kb + " KB", s)
path.write_text(s)
PYEOF
  unzip -p "$ZIP" Notchling/Notchling.app/Contents/Info.plist \
    | plutil -extract CFBundleShortVersionString raw -o - - 2>/dev/null > "$SRC/version.txt" || true
fi

cd "$SRC"
vercel --prod --yes --scope team-11199 >/dev/null 2>&1

B=https://notchling.vercel.app
for u in / /get.sh /Notchling.zip /version.txt /share.png; do
  printf "  %s  %s\n" "$(curl -s -o /dev/null -w '%{http_code}' "$B$u")" "$u"
done
echo "✓ live at $B"
