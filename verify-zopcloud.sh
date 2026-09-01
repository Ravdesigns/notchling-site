#!/bin/bash
# Run this the moment the ZopCloud rebuild reports Active. It checks the things
# that actually break a launch, not just that the page loads.
H=https://notchling.zopcloud.zop.dev
V=https://notchling.vercel.app
pass=0; fail=0
ok(){ printf "  \033[32m✓\033[0m %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  \033[31m✗\033[0m %s\n" "$1"; fail=$((fail+1)); }

echo "▸ pages and assets"
for p in / /assets/site.css /assets/site.js /get.sh /version.txt /share.png /stats.html /robots.txt /Notchling.zip; do
  c=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$H$p")
  [ "$c" = "200" ] && ok "$p" || no "$p returned $c"
done
c=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$H/healthz"); [ "$c" = "200" ] && ok "/healthz" || no "/healthz returned $c"
c=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$H/definitely-not-here"); [ "$c" = "404" ] && ok "404 for a bad path" || no "bad path returned $c"

echo "▸ the new build actually shipped"
PAGE=$(curl -s -m 25 "$H/")
grep -q 'id="pricing"' <<<"$PAGE" && ok "pricing section present" || no "NO pricing section: still the old commit"
grep -q 'id="m-pro"'   <<<"$PAGE" && ok "Pro pane present"        || no "no Pro pane"
grep -q 'class="tag">Pro<' <<<"$PAGE" && ok "Pro tag in the feature grid" || no "no Pro tag"
[ "$(curl -s -m 20 "$H/version.txt" | tr -d '[:space:]')" = "1.10.0" ] && ok "version.txt 1.10.0" || no "version.txt is $(curl -s -m 20 "$H/version.txt" | tr -d '[:space:]')"

echo "▸ the trust artefact"
SHOWN=$(grep -o 'sha256 [a-f0-9]\{64\}' <<<"$PAGE" | head -1 | cut -d' ' -f2)
REAL=$(curl -s -m 60 "$H/Notchling.zip" | shasum -a 256 | cut -d' ' -f1)
[ -n "$SHOWN" ] && [ "$SHOWN" = "$REAL" ] && ok "page sha matches its own zip" || no "sha MISMATCH page=${SHOWN:0:12} zip=${REAL:0:12}"
grep -q "$H/Notchling.zip" <<<"$(curl -s -m 20 "$H/get.sh")" && ok "get.sh pulls from this host" || no "get.sh pulls from elsewhere"
grep -q "$H/get.sh" <<<"$PAGE" && ok "curl line names this host" || no "curl line names another host"

echo "▸ the app inside the zip"
T=$(mktemp -d); curl -fsSL -m 60 "$H/Notchling.zip" -o "$T/n.zip" 2>/dev/null
if unzip -q "$T/n.zip" -d "$T" 2>/dev/null; then
  APP="$T/Notchling/Notchling.app"
  VER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null)
  [ "$VER" = "1.10.0" ] && ok "bundle is v1.10.0" || no "bundle is v$VER"
  A=$(lipo -archs "$APP/Contents/MacOS/Notchling" 2>/dev/null)
  [[ "$A" == *x86_64* && "$A" == *arm64* ]] && ok "universal ($A)" || no "not universal: $A"
  strings "$APP/Contents/MacOS/Notchling" 2>/dev/null | grep -q "notchling.licence" && ok "licensing is in the binary" || no "NO licensing in the binary: old build"
else no "zip did not unpack"; fi
rm -rf "$T"

echo "▸ analytics reachable from this host"
grep -q 'notchling.vercel.app/api/hit' <<<"$(curl -s -m 20 "$H/stats.html")" && ok "dashboard calls the counter absolutely" || no "dashboard uses a relative /api path: it will read as unreachable here"
grep -q "$V/api/hit" <<<"$PAGE" && ok "page beacon is absolute" || no "page beacon is relative"

echo
printf "  %d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ] && echo "  Ready to submit." || echo "  Do not submit until these are green."
exit $fail
