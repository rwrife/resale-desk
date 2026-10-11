import Testing
@testable import ResaleDeskKit

@Suite struct ListingTests {
    @Test func priceTextUsesExactCentsAndUnknown() throws {
        #expect(try ListingCopy.cents("12.34") == 1234)
        #expect(try ListingCopy.cents(" 0 ") == 0)
        #expect(try ListingCopy.cents("") == nil)
        #expect(try ListingCopy.cents("12,3") == 1230)
        #expect(ListingCopy.price(1234) == "12.34")
        #expect(ListingCopy.price(nil) == "")
        for invalid in ["-1", "1.234", "1e2", "nan", "1,000.00", "92233720368547758.08"] {
            #expect(throws: DomainError.self) { try ListingCopy.cents(invalid) }
        }
    }

    @Test func compositionUsesConditionRubricAndNotes() throws {
        let item = Item(id: "i", title: "Vintage Wool Sweater", photoPaths: ["photos/1.jpg"], category: "Apparel")
        let rubric = RubricTemplate(id: "r", questions: [
            RubricQuestion(id: "clean", title: "Clean fabric", required: true),
            RubricQuestion(id: "tear", title: "Tears or holes", required: true)
        ])
        let condition = ItemCondition(rubricID: "r", answers: [
            ConditionAnswer(questionID: "clean", value: .pass),
            ConditionAnswer(questionID: "tear", value: .fail, note: "Small repair on left cuff")
        ])
        let title = ListingCopy.composeTitle(item: item, template: "{title}")
        #expect(title == "Vintage Wool Sweater")

        let description = ListingCopy.composeDescription(item: item, condition: condition, rubric: rubric, template: "Title: {title}\nCategory: {category}\nCondition Grade: {grade}\n{checks}\nDefect Notes:\n{notes}")
        #expect(ListingCopy.composeTitle(item: item, template: "Owned: {title}") == "Owned: Vintage Wool Sweater")
        #expect(ListingCopy.composeDescription(item: item, condition: nil, rubric: nil, template: "{grade}") == "Unknown")
        #expect(ListingCopy.composeTitle(item: Item(id: "x", title: "{category}", category: "Private"), template: "{title}") == "{category}")
        #expect(description.contains("Title: Vintage Wool Sweater"))
        #expect(description.contains("Category: Apparel"))
        #expect(description.contains("Condition Grade: Good"))
        #expect(description.contains("- Tears or holes: Fail (Small repair on left cuff)"))
        #expect(description.contains("- Clean fabric: Pass"))
        #expect(description.contains("Defect Notes:"))
        #expect(description.contains("• Tears or holes: Small repair on left cuff"))

        let shareText = ListingCopy.shareExport(title: title, description: description, askingCents: 4500)
        #expect(shareText.contains("Vintage Wool Sweater"))
        #expect(shareText.contains("Asking price: 45.00 (your currency)"))
        #expect(shareText.contains(description))
        #expect(!shareText.contains("35.00"))
    }
}
