import AadatCore
import SwiftUI

/// The window shown when the menu bar item is clicked.
struct MenuContentView: View {
    @ObservedObject var controller: BoardController
    @State private var newTitle = ""
    @State private var addToTomorrow = false
    @State private var showingTomorrow = true
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            addField
            todayList
            tomorrowSection
            if let error = controller.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)))
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
        .onAppear {
            controller.checkDay()
            controller.refreshLoginItemState()
            fieldFocused = true
        }
    }

    // MARK: Header

    private var header: some View {
        let board = controller.board
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(.headline)
                Text(board.day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(board.totalCount == 0 ? "No tasks" : "\(board.doneCount) of \(board.totalCount) done")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if board.totalCount > 0 {
                ProgressView(value: Double(board.doneCount), total: Double(board.totalCount))
                    .progressViewStyle(.linear)
                    .tint(board.doneCount == board.totalCount ? .green : .accentColor)
            }
        }
    }

    // MARK: Adding

    private var addField: some View {
        HStack(spacing: 6) {
            TextField(addToTomorrow ? "Add a task for tomorrow" : "Add a task for today", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit(add)
            Picker("List", selection: $addToTomorrow) {
                Text("Today").tag(false)
                Text("Tomorrow").tag(true)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .help("Which list new tasks go to")
        }
    }

    private func add() {
        controller.add(newTitle, to: addToTomorrow ? .tomorrow : .today)
        newTitle = ""
        fieldFocused = true
    }

    // MARK: Lists

    @ViewBuilder
    private var todayList: some View {
        if controller.board.today.isEmpty {
            Text("Nothing planned yet. Type a task above and press Return.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(controller.board.today) { item in
                        TaskRow(item: item, list: .today, controller: controller)
                    }
                }
            }
            .frame(maxHeight: 340)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var tomorrowSection: some View {
        let tomorrow = controller.board.tomorrow
        if !tomorrow.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    showingTomorrow.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showingTomorrow ? "chevron.down" : "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .frame(width: 10)
                        Text("Tomorrow").font(.subheadline.weight(.semibold))
                        Text("\(tomorrow.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showingTomorrow {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(tomorrow) { item in
                                TaskRow(item: item, list: .tomorrow, controller: controller)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                    .fixedSize(horizontal: false, vertical: true)
                    Text("These move to Today at midnight.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            if controller.board.doneCount > 0 {
                MenuButton("Clear done tasks", systemImage: "checkmark.circle.badge.xmark") { controller.clearDone() }
            }
            MenuButton(
                controller.loginItemState == .enabled ? "Open at login: on" : "Open at login: off",
                systemImage: controller.loginItemState == .enabled ? "checkmark.square" : "square"
            ) {
                controller.setLaunchAtLogin(controller.loginItemState != .enabled)
            }
            if controller.loginItemState == .requiresApproval {
                Button("Allow Aadat in Login Items settings", action: controller.openLoginItemSettings)
                    .buttonStyle(.link)
                    .font(.caption)
                    .padding(.leading, 6)
            }
            MenuButton("Quit Aadat", systemImage: "power") { NSApp.terminate(nil) }
        }
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
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if list == .today {
                Button { controller.toggleDone(item) } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(item.isDone ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(item.isDone ? "Mark not done" : "Mark done")
                .accessibilityLabel(item.isDone ? "Mark \(item.title) not done" : "Mark \(item.title) done")
            } else {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 15)
            }

            if editing {
                TextField("Task", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($editFocused)
                    .onSubmit(commitEdit)
                    .onExitCommand { editing = false }
                    .onChange(of: editFocused) { focused in
                        if !focused { commitEdit() }
                    }
            } else {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: startEdit)
            }

            if hovering && !editing {
                actions
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? Color.primary.opacity(0.06) : .clear))
        .onHover { hovering = $0 }
        .contextMenu {
            if list == .today && !item.isDone {
                Button("Push to Tomorrow") { controller.pushToTomorrow(item) }
            }
            if list == .tomorrow {
                Button("Move to Today") { controller.moveToToday(item) }
            }
            Button("Edit") { startEdit() }
            Divider()
            Button("Delete") { controller.remove(item) }
        }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 6) {
            if list == .today && !item.isDone {
                RowIcon("arrow.right.circle", help: "Push to tomorrow") { controller.pushToTomorrow(item) }
            }
            if list == .tomorrow {
                RowIcon("arrow.uturn.backward.circle", help: "Move back to today") { controller.moveToToday(item) }
            }
            RowIcon("trash", help: "Delete") { controller.remove(item) }
        }
    }

    private func startEdit() {
        draft = item.title
        editing = true
        editFocused = true
    }

    private func commitEdit() {
        guard editing else { return }
        editing = false
        controller.rename(item, to: draft)
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
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// A full-width, menu-like button.
struct MenuButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? Color.primary.opacity(0.08) : .clear))
        .onHover { hovering = $0 }
    }
}
