import AadatCore
import AppKit
import Foundation

/// Owns the board, saves every change, and moves to the next day at local midnight.
///
/// Midnight is caught three ways, so a sleeping or closed Mac never misses it:
/// a timer aimed at the next midnight, the system's day-changed and wake notifications,
/// and a check whenever the window opens or the board is edited.
@MainActor
final class BoardController: ObservableObject {
    @Published private(set) var board: DayBoard
    @Published private(set) var loginItemState: LoginItem.State = .disabled
    @Published private(set) var lastError: String?

    private let store: BoardFileStore?
    /// False when the saved file came from a newer version; we then never overwrite it.
    private var canSave = true
    private var midnightTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    private var calendar: Calendar { .autoupdatingCurrent }

    init() {
        let now = Date()
        var store: BoardFileStore?
        var board: DayBoard?
        do {
            let opened = try BoardFileStore.standard()
            store = opened
            board = try opened.load()
        } catch {
            Log.storage.error("Could not load tasks: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            if error is BoardFileStore.StoreError { canSave = false }
        }
        self.store = store
        self.board = board ?? .empty(now: now, calendar: .autoupdatingCurrent)
        let rolled = self.board.rollOver(now: now, calendar: calendar)
        let purged = self.board.purgeExpiredDeleted(now: now)
        if rolled || purged { save() }
    }

    func start() {
        refreshLoginItemState()
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        for (nc, name) in [
            (center, Notification.Name.NSCalendarDayChanged),
            (center, Notification.Name.NSSystemTimeZoneDidChange),
            (center, Notification.Name.NSSystemClockDidChange),
            (workspace, NSWorkspace.didWakeNotification),
        ] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkDay() }
            })
        }
        scheduleMidnight()
    }

    // MARK: Day change

    /// Rolls the board over if the day has changed, and drops deleted tasks older than 24 hours.
    func checkDay() {
        let now = Date()
        let rolled = board.rollOver(now: now, calendar: calendar)
        if rolled { Log.app.notice("New day; tomorrow's tasks moved to today") }
        let purged = board.purgeExpiredDeleted(now: now)
        if rolled || purged { save() }
    }

    private func scheduleMidnight() {
        midnightTask?.cancel()
        midnightTask = Task { [weak self] in
            while !Task.isCancelled {
                let now = Date()
                let calendar = Calendar.autoupdatingCurrent
                let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
                    ?? now.addingTimeInterval(3600)
                // Wake a second after midnight; never sleep more than an hour, as a safety net
                // against clock changes the notifications miss.
                let delay = min(max(midnight.timeIntervalSince(now) + 1, 1), 3600)
                try? await Task.sleep(for: .seconds(delay))
                self?.checkDay()
            }
        }
    }

    // MARK: Editing

    func add(_ title: String, to list: DayBoard.List = .today) {
        edit { $0.add(title, to: list, now: Date()) }
    }

    func toggleDone(_ item: TodoItem) {
        edit { $0.toggleDone(id: item.id, now: Date()) }
    }

    func pushToTomorrow(_ item: TodoItem) {
        edit { $0.pushToTomorrow(id: item.id) }
    }

    func moveToToday(_ item: TodoItem) {
        edit { $0.moveToToday(id: item.id) }
    }

    func rename(_ item: TodoItem, to title: String) {
        edit { $0.rename(id: item.id, to: title) }
    }

    func remove(_ item: TodoItem) {
        edit { $0.remove(id: item.id, now: Date()) }
    }

    func clearDone() {
        edit { $0.clearDone(now: Date()) }
    }

    func restore(_ entry: DeletedItem) {
        edit { $0.restore(id: entry.id) }
    }

    func deleteForever(_ entry: DeletedItem) {
        edit { $0.deleteForever(id: entry.id) }
    }

    func emptyDeleted() {
        edit { $0.emptyDeleted() }
    }

    private func edit(_ change: (inout DayBoard) -> Void) {
        let now = Date()
        board.rollOver(now: now, calendar: calendar)
        board.purgeExpiredDeleted(now: now)
        change(&board)
        save()
    }

    private func save() {
        guard canSave, let store else { return }
        do {
            try store.save(board)
            lastError = nil
        } catch {
            Log.storage.error("Could not save tasks: \(error.localizedDescription, privacy: .public)")
            lastError = "Could not save: \(error.localizedDescription)"
        }
    }

    // MARK: Launch at login

    func refreshLoginItemState() {
        loginItemState = LoginItem.state
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
        } catch {
            lastError = "Launch at login: \(error.localizedDescription)"
        }
        refreshLoginItemState()
    }

    func openLoginItemSettings() {
        LoginItem.openSystemSettings()
    }
}
