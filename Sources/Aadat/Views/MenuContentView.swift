import AadatCore
import SwiftUI

/// The window shown when the menu bar item is clicked.
struct MenuContentView: View {
    @ObservedObject var controller: BoardController
    @State private var newTitle = ""
    @State private var addToTomorrow = false
    @State private var showingTomorrow = true
    @State private var showingDeleted = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            addField
            todaySection
            tomorrowSection
            deletedSection
            if let error = controller.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.orange.opacity(0.12)))
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 360)
        .animation(.easeInOut(duration: 0.2), value: controller.board)
        .onAppear {
            controller.checkDay()
            controller.refreshLoginItemState()
            fieldFocused = true
        }
    }

    // MARK: Header

    private var header: some View {
        let board = controller.board
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(board.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProgressRing(done: board.doneCount, total: board.totalCount)
        }
    }

    // MARK: Adding

    private var addField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
            TextField(addToTomorrow ? "Add a task for tomorrow" : "Add a task for today", text: $newTitle)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .onSubmit(add)
            ListToggle(addToTomorrow: $addToTomorrow)
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(fieldFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08))
        )
    }

    private func add() {
        controller.add(newTitle, to: addToTomorrow ? .tomorrow : .today)
        newTitle = ""
        fieldFocused = true
    }

    // MARK: Today

    @ViewBuilder
    private var todaySection: some View {
        let today = controller.board.today
        if today.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "sun.max")
                    .font(.system(size: 20))
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("A clear day").font(.callout.weight(.medium))
                    Text("Type a task above and press Return.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.03)))
        } else {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader(title: "Tasks", count: today.count) {
                    if controller.board.doneCount > 0 {
                        Button("Clear done", action: controller.clearDone)
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .help("Move finished tasks to Recently Deleted")
                    }
                }
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(today) { item in
                            TaskRow(item: item, list: .today, controller: controller)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .frame(maxHeight: 320)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Tomorrow

    @ViewBuilder
    private var tomorrowSection: some View {
        let tomorrow = controller.board.tomorrow
        if !tomorrow.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader(title: "Tomorrow", count: tomorrow.count, expanded: $showingTomorrow)
                if showingTomorrow {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(tomorrow) { item in
                                TaskRow(item: item, list: .tomorrow, controller: controller)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                    .fixedSize(horizontal: false, vertical: true)
                    Text("These move to Today at midnight.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 6)
                }
            }
        }
    }

    // MARK: Recently deleted

    @ViewBuilder
    private var deletedSection: some View {
        let deleted = controller.board.deleted
        if !deleted.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader(title: "Recently Deleted", count: deleted.count, expanded: $showingDeleted) {
                    if showingDeleted {
                        Button("Empty", action: controller.emptyDeleted)
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .help("Delete all of these now")
                    }
                }
                if showingDeleted {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(deleted) { entry in
                                DeletedRow(entry: entry, controller: controller)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                    .fixedSize(horizontal: false, vertical: true)
                    Text("Deleted tasks are kept for 24 hours.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 6)
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(isOn: Binding(
                    get: { controller.loginItemState == .enabled },
                    set: { controller.setLaunchAtLogin($0) }
                )) {
                    Text("Open at login").font(.callout)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
                .help("Quit Aadat (⌘Q)")
            }
            if controller.loginItemState == .requiresApproval {
                Button("Allow Aadat in Login Items settings", action: controller.openLoginItemSettings)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Header pieces

/// Today's progress as a ring with the count inside.
private struct ProgressRing: View {
    let done: Int
    let total: Int

    private var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
    private var allDone: Bool { total > 0 && done == total }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(allDone ? Color.green : Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: fraction)
            if allDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)
            } else {
                Text("\(done)/\(total)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(total == 0 ? .secondary : .primary)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(total == 0 ? "No tasks today" : "\(done) of \(total) tasks done")
    }
}

/// A small capsule that switches new tasks between Today and Tomorrow.
private struct ListToggle: View {
    @Binding var addToTomorrow: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { addToTomorrow.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: addToTomorrow ? "moon.stars.fill" : "sun.max.fill")
                Text(addToTomorrow ? "Tomorrow" : "Today")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(addToTomorrow ? Color.indigo : Color.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill((addToTomorrow ? Color.indigo : Color.orange).opacity(0.14)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("New tasks go to \(addToTomorrow ? "Tomorrow" : "Today"). Click to switch.")
        .accessibilityLabel("Add to \(addToTomorrow ? "Tomorrow" : "Today")")
    }
}

/// A section title with a count, optionally collapsible, with an optional trailing control.
private struct SectionHeader<Trailing: View>: View {
    let title: String
    let count: Int
    var expanded: Binding<Bool>?
    @ViewBuilder var trailing: Trailing

    init(title: String, count: Int, expanded: Binding<Bool>? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.count = count
        self.expanded = expanded
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if let expanded { withAnimation(.easeInOut(duration: 0.2)) { expanded.wrappedValue.toggle() } }
            } label: {
                HStack(spacing: 6) {
                    if let expanded {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .rotationEffect(.degrees(expanded.wrappedValue ? 90 : 0))
                            .frame(width: 10)
                            .foregroundStyle(.secondary)
                    }
                    Text(title.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text("\(count)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(expanded != nil)
            trailing
        }
        .padding(.horizontal, 6)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, count: Int, expanded: Binding<Bool>? = nil) {
        self.init(title: title, count: count, expanded: expanded) { EmptyView() }
    }
}

// MARK: - Task row

private struct TaskRow: View {
    let item: TodoItem
    let list: DayBoard.List
    @ObservedObject var controller: BoardController
    @State private var hovering = false
    @State private var editing = false
    @State private var draft = ""
    @State private var noteDraft = ""
    @FocusState private var focus: EditField?

    private enum EditField { case title, note }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if list == .today {
                Button { controller.toggleDone(item) } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(item.isDone ? Color.green : Color.secondary.opacity(hovering ? 1 : 0.7))
                }
                .buttonStyle(.plain)
                .help(item.isDone ? "Mark not done" : "Mark done")
                .accessibilityLabel(item.isDone ? "Mark \(item.title) not done" : "Mark \(item.title) done")
            } else {
                Image(systemName: "moon.stars")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.indigo.opacity(0.8))
                    .frame(width: 16, height: 16)
            }

            if editing {
                editor
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .strikethrough(item.isDone, color: .secondary)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                        .lineLimit(3)
                    if let note = item.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .help(note)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { startEdit(.title) }
            }

            if hovering && !editing {
                actions.transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(RowBackground(hovering: hovering))
        .onHover { hovering in withAnimation(.easeOut(duration: 0.12)) { self.hovering = hovering } }
        .contextMenu {
            if list == .today && !item.isDone {
                Button("Push to Tomorrow") { controller.pushToTomorrow(item) }
            }
            if list == .tomorrow {
                Button("Move to Today") { controller.moveToToday(item) }
            }
            Button("Edit") { startEdit(.title) }
            Button(item.note == nil ? "Add Note" : "Edit Note") { startEdit(.note) }
            if item.note != nil {
                Button("Remove Note") { controller.setNote(item, to: "") }
            }
            Divider()
            Button("Delete") { controller.remove(item) }
        }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 8) {
            if list == .today && !item.isDone {
                RowIcon("arrow.right.circle", help: "Push to tomorrow") { controller.pushToTomorrow(item) }
            }
            if list == .tomorrow {
                RowIcon("arrow.uturn.backward.circle", help: "Move back to today") { controller.moveToToday(item) }
            }
            RowIcon("square.and.pencil", help: item.note == nil ? "Add a note" : "Edit task and note") {
                startEdit(item.note == nil ? .note : .title)
            }
            RowIcon("trash", help: "Delete (kept in Recently Deleted for 24 hours)") { controller.remove(item) }
        }
    }

    /// Title and note fields. Return saves, Escape cancels, Tab moves between the fields.
    private var editor: some View {
        VStack(alignment: .leading, spacing: 5) {
            TextField("Task", text: $draft)
                .textFieldStyle(.plain)
                .focused($focus, equals: .title)
                .onSubmit(commitEdit)
            TextField("Add a note", text: $noteDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.caption)
                .lineLimit(1...5)
                .focused($focus, equals: .note)
                .onSubmit(commitEdit)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.05)))
            Text("Return to save · Esc to cancel")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onExitCommand(perform: cancelEdit)
        .onChange(of: focus) { field in
            // Clicking outside the row saves, like other macOS lists.
            if field == nil { commitEdit() }
        }
    }

    private func startEdit(_ field: EditField) {
        draft = item.title
        noteDraft = item.note ?? ""
        editing = true
        // Focus once the fields exist.
        DispatchQueue.main.async { focus = field }
    }

    private func commitEdit() {
        guard editing else { return }
        editing = false
        focus = nil
        controller.rename(item, to: draft)
        controller.setNote(item, to: noteDraft)
    }

    private func cancelEdit() {
        editing = false
        focus = nil
    }
}

// MARK: - Deleted row

private struct DeletedRow: View {
    let entry: DeletedItem
    @ObservedObject var controller: BoardController
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            ListTag(list: entry.list)
            Text(entry.item.title)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if hovering {
                HStack(spacing: 8) {
                    RowIcon("arrow.uturn.backward.circle", help: "Restore") { controller.restore(entry) }
                    RowIcon("xmark.circle", help: "Delete now") { controller.deleteForever(entry) }
                }
                .transition(.opacity)
            } else {
                Text(timeLeft)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(RowBackground(hovering: hovering))
        .onHover { hovering in withAnimation(.easeOut(duration: 0.12)) { self.hovering = hovering } }
        .contextMenu {
            Button("Restore") { controller.restore(entry) }
            Divider()
            Button("Delete Now") { controller.deleteForever(entry) }
        }
    }

    private var timeLeft: String {
        let seconds = max(0, entry.expiresAt.timeIntervalSinceNow)
        let hours = Int(seconds / 3600)
        return hours >= 1 ? "\(hours)h left" : "\(max(1, Int(seconds / 60)))m left"
    }
}

/// Which list a deleted task came from.
private struct ListTag: View {
    let list: DayBoard.List

    var body: some View {
        let color: Color = list == .today ? .orange : .indigo
        Text(list == .today ? "Today" : "Tomorrow")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.14)))
            .fixedSize()
    }
}

// MARK: - Shared pieces

private struct RowBackground: View {
    let hovering: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(hovering ? Color.primary.opacity(0.06) : .clear)
    }
}

private struct RowIcon: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    init(_ systemImage: String, help: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
