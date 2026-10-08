import Testing
@testable import ResaleDeskKit

@Suite("Skeleton placeholder")
struct PlaceholderTests {
    @Test("domain namespace is reachable")
    func domainNamespace() {
        #expect(ResaleDeskKit.domain == "ResaleDeskKit")
    }

    @Test("milestone marker is M2 domain")
    func milestoneMarker() {
        #expect(ResaleDeskKit.milestone == "M2-domain")
    }
}
