# Bootstrap Evidence (M1)

Evidence for M1 bootstrap (issue #1).

## Host-side verification

Environment: Linux (podman container `swift:6.2-noble`, x86_64).

1. **`ResaleDeskKit` unit tests**: 2/2 tests passed in pure Swift container (`swift:6.2-noble`).
2. **`ResaleDeskStore` unit tests**: 2/2 tests passed in pure Swift container (`swift:6.2-noble`).
3. **Zero-network gate (`scripts/check_zero_network.sh`)**: PASS (empty allowlist, no prohibited network symbols across app or package sources).
4. **Native-only framework gate (`scripts/check_native_only.sh`)**: PASS (no Flutter/React Native/Expo/Kotlin Multiplatform/.NET MAUI/Unity).
5. **Static contract checks (`scripts/check_contract.swift`)**: PASS (pinned Xcode 26.0.1 / 17A400 / iOS SDK 26.0, `TARGETED_DEVICE_FAMILY = 1` across all 4 configurations, bundle id `com.infinityball.resaledesk`).
6. **Negative gate tests (`scripts/test_gates.sh`)**: PASS (17 negative fixtures verifying multiline rejection of Foundation contentsOf, remote URL strings, Alamofire/remote packages, Xcode remote packages, network entitlements, Flutter, React Native, Expo, KMP gradle/gradle.kts, MAUI csproj UseMaui, and Unity).

## CI-pending Apple evidence

The following are measured exclusively on Apple CI (`macos-26` runner with exact Xcode 26.0.1 / 17A400 pin):

1. Exact toolchain selection (`Xcode 26.0.1 (17A400)`).
2. iOS SDK 26.0+ verification.
3. Package unit tests on the macOS toolchain.
4. App build for `iphonesimulator` (`generic/platform=iOS Simulator`).
5. Built app post-build plist measurement (`UIDeviceFamily == [1]`, bundle identifier `com.infinityball.resaledesk`).
6. Embedded `PrivacyInfo.xcprivacy` presence.
