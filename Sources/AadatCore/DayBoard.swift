import Foundation

/// One task on the board.
public struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    /// Optional short description. Older saved tasks have none.
    public var note: String?
    public var isDone: Bool
    public let createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        note: String? = nil,
        isDone: Bool = false,
        createdAt: Date,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// A task that was deleted, kept for `DayBoard.deletedRetention` so it can be restored.
public struct DeletedItem: Codable, Identifiable, Equatable, Sendable {
    public var item: TodoItem
    /// The list the task was deleted from.
    public let list: DayBoard.List
    public let deletedAt: Date
    /// The board's day when the task was deleted.
    public let day: Date

    public var id: UUID { item.id }
    public var expiresAt: Date { deletedAt.addingTimeInterval(DayBoard.deletedRetention) }
}

/// Today's list plus the list waiting for tomorrow.
///
/// Rules:
/// - A day runs from local midnight to the next local midnight.
/// - Done tasks stay on today's list (marked done) until the day ends.
/// - When the day ends, done tasks are cleared. Unfinished tasks carry over automatically,
///   followed by tomorrow's list, so a task you forgot to push is never lost.
/// - If several days pass with the app closed, everything unfinished is still carried
///   into the next day the app sees.
/// - Deleted tasks go to `deleted` (newest first) and are kept for 24 hours.
public struct DayBoard: Codable, Equatable, Sendable {
    public enum List: String, Codable, Sendable {
        case today
        case tomorrow
    }

    public static let maximumTitleLength = 200
    public static let maximumNoteLength = 500
    /// How long a deleted task can be restored.
    public static let deletedRetention: TimeInterval = 24 * 60 * 60

    /// Start (local midnight) of the day `today` belongs to.
    public private(set) var day: Date
    public private(set) var today: [TodoItem]
    public private(set) var tomorrow: [TodoItem]
    /// Recently deleted tasks, newest first.
    public private(set) var deleted: [DeletedItem]

    public init(day: Date, today: [TodoItem] = [], tomorrow: [TodoItem] = [], deleted: [DeletedItem] = []) {
        self.day = day
        self.today = today
        self.tomorrow = tomorrow
        self.deleted = deleted
    }

    private enum CodingKeys: String, CodingKey {
        case day, today, tomorrow, deleted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Date.self, forKey: .day)
        today = try container.decode([TodoItem].self, forKey: .today)
        tomorrow = try container.decode([TodoItem].self, forKey: .tomorrow)
        // Boards saved before "Recently deleted" existed have no such key.
        deleted = try container.decodeIfPresent([DeletedItem].self, forKey: .deleted) ?? []
    }

    public static func empty(now: Date, calendar: Calendar) -> DayBoard {
        DayBoard(day: calendar.startOfDay(for: now))
    }

    // MARK: Counts

    public var doneCount: Int { today.count { $0.isDone } }
    public var totalCount: Int { today.count }

    // MARK: Day change

    /// Moves to the day containing `now` if it is later than the board's day.
    /// Returns true if the board changed.
    ///
    /// If the clock goes backwards (for example a time zone change), the board is left alone
    /// rather than discarding anything.
    @discardableResult
    public mutating func rollOver(now: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: now)
        guard start > day else { return false }
        let unfinished = today.filter { !$0.isDone }
        today = unfinished + tomorrow.map { item in
            var item = item
            item.isDone = false
            item.completedAt = nil
            return item
        }
        tomorrow = []
        day = start
        return true
    }

    // MARK: Editing

    /// Adds a task. Returns nil (and changes nothing) if the title is empty after trimming.
    @discardableResult
    public mutating func add(_ title: String, to list: List = .today, now: Date) -> TodoItem? {
        guard let title = Self.clean(title) else { return nil }
        let item = TodoItem(title: title, createdAt: now)
        switch list {
        case .today: today.append(item)
        case .tomorrow: tomorrow.append(item)
        }
        return item
    }

    /// Marks a task on today's list done or not done.
    public mutating func toggleDone(id: UUID, now: Date) {
        guard let index = today.firstIndex(where: { $0.id == id }) else { return }
        today[index].isDone.toggle()
        today[index].completedAt = today[index].isDone ? now : nil
    }

    /// Moves an unfinished task from today to tomorrow. Done tasks stay where they are.
    public mutating func pushToTomorrow(id: UUID) {
        guard let index = today.firstIndex(where: { $0.id == id }), !today[index].isDone else { return }
        tomorrow.append(today.remove(at: index))
    }

    /// Brings a task from tomorrow back to today.
    public mutating func moveToToday(id: UUID) {
        guard let index = tomorrow.firstIndex(where: { $0.id == id }) else { return }
        today.append(tomorrow.remove(at: index))
    }

    public mutating func rename(id: UUID, to title: String) {
        guard let title = Self.clean(title) else { return }
        if let index = today.firstIndex(where: { $0.id == id }) {
            today[index].title = title
        } else if let index = tomorrow.firstIndex(where: { $0.id == id }) {
            tomorrow[index].title = title
        }
    }

    /// Sets a task's note. Blank text removes the note.
    public mutating func setNote(id: UUID, to text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = trimmed.isEmpty ? nil : String(trimmed.prefix(Self.maximumNoteLength))
        if let index = today.firstIndex(where: { $0.id == id }) {
            today[index].note = note
        } else if let index = tomorrow.firstIndex(where: { $0.id == id }) {
            tomorrow[index].note = note
        }
    }

    /// Moves a task to Recently Deleted.
    public mutating func remove(id: UUID, now: Date) {
        if let index = today.firstIndex(where: { $0.id == id }) {
            keepDeleted(today.remove(at: index), from: .today, now: now)
        } else if let index = tomorrow.firstIndex(where: { $0.id == id }) {
            keepDeleted(tomorrow.remove(at: index), from: .tomorrow, now: now)
        }
    }

    /// Moves done tasks from today's list to Recently Deleted before midnight.
    public mutating func clearDone(now: Date) {
        for item in today.filter(\.isDone) {
            remove(id: item.id, now: now)
        }
    }

    // MARK: Recently deleted

    /// Puts a deleted task back on the list it came from. If the day has changed since,
    /// that list's day has already arrived (or passed), so the task comes back to today, not done.
    public mutating func restore(id: UUID) {
        guard let index = deleted.firstIndex(where: { $0.id == id }) else { return }
        let entry = deleted.remove(at: index)
        var item = entry.item
        if entry.day == day {
            switch entry.list {
            case .today: today.append(item)
            case .tomorrow: tomorrow.append(item)
            }
        } else {
            item.isDone = false
            item.completedAt = nil
            today.append(item)
        }
    }

    public mutating func deleteForever(id: UUID) {
        deleted.removeAll { $0.id == id }
    }

    public mutating func emptyDeleted() {
        deleted = []
    }

    /// Drops deleted tasks older than `deletedRetention`. Returns true if anything was dropped.
    @discardableResult
    public mutating func purgeExpiredDeleted(now: Date) -> Bool {
        let before = deleted.count
        deleted.removeAll { $0.expiresAt <= now }
        return deleted.count != before
    }

    private mutating func keepDeleted(_ item: TodoItem, from list: List, now: Date) {
        deleted.insert(DeletedItem(item: item, list: list, deletedAt: now, day: day), at: 0)
    }

    private static func clean(_ title: String) -> String? {
        let trimmed = title
            .components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumTitleLength))
    }
}
