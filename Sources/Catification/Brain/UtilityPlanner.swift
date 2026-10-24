import Foundation

/// What the planner needs to know about a cat and its surroundings. Pure data, so the planner
/// can be tested without a world.
struct PlannerContext {
    var energy: Double
    var social = 0.5
    var curiosity = 0.5
    var grumpy = false
    /// 0…1; only matters when there's a fountain.
    var thirst = 0.0
    var hour = Calendar.current.component(.hour, from: Date())
    /// Actions that make sense right now (there is a post, a playmate, a ball…).
    var available: Set<CatAction>
}

/// Scores every available action from the cat's brain and state. The cat then picks one at
/// random in proportion to its score, so likely things happen often but not always.
enum UtilityPlanner {
    /// The appeal of each action before habits, needs and routines.
    static let baseWeights: [CatAction: Double] = [
        .idle: 1.0, .sit: 1.5, .groom: 0.7, .wander: 1.6, .explore: 1.3, .zoomies: 0.45, .nap: 2.2,
        .scratch: 0.6, .rummage: 0.5, .play: 1.4, .chaseBall: 0.8, .visitCursor: 1.6, .drink: 1.2,
    ]

    /// Which need each action satisfies; used to sway choices by how lonely or bored a cat is.
    private static let curiousActions: Set<CatAction> = [.wander, .explore, .rummage, .scratch]
    private static let socialActions: Set<CatAction> = [.play, .visitCursor]

    static func scores(brain: CatBrain, context c: PlannerContext) -> [(action: CatAction, score: Double)] {
        CatAction.allCases.compactMap { action in
            guard c.available.contains(action), let base = baseWeights[action] else { return nil }
            var score = base * brain.habit(action) * stateFactor(action, c)

            // Lonely or bored cats lean towards what fixes it; 0.5 is neutral.
            let k = brain.needs.influence
            if curiousActions.contains(action) { score *= max(0, 1 + k * (c.curiosity - 0.5) * 2) }
            if socialActions.contains(action) { score *= max(0, 1 + k * (c.social - 0.5) * 2) }

            for routine in brain.routines where routine.action == action && routine.isActive(hour: c.hour) {
                score *= max(0, routine.boost)
            }
            return score > 0 ? (action, score) : nil
        }
    }

    /// The parts of the old hard-coded weights that depend on how the cat feels right now.
    private static func stateFactor(_ action: CatAction, _ c: PlannerContext) -> Double {
        switch action {
        case .zoomies: c.energy * (c.grumpy ? 0.3 : 1)
        case .nap: 1.1 - c.energy
        case .play, .chaseBall: c.energy
        case .drink: c.thirst * 2
        default: 1
        }
    }

    /// Weighted random pick, the way `decide()` uses it. `random` is injectable for tests.
    static func pick(from scores: [(action: CatAction, score: Double)], random: Double = .random(in: 0..<1)) -> CatAction? {
        pick(scores.map { ($0.action, $0.score) }, random: random)
    }

    /// Weighted random pick among anything: actions, recipes.
    static func pick<Choice>(_ options: [(Choice, Double)], random: Double) -> Choice? {
        let total = options.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var r = random * total
        for (choice, score) in options {
            r -= score
            if r < 0 { return choice }
        }
        return options.last?.0
    }
}
