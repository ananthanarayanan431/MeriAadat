import Foundation

/// One task on the board.
public struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var isDone: Bool
    public let createdAt: Date
    public var completedAt: Date?

    public init(id: UUID = UUID(), title: String, isDone: Bool = false, createdAt: Date, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// Today's list plus the list waiting for tomorrow.
///
/// Rules:
/// - A day runs from local midnight to the next local midnight.
/// - Done tasks stay on today's list (marked done) until the day ends.
/// - When the day ends, today's list is cleared and tomorrow's list becomes today's.
/// - If several days pass with the app closed, tasks pushed to "tomorrow" are still carried
///   into the next day the app sees, so nothing that was pushed is lost.
public struct DayBoard: Codable, Equatable, Sendable {
    public enum List: String, Codable, Sendable {
        case today
        case tomorrow
    }

    public static let maximumTitleLength = 200

    /// Start (local midnight) of the day `today` belongs to.
    public private(set) var day: Date
    public private(set) var today: [TodoItem]
    public private(set) var tomorrow: [TodoItem]

    public init(day: Date, today: [TodoItem] = [], tomorrow: [TodoItem] = []) {
        self.day = day
        self.today = today
        self.tomorrow = tomorrow
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
        today = tomorrow.map { item in
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

    public mutating func remove(id: UUID) {
        today.removeAll { $0.id == id }
        tomorrow.removeAll { $0.id == id }
    }

    /// Removes done tasks from today's list before midnight.
    public mutating func clearDone() {
        today.removeAll { $0.isDone }
    }

    private static func clean(_ title: String) -> String? {
        let trimmed = title
            .components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumTitleLength))
    }
}
