import SwiftUI

/// The menu bar item: a checklist icon and today's "done/total" count.
struct MenuBarLabel: View {
    @ObservedObject var controller: BoardController

    var body: some View {
        let board = controller.board
        HStack(spacing: 3) {
            Image(systemName: allDone ? "checkmark.circle" : "checklist")
            if board.totalCount > 0 {
                Text("\(board.doneCount)/\(board.totalCount)")
                    .monospacedDigit()
            }
        }
        .accessibilityLabel("Aadat, \(board.doneCount) of \(board.totalCount) tasks done today")
    }

    private var allDone: Bool {
        controller.board.totalCount > 0 && controller.board.doneCount == controller.board.totalCount
    }
}
