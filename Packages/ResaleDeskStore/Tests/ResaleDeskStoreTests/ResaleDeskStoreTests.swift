import Testing
@testable import ResaleDeskStore

@Suite("ResaleDeskStore skeleton tests")
struct ResaleDeskStoreTests {
    @Test("domain namespace is reachable")
    func domainNamespace() {
        #expect(ResaleDeskStore.domain == "ResaleDeskStore")
    }

    @Test("milestone marker is M2-store")
    func milestoneMarker() {
        #expect(ResaleDeskStore.milestone == "M2-store")
    }
}
