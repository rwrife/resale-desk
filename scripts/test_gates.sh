#!/usr/bin/env bash
# Exercise the real gates against isolated negative fixtures, not regex replicas.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/scripts" "$scratch/ResaleDesk" "$scratch/Packages/Probe" "$scratch/ResaleDesk.xcodeproj"
cp scripts/check_zero_network.sh scripts/check_native_only.sh "$scratch/scripts/"
for gate in check_zero_network check_native_only; do
  bash "$scratch/scripts/$gate.sh"
done
reject() {
  local gate="$1" file="$2" fixture="$3"
  mkdir -p "$(dirname "$scratch/$file")"
  printf '%s\n' "$fixture" > "$scratch/$file"
  if bash "$scratch/scripts/$gate.sh" > "$scratch/output" 2>&1; then
    echo "FAIL: $gate accepted $file: $fixture"
    exit 1
  fi
  rm "$scratch/$file"
}
reject check_zero_network ResaleDesk/Probe.swift 'let session = URLSession.shared'
reject check_zero_network ResaleDesk/Probe.swift $'let bytes = try Data(\n  contentsOf: remoteURL\n)'
reject check_zero_network ResaleDesk/Probe.swift $'let text = try String(\n  contentsOf: remoteURL\n)'
reject check_zero_network ResaleDesk/Probe.swift $'let url = URL(\n  string: "https://example.com"\n)'
reject check_zero_network Packages/Probe/Package.swift $'.package(\n  url: "https://github.com/Alamofire/Alamofire",\n  from: "5.0.0"\n)'
reject check_zero_network ResaleDesk/Probe.swift 'let browser: WKWebView'
reject check_zero_network Packages/ResaleDeskStore/Package.swift '.package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0")'
reject check_zero_network Packages/ResaleDeskStore/Package.swift '        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.0"),'
printf '%s\n' '        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),' > "$scratch/Packages/ResaleDeskStore/Package.swift"
bash "$scratch/scripts/check_zero_network.sh"
rm "$scratch/Packages/ResaleDeskStore/Package.swift"
reject check_zero_network ResaleDesk.xcodeproj/project.pbxproj 'isa = XCRemoteSwiftPackageReference;'
reject check_zero_network ResaleDesk/Probe.entitlements '<key>com.apple.developer.icloud-services</key>'
reject check_zero_network ResaleDesk/Probe.plist '<key>NSAppTransportSecurity</key>'
reject check_native_only pubspec.yaml 'name: probe'
reject check_native_only package.json '{"dependencies":{"react-native":"1"}}'
reject check_native_only package.json '{"dependencies":{"expo":"1"}}'
reject check_native_only build.gradle "plugins { id 'org.jetbrains.kotlin.multiplatform' }"
reject check_native_only build.gradle.kts 'plugins { kotlin("multiplatform") }'
reject check_native_only Probe.csproj '<UseMaui>true</UseMaui>'
reject check_native_only ProjectVersion.txt 'm_EditorVersion: 6'
echo "Gate regression checks: PASS (18 negative fixtures, 1 audited dependency pin)"
