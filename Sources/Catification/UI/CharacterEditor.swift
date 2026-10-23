import SwiftUI

/// The "character" part of the cat editor: the owner's description, habits, favourite spots,
/// daily routines and reactions. Editing anything turns the personality preset into a custom brain.
struct CharacterSections: View {
    @Binding var cat: CatConfig
    /// Habits just added at 1×, kept on screen until they're moved or removed.
    @State private var addedHabits: Set<String> = []
    @State private var addedPlaces: Set<CatPlace> = []

    /// Habits as people think of them; each slider moves one or more actions together.
    private static let habitGroups: [(title: String, actions: [CatAction])] = [
        (L("Explores"), [.wander, .explore]),
        (L("Plays"), [.play, .zoomies, .chaseBall]),
        (L("Naps"), [.nap]),
        (L("Digs in the trash"), [.rummage]),
        (L("Scratches the post"), [.scratch]),
        (L("Comes for cuddles"), [.visitCursor]),
        (L("Grooms"), [.groom]),
    ]

    private var brain: Binding<CatBrain> {
        Binding(get: { cat.effectiveBrain }, set: { cat.brain = $0 })
    }

    var body: some View {
        Section {
            TextEditor(text: $cat.about)
                .font(.body)
                .frame(minHeight: 70)
            Text("Their story, quirks and what they love. Describe a real cat — yours, or one you miss.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("About this cat")
        }

        Section {
            // Only what makes this cat different from an ordinary one; everything else is 1×.
            ForEach(shownHabitGroups, id: \.title) { group in
                HStack {
                    slider(group.title, value: habitBinding(group.actions), range: 0...3)
                    Button {
                        resetHabit(group)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Back to ordinary")
                }
            }
            if shownHabitGroups.isEmpty {
                Text("An ordinary cat. Add what makes this one special.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Menu {
                    ForEach(hiddenHabitGroups, id: \.title) { group in
                        Button(group.title) { addedHabits.insert(group.title) }
                    }
                } label: {
                    Label("Add a habit", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(hiddenHabitGroups.isEmpty)
                Spacer()
                Text("1× is an ordinary cat, 0 never, 3× all the time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("Habits")
                Spacer()
                if cat.brain != nil {
                    Button("Reset to personality") { cat.brain = nil }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
        }

        Section("Favourite nap spots") {
            ForEach(shownPlaces) { place in
                HStack {
                    slider(place.title, value: placeBinding(place), range: 0...3)
                    Button {
                        addedPlaces.remove(place)
                        brain.wrappedValue.places[place] = 0
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Not a favourite")
                }
            }
            if shownPlaces.isEmpty {
                Text("Naps wherever it happens to be.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Menu {
                    ForEach(hiddenPlaces) { place in
                        Button(place.title) {
                            addedPlaces.insert(place)
                            brain.wrappedValue.places[place] = 1
                        }
                    }
                } label: {
                    Label("Add a spot", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(hiddenPlaces.isEmpty)
                Spacer()
                Text("1× a usual spot, 3× a firm favourite.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            DisclosureGroup("Daily routine (\(brain.wrappedValue.routines.count))") {
                ForEach(brain.routines) { $routine in
                    RoutineRow(routine: $routine) {
                        brain.wrappedValue.routines.removeAll { $0.id == routine.id }
                    }
                }
                Button {
                    brain.wrappedValue.routines.append(Routine(fromHour: 13, toHour: 16, action: .nap, boost: 2))
                } label: {
                    Label("Add a routine", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            DisclosureGroup("Reactions (\(brain.wrappedValue.reactions.count))") {
                ForEach(brain.reactions) { $reaction in
                    ReactionRow(reaction: $reaction) {
                        brain.wrappedValue.reactions.removeAll { $0.id == reaction.id }
                    }
                }
                Button {
                    brain.wrappedValue.reactions.append(Reaction(event: .petted, response: .hearts, chance: 0.5))
                } label: {
                    Label("Add a reaction", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("Routines and reactions")
        }

        Section {
            Button("Export this cat…") { CatProfileFiles.export(cat) }
            Text("Saves a .catprofile file you can share, for example in GitHub Discussions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range)
                Text(String(format: "%.1f×", value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }

    private func isSpecial(_ group: (title: String, actions: [CatAction])) -> Bool {
        abs(cat.effectiveBrain.habit(group.actions[0]) - 1) > 0.05
    }

    private var shownHabitGroups: [(title: String, actions: [CatAction])] {
        Self.habitGroups.filter { isSpecial($0) || addedHabits.contains($0.title) }
    }

    private var hiddenHabitGroups: [(title: String, actions: [CatAction])] {
        Self.habitGroups.filter { !isSpecial($0) && !addedHabits.contains($0.title) }
    }

    private func resetHabit(_ group: (title: String, actions: [CatAction])) {
        addedHabits.remove(group.title)
        var b = brain.wrappedValue
        for action in group.actions { b.habits[action] = nil }
        brain.wrappedValue = b
    }

    private func habitBinding(_ actions: [CatAction]) -> Binding<Double> {
        Binding(
            get: { brain.wrappedValue.habit(actions[0]) },
            set: { value in
                var b = brain.wrappedValue
                for action in actions { b.habits[action] = (value * 10).rounded() / 10 }
                brain.wrappedValue = b
            }
        )
    }

    private var shownPlaces: [CatPlace] {
        CatPlace.allCases.filter { cat.effectiveBrain.place($0) > 0.05 || addedPlaces.contains($0) }
    }

    private var hiddenPlaces: [CatPlace] {
        CatPlace.allCases.filter { !shownPlaces.contains($0) }
    }

    private func placeBinding(_ place: CatPlace) -> Binding<Double> {
        Binding(
            get: { brain.wrappedValue.place(place) },
            set: { brain.wrappedValue.places[place] = ($0 * 10).rounded() / 10 }
        )
    }
}

private struct RoutineRow: View {
    @Binding var routine: Routine
    let remove: () -> Void

    var body: some View {
        HStack {
            Picker("", selection: $routine.fromHour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
            }
            .labelsHidden()
            .frame(width: 80)
            Text("–")
            Picker("", selection: $routine.toHour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
            }
            .labelsHidden()
            .frame(width: 80)
            Picker("", selection: $routine.action) {
                ForEach(CatAction.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            Picker("", selection: $routine.boost) {
                ForEach([0.0, 0.5, 2.0, 3.0], id: \.self) { Text(boostTitle($0)).tag($0) }
            }
            .labelsHidden()
            .frame(width: 110)
            if routine.action == .nap {
                Picker("", selection: $routine.place) {
                    Text("Anywhere").tag(CatPlace?.none)
                    ForEach(CatPlace.allCases) { Text($0.title).tag(CatPlace?.some($0)) }
                }
                .labelsHidden()
            }
            Button(action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
        }
    }

    private func boostTitle(_ boost: Double) -> String {
        switch boost {
        case 0: L("never")
        case 0.5: L("less often")
        case 2: L("more often")
        default: L("much more often")
        }
    }
}

private struct ReactionRow: View {
    @Binding var reaction: Reaction
    let remove: () -> Void

    var body: some View {
        HStack {
            Text("When")
            Picker("", selection: $reaction.event) {
                ForEach(CatEvent.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Picker("", selection: $reaction.response) {
                ForEach(ReactionResponse.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            Slider(value: $reaction.chance, in: 0...1)
                .frame(width: 80)
            Text("\(Int((reaction.chance * 100).rounded()))%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
            Button(action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
        }
    }
}
