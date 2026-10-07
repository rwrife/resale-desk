import Testing
@testable import ResaleDeskKit

@Suite("Skeleton placeholder")
struct PlaceholderTests {
    @Test("domain namespace is reachable")
    func domainNamespace() {
        #expect(ResaleDeskKit.domain == "ResaleDeskKit")
    }

    @Test("milestone marker is set for M1")
    func milestoneMarker() {
        #expect(ResaleDeskKit.milestone == "M1-skeleton")
    }
}
