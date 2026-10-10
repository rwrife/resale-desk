import Testing
@testable import ResaleDeskKit

@Suite("Skeleton placeholder")
struct PlaceholderTests {
    @Test("domain namespace is reachable")
    func domainNamespace() {
        #expect(ResaleDeskKit.domain == "ResaleDeskKit")
    }

    @Test("milestone marker is M3 inventory")
    func milestoneMarker() {
        #expect(ResaleDeskKit.milestone == "M3-inventory")
    }

    @Test("default category rubrics validate and grade")
    func defaultRubrics() throws {
        #expect(ResaleDeskKit.defaultRubrics.count == 4)
        for rubric in ResaleDeskKit.defaultRubrics {
            try rubric.validate()
            let passing = rubric.questions.map { ConditionAnswer(questionID: $0.id, value: .pass) }
            #expect(try rubric.grade(passing) == .excellent)
        }
    }
}
