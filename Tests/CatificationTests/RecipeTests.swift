import XCTest
@testable import Catification

@MainActor
final class RecipeTests: XCTestCase {
    // MARK: Format

    func testHandWrittenRecipeDecodes() throws {
        let json = #"""
        { "name": "After dinner", "when": { "event": "ate" }, "chance": 0.7, "cooldown": 3600,
          "do": [ { "goTo": "trash" }, { "rummage": true }, { "goTo": "laundry" }, { "sleep": 120 }, { "drink": true }, { "emote": "heart" } ] }
        """#
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        XCTAssertEqual(recipe.trigger, .event(.ate))
        XCTAssertEqual(recipe.steps, [.goTo(.trash), .rummage, .goTo(.laundry), .sleep(seconds: 120), .drink, .emote(.heart)])
        XCTAssertEqual(recipe.chance, 0.7)
        XCTAssertTrue(recipe.isRunnable)
    }

    func testTemplatesRoundTrip() throws {
        for template in RecipeTemplate.allCases {
            let recipe = template.make()
            let decoded = try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe))
            XCTAssertEqual(decoded, recipe, "\(template)")
        }
    }

    /// A recipe from a newer version keeps its unknown parts when saved again, but never runs.
    func testUnknownPartsAreKeptButDontRun() throws {
        let json = #"{ "name": "Future", "when": { "moon": "full" }, "do": [ { "sit": 3 }, { "knit": { "rows": 2 } } ] }"#
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        XCTAssertFalse(recipe.isRunnable)
        let again = try JSONSerialization.jsonObject(with: JSONEncoder().encode(recipe)) as? [String: Any]
        XCTAssertEqual((again?["when"] as? [String: String])?["moon"], "full")
        let steps = again?["do"] as? [[String: Any]]
        XCTAssertEqual((steps?.last?["knit"] as? [String: Int])?["rows"], 2)
    }

    func testBadRecipesDontBreakTheBrain() throws {
        let json = #"{ "habits": { "rummage": 2 }, "recipes": "not a list" }"#
        let brain = try JSONDecoder().decode(CatBrain.self, from: Data(json.utf8))
        XCTAssertEqual(brain.habit(.rummage), 2)
        XCTAssertTrue(brain.recipes.isEmpty)
    }

    // MARK: Behaviour

    private func cat(_ name: String, recipes: [Recipe]) -> CatConfig {
        var cat = CatConfig(name: name, coat: .ginger, personality: .playful)
        var brain = CatBrain.preset(.playful)
        brain.recipes = recipes
        cat.brain = brain
        return cat
    }

    private func at(hour: Int) -> Date {
        DateComponents(calendar: .current, year: 2026, month: 1, day: 13, hour: hour).date!
    }

    func testEveningZoomiesHappenInTheEveningOnly() {
        func count(startingAt hour: Int) -> Int {
            let world = World(seed: 3, start: at(hour: hour))
            world.spawn(character: cat("Ginger", recipes: [RecipeTemplate.eveningZoomies.make()]))
            world.run(for: 3600)
            return world.report.day(of: "Ginger")?.recipes[RecipeTemplate.eveningZoomies.title] ?? 0
        }
        XCTAssertGreaterThan(count(startingAt: 19), 0)
        XCTAssertEqual(count(startingAt: 9), 0)
    }

    func testPettingStartsARecipeThatRunsStepByStep() throws {
        // After petting: to the bed, then a nap.
        let recipe = Recipe(name: "Cuddle nap", trigger: .event(.petted), steps: [.goTo(.bed), .sleep(seconds: 60)])
        let world = World(seed: 5)
        let ginger = try XCTUnwrap(world.spawn(character: cat("Ginger", recipes: [recipe])))
        // Pet it once it's around and awake, like a person would.
        while !ginger.isIdle { world.run(for: 0.5) }
        world.emit(.petted, to: ginger)
        world.run(for: 90)
        let day = try XCTUnwrap(world.report.day(of: "Ginger"))
        XCTAssertEqual(day.recipes["Cuddle nap"], 1)
        XCTAssertGreaterThan(day.seconds["sleep"] ?? 0, 30)
    }
}
