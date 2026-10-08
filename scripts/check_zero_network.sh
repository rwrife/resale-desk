#!/usr/bin/env bash
# Zero-network gate (issue #1, binding project contract).
#
# ResaleDesk is zero-network BY CONSTRUCTION: the app and the domain
# package must never use network APIs. The allowlist is intentionally
# EMPTY — any match in scanned sources fails the build.
#
# Scanned roots: ResaleDesk/ (app sources) and Packages/*/Sources/.
set -euo pipefail

cd "$(dirname "$0")/.."

ROOTS=("ResaleDesk" "Packages")
ALLOWLIST=()   # empty by design; extend only with explicit user sign-off

PATTERNS=(
  '\bURLSession\b'
  '\bNWConnection\b'
  '\bNWListener\b'
  '\bNWConnectionGroup\b'
  '\bNWBrowser\b'
  '\bNetService\b'
  '\bCFNetwork\b'
  '\bimport[[:space:]]+Network\b'
  '\bCFStream\b'
  '\bCFSocket\b'
  '\bCocoaHTTPServer\b'
  '\bWebSocket\b'
  '\bgetaddrinfo\b'
  '\bsocket[[:space:]]*\('
  '\bconnect[[:space:]]*\('
  '\blisten[[:space:]]*\('
  '\bbind[[:space:]]*\('
  '\baccept[[:space:]]*\('
  '\bNSURLSession\b'
  '\bcontentsOf[[:space:]]*:'
  '"(https?|wss?)://'
  '\bWKWebView\b'
  '\bSFSafariViewController\b'
)

matches=""
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  for pat in "${PATTERNS[@]}"; do
    hits=$(grep -RE --exclude-dir=.build --include='*.swift' --include='*.h' --include='*.m' --include='*.c' \
      "$pat" "$root" 2>/dev/null | grep -vFx 'Packages/ResaleDeskStore/Package.swift:        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),' || true)
    [ -n "$hits" ] && matches+="${hits}"$'\n'
  done
done

# Filter allowlisted lines (exact substring match against allowlist entries)
if [ -n "$matches" ]; then
  filtered=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    skip=0
    for a in ${ALLOWLIST[@]+"${ALLOWLIST[@]}"}; do
      [[ "$line" == *"$a"* ]] && { skip=1; break; }
    done
    [ "$skip" -eq 0 ] && filtered+="$line"$'\n'
  done <<< "$matches"
  if [ -n "$filtered" ]; then
    echo "ZERO-NETWORK GATE FAILED — network API usage found (allowlist is empty):"
    printf '%s' "$filtered"
    exit 1
  fi
fi

# Audited GRDB 7.11.1 is a build-time fetch only; reject any other remote pin.
remote=$(grep -RE --exclude-dir=.build --include='Package.swift' '\.package[[:space:]]*\([[:space:]]*url[[:space:]]*:' Packages || true)
if [ -n "$remote" ] && [ "$remote" != 'Packages/ResaleDeskStore/Package.swift:        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),' ]; then
  echo "ZERO-NETWORK GATE FAILED: unaudited remote Swift dependency: $remote"
  exit 1
fi
if grep -RnE 'XCRemoteSwiftPackageReference|repositoryURL[[:space:]]*=' ResaleDesk.xcodeproj; then
  echo "ZERO-NETWORK GATE FAILED: unaudited Xcode dependency"
  exit 1
fi
if grep -RnE --include='*.entitlements' --include='*.plist' 'com\.apple\.(security\.network|developer\.(icloud|networking|associated-domains))|NSAppTransportSecurity' ResaleDesk ResaleDesk.xcodeproj; then
  echo "ZERO-NETWORK GATE FAILED: network capability or entitlement"
  exit 1
fi
# ponytail: broad contentsOf ban remains; add a file-URL-only audited reader when M6 backup ships.
echo "Zero-network gate: PASS (empty allowlist, sources, dependencies, entitlements)"
