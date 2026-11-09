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
        board.clearDone()
        #expect(board.today.isEmpty)
        board.remove(id: b.id)
        #expect(board.tomorrow.isEmpty)
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
