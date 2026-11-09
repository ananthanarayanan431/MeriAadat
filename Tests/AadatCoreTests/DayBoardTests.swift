import Foundation
import Testing
@testable import AadatCore

@Suite("DayBoard")
struct DayBoardTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test("Adding trims, rejects blanks and counts toward today")
    func adding() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let blank = board.add("   ", now: date(10, 9))
        #expect(blank == nil)
        let item = board.add("  Write report \n", now: date(10, 9))
        #expect(item?.title == "Write report")
        #expect(board.totalCount == 1)
        #expect(board.doneCount == 0)
    }

    @Test("Done tasks stay on today's list and count as done")
    func doneStays() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let a = board.add("A", now: date(10, 9))!
        board.add("B", now: date(10, 9))
        board.toggleDone(id: a.id, now: date(10, 10))

        #expect(board.today.map(\.title) == ["A", "B"])
        #expect(board.doneCount == 1)
        #expect(board.totalCount == 2)
        #expect(board.today[0].completedAt == date(10, 10))

        board.toggleDone(id: a.id, now: date(10, 11))
        #expect(board.doneCount == 0)
        #expect(board.today[0].completedAt == nil)
    }

    @Test("Nothing changes before midnight")
    func sameDay() {
        var board = DayBoard.empty(now: date(10, 0, 1), calendar: calendar)
        board.add("A", now: date(10, 9))
        let changed = board.rollOver(now: date(10, 23, 59), calendar: calendar)
        #expect(!changed)
        #expect(board.totalCount == 1)
    }

    @Test("At midnight today clears and tomorrow becomes today")
    func midnight() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let done = board.add("Done task", now: date(10, 9))!
        board.add("Unfinished task", now: date(10, 9))
        let pushed = board.add("Pushed task", now: date(10, 9))!
        board.toggleDone(id: done.id, now: date(10, 10))
        board.pushToTomorrow(id: pushed.id)
        board.add("Planned task", to: .tomorrow, now: date(10, 20))

        let changed = board.rollOver(now: date(11, 0, 0), calendar: calendar)
        #expect(changed)

        #expect(board.day == date(11, 0))
        #expect(board.today.map(\.title) == ["Pushed task", "Planned task"])
        #expect(board.tomorrow.isEmpty)
        #expect(board.doneCount == 0)
    }

    @Test("Pushed tasks survive several days with the app closed")
    func skippedDays() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let pushed = board.add("Pushed", now: date(10, 9))!
        board.pushToTomorrow(id: pushed.id)

        let changed = board.rollOver(now: date(14, 8), calendar: calendar)
        #expect(changed)
        #expect(board.today.map(\.title) == ["Pushed"])
        #expect(board.day == date(14, 0))
    }

    @Test("A clock moving backwards keeps the board")
    func clockBackwards() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        board.add("A", now: date(10, 9))
        let changed = board.rollOver(now: date(9, 23), calendar: calendar)
        #expect(!changed)
        #expect(board.totalCount == 1)
    }

    @Test("Done tasks cannot be pushed; tomorrow tasks can come back")
    func pushRules() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let a = board.add("A", now: date(10, 9))!
        board.toggleDone(id: a.id, now: date(10, 9))
        board.pushToTomorrow(id: a.id)
        #expect(board.tomorrow.isEmpty)

        let b = board.add("B", now: date(10, 9))!
        board.pushToTomorrow(id: b.id)
        #expect(board.tomorrow.map(\.title) == ["B"])
        board.moveToToday(id: b.id)
        #expect(board.tomorrow.isEmpty)
        #expect(board.today.map(\.title) == ["A", "B"])
    }

    @Test("Rename, remove and clear done")
    func editing() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let a = board.add("A", now: date(10, 9))!
        let b = board.add("B", to: .tomorrow, now: date(10, 9))!
        board.rename(id: b.id, to: "B2")
        board.rename(id: a.id, to: "  ")
        #expect(board.tomorrow[0].title == "B2")
        #expect(board.today[0].title == "A")

        board.toggleDone(id: a.id, now: date(10, 9))
        board.clearDone(now: date(10, 9))
        #expect(board.today.isEmpty)
        board.remove(id: b.id, now: date(10, 9))
        #expect(board.tomorrow.isEmpty)
    }
}

@Suite("Recently deleted")
struct RecentlyDeletedTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test("Deleting keeps the task, newest first, tagged with its list")
    func deleteKeeps() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let a = board.add("A", now: date(10, 9))!
        let b = board.add("B", to: .tomorrow, now: date(10, 9))!
        board.remove(id: a.id, now: date(10, 10))
        board.remove(id: b.id, now: date(10, 11))

        #expect(board.today.isEmpty)
        #expect(board.tomorrow.isEmpty)
        #expect(board.deleted.map(\.item.title) == ["B", "A"])
        #expect(board.deleted.map(\.list) == [.tomorrow, .today])
        #expect(board.deleted[1].deletedAt == date(10, 10))
    }

    @Test("Clear done sends done tasks to recently deleted")
    func clearDoneKeeps() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let a = board.add("A", now: date(10, 9))!
        board.add("B", now: date(10, 9))
        board.toggleDone(id: a.id, now: date(10, 9))
        board.clearDone(now: date(10, 12))
        #expect(board.today.map(\.title) == ["B"])
        #expect(board.deleted.map(\.item.title) == ["A"])
        #expect(board.deleted[0].item.isDone)
    }

    @Test("Restore puts a task back on the list it came from")
    func restoreSameDay() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let a = board.add("A", now: date(10, 9))!
        let b = board.add("B", to: .tomorrow, now: date(10, 9))!
        board.toggleDone(id: a.id, now: date(10, 9))
        board.remove(id: a.id, now: date(10, 10))
        board.remove(id: b.id, now: date(10, 10))

        board.restore(id: a.id)
        board.restore(id: b.id)
        #expect(board.today.map(\.title) == ["A"])
        #expect(board.today[0].isDone)
        #expect(board.tomorrow.map(\.title) == ["B"])
        #expect(board.deleted.isEmpty)
    }

    @Test("After midnight a restored task comes back to today, not done")
    func restoreNextDay() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let a = board.add("A", now: date(10, 9))!
        let b = board.add("B", to: .tomorrow, now: date(10, 9))!
        board.toggleDone(id: a.id, now: date(10, 9))
        board.remove(id: a.id, now: date(10, 20))
        board.remove(id: b.id, now: date(10, 20))
        board.rollOver(now: date(11, 8), calendar: calendar)
        #expect(board.deleted.count == 2)

        board.restore(id: a.id)
        board.restore(id: b.id)
        #expect(board.today.map(\.title) == ["A", "B"])
        #expect(board.today.allSatisfy { !$0.isDone && $0.completedAt == nil })
        #expect(board.tomorrow.isEmpty)
    }

    @Test("Deleted tasks are gone for good after 24 hours")
    func expiry() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let a = board.add("A", now: date(10, 9))!
        let b = board.add("B", now: date(10, 9))!
        board.remove(id: a.id, now: date(10, 10))
        board.remove(id: b.id, now: date(10, 12))

        let early = board.purgeExpiredDeleted(now: date(11, 9, 59))
        #expect(!early)
        #expect(board.deleted.count == 2)
        let onTime = board.purgeExpiredDeleted(now: date(11, 10))
        #expect(onTime)
        #expect(board.deleted.map(\.item.title) == ["B"])
    }

    @Test("Delete forever and empty")
    func deleteForever() {
        var board = DayBoard.empty(now: date(10, 9), calendar: calendar)
        let a = board.add("A", now: date(10, 9))!
        let b = board.add("B", now: date(10, 9))!
        board.remove(id: a.id, now: date(10, 10))
        board.remove(id: b.id, now: date(10, 10))
        board.deleteForever(id: a.id)
        #expect(board.deleted.map(\.item.title) == ["B"])
        board.emptyDeleted()
        #expect(board.deleted.isEmpty)
    }

    @Test("A board saved before this feature still loads")
    func oldFileLoads() throws {
        let json = #"{"day":"2026-11-09T18:30:00Z","today":[],"tomorrow":[]}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let board = try decoder.decode(DayBoard.self, from: Data(json.utf8))
        #expect(board.deleted.isEmpty)
    }
}

@Suite("Notes")
struct NoteTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }()

    @Test("A note is trimmed, keeps its lines, and clears when empty")
    func setNote() {
        var board = DayBoard.empty(now: now, calendar: calendar)
        let a = board.add("A", now: now)!
        #expect(board.today[0].note == nil)

        board.setNote(id: a.id, to: "  Call before 5pm\nAsk about the invoice \n\n")
        #expect(board.today[0].note == "Call before 5pm\nAsk about the invoice")

        board.setNote(id: a.id, to: "   \n ")
        #expect(board.today[0].note == nil)
    }

    @Test("Long notes are cut to the maximum length")
    func longNote() {
        var board = DayBoard.empty(now: now, calendar: calendar)
        let a = board.add("A", now: now)!
        board.setNote(id: a.id, to: String(repeating: "x", count: DayBoard.maximumNoteLength + 50))
        #expect(board.today[0].note?.count == DayBoard.maximumNoteLength)
    }

    @Test("A note travels with its task")
    func noteTravels() {
        var board = DayBoard.empty(now: now, calendar: calendar)
        let a = board.add("A", now: now)!
        let b = board.add("B", to: .tomorrow, now: now)!
        board.setNote(id: a.id, to: "note a")
        board.setNote(id: b.id, to: "note b")

        board.pushToTomorrow(id: a.id)
        #expect(board.tomorrow.first { $0.id == a.id }?.note == "note a")

        board.remove(id: b.id, now: now)
        #expect(board.deleted[0].item.note == "note b")
        board.restore(id: b.id)

        board.rollOver(now: now.addingTimeInterval(86_400), calendar: calendar)
        #expect(board.today.compactMap(\.note).sorted() == ["note a", "note b"])
    }

    @Test("Tasks saved before notes existed still load")
    func oldItemLoads() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"A","isDone":false,"createdAt":"2026-11-09T18:30:00Z"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let item = try decoder.decode(TodoItem.self, from: Data(json.utf8))
        #expect(item.note == nil)
    }
}

@Suite("BoardFileStore")
struct BoardFileStoreTests {
    func makeStore() throws -> BoardFileStore {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("aadat-tests-\(UUID().uuidString)", isDirectory: true)
        return BoardFileStore(applicationSupportDirectory: base)
    }

    @Test("Missing file loads as nil; saved board round-trips")
    func roundTrip() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory.deletingLastPathComponent()) }
        #expect(try store.load() == nil)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var board = DayBoard.empty(now: now, calendar: .current)
        board.add("A", now: now)
        board.add("B", to: .tomorrow, now: now)
        try store.save(board)
        #expect(try store.load() == board)
    }

    @Test("Unreadable file is set aside, not lost")
    func corrupt() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)

        #expect(try store.load() == nil)
        #expect(try Data(contentsOf: store.quarantineURL) == Data("not json".utf8))
    }
}
