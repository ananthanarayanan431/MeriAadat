# Aadat

A personal to-do list for today that lives in the macOS menu bar. No account, no backend, no sync.
Tasks are stored in one file on this Mac: `~/Library/Application Support/Aadat/board.json`.

## How it works

- **Today** is the list you work from. The menu bar shows today's count, for example `2/5`.
- Click the circle to mark a task **done**. Done tasks stay on the list, struck through, until the day ends.
- **Push to tomorrow** (the arrow on hover, or right-click) moves an unfinished task to the **Tomorrow** list.
  You can also add straight to Tomorrow with the picker next to the text field.
- At **midnight** (local time) today's list is cleared and Tomorrow's tasks become Today's.
  Unfinished tasks that were not pushed are dropped with the old day.
- If the Mac is asleep or off at midnight, the switch happens as soon as it wakes or Aadat starts.
  Tasks pushed to tomorrow are never lost, even if several days pass.
- Double-click a task (or right-click, Edit) to rename it. "Clear done tasks" removes finished ones early.

## Build and run

Requires macOS 13+ and Swift 6 (Xcode or Command Line Tools).

```sh
make test      # unit tests for the day logic and storage
make app       # builds and ad-hoc signs build/Aadat.app
open build/Aadat.app
```

To keep it, copy `build/Aadat.app` to `/Applications` and turn on "Open at login" from its menu.

## Layout

- `Sources/AadatCore` – `DayBoard` (today/tomorrow lists and midnight rollover) and `BoardFileStore` (atomic JSON file). Foundation only, unit tested.
- `Sources/Aadat` – the SwiftUI menu bar app. `BoardController` saves every change and rolls the day over via a midnight timer, the system day-changed and wake notifications, and a check whenever the window opens.
