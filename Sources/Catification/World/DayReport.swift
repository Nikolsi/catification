import Foundation

/// What each cat did: actions it chose, time spent per activity, where it napped and notable
/// moments (jumps, misses, portals). Filled in by a world when one is attached (`CatWorld.report`).
@MainActor
final class DayReport {
    struct CatDay: Codable, Equatable {
        var name: String
        /// How often each action was started, by the planner or a reaction.
        var actions: [String: Int] = [:]
        /// Seconds spent in each activity (sit, walk, sleep…).
        var seconds: [String: Double] = [:]
        /// Where it chose to nap; "here" when it just lay down where it was.
        var naps: [String: Int] = [:]
        /// Jumps, calculations, hangs, falls, portals.
        var moments: [String: Int] = [:]
        /// Recipes started, by name.
        var recipes: [String: Int] = [:]

        func count(_ action: CatAction) -> Int { actions[action.rawValue] ?? 0 }
    }

    private(set) var cats: [CatDay] = []
    private var index: [UUID: Int] = [:]
    private(set) var seconds: Double = 0

    func day(of name: String) -> CatDay? { cats.first { $0.name == name } }

    func tick(_ cats: [Cat], dt: Double) {
        seconds += dt
        for cat in cats { update(cat) { $0.seconds["\(cat.activity)", default: 0] += dt } }
    }

    func decided(_ action: CatAction, cat: Cat) { update(cat) { $0.actions[action.rawValue, default: 0] += 1 } }
    func napped(at place: CatPlace?, cat: Cat) { update(cat) { $0.naps[place?.rawValue ?? "here", default: 0] += 1 } }
    func moment(_ name: String, cat: Cat) { update(cat) { $0.moments[name, default: 0] += 1 } }
    func recipe(_ name: String, cat: Cat) { update(cat) { $0.recipes[name, default: 0] += 1 } }

    private func update(_ cat: Cat, _ change: (inout CatDay) -> Void) {
        let i = index[cat.id] ?? {
            cats.append(CatDay(name: cat.config.name))
            index[cat.id] = cats.count - 1
            return cats.count - 1
        }()
        change(&cats[i])
    }

    /// A readable summary, one block per cat.
    var text: String {
        func list(_ d: [String: Int]) -> String {
            d.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        }
        var out = String(format: "%.1f simulated hours\n", seconds / 3600)
        for cat in cats {
            let total = max(1, cat.seconds.values.reduce(0, +))
            let time = cat.seconds.sorted { $0.value > $1.value }.prefix(6)
                .map { "\($0.key) \(Int(($0.value / total * 100).rounded()))%" }.joined(separator: ", ")
            out += "\n\(cat.name)\n"
            out += "  actions: \(list(cat.actions))\n"
            out += "  time:    \(time)\n"
            if !cat.naps.isEmpty { out += "  naps:    \(list(cat.naps))\n" }
            if !cat.moments.isEmpty { out += "  moments: \(list(cat.moments))\n" }
            if !cat.recipes.isEmpty { out += "  rituals: \(list(cat.recipes))\n" }
        }
        return out
    }
}
