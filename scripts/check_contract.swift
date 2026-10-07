import Foundation

// Static metadata checks only. The Apple job separately measures the built app.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let pin = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("toolchain.json"))) as! [String: Any]
func require(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("Contract failure: \(message)\n", stderr)
        exit(1)
    }
}
require(pin["xcode_version"] as? String == "26.0.1", "Xcode version")
require(pin["xcode_build"] as? String == "17A400", "Xcode build")
require(pin["iphoneos_sdk"] as? String == "26.0", "iOS SDK")
require(pin["minimum_sdk_major"] as? Int == 26, "SDK floor")
require(pin["deployment_target"] as? String == "26.0", "deployment floor")
require(pin["swift_language_mode"] as? String == "6", "Swift mode")
require(pin["bundle_identifier"] as? String == "com.infinityball.resaledesk", "bundle identity")
require(pin["targeted_device_family"] as? String == "1", "device family")
require(pin["native_ipad_support"] as? Bool == false, "iPad support")
require((pin["network_allowlist"] as? [String]) == [], "network allowlist")
let project = try String(contentsOf: root.appendingPathComponent("ResaleDesk.xcodeproj/project.pbxproj"), encoding: .utf8)
func values(_ key: String) throws -> [String] {
    let expression = try NSRegularExpression(pattern: "\\b\(key)\\s*=\\s*([^;]+);")
    return expression.matches(in: project, range: NSRange(project.startIndex..., in: project)).map {
        String(project[Range($0.range(at: 1), in: project)!]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
let configurations = try values("isa").filter { $0 == "XCBuildConfiguration" }.count
require(configurations == 4, "expected Debug/Release project and app configurations; update gate when targets change")
for (key, expected, count) in [
    ("TARGETED_DEVICE_FAMILY", "1", configurations),
    ("IPHONEOS_DEPLOYMENT_TARGET", "26.0", configurations),
    ("SWIFT_VERSION", "6.0", configurations),
    ("PRODUCT_BUNDLE_IDENTIFIER", "com.infinityball.resaledesk", 2)
] {
    let actual = try values(key)
    require(actual.count == count && actual.allSatisfy { $0 == expected }, "\(key) across all configurations")
}
print("Static contract checks: PASS (exact pin, four configurations, identity, offline policy)")
