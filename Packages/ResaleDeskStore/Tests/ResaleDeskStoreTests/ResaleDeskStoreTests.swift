import Testing
@testable import ResaleDeskStore

@Suite("ResaleDeskStore skeleton tests")
struct ResaleDeskStoreTests {
    @Test("domain namespace is reachable")
    func domainNamespace() {
        #expect(ResaleDeskStore.domain == "ResaleDeskStore")
    }

    @Test("milestone marker is M1-skeleton")
    func milestoneMarker() {
        #expect(ResaleDeskStore.milestone == "M1-skeleton")
    }
}
