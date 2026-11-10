<p align="center">
  <img src="docs/images/logo.png" width="112" alt="Aadat logo">
</p>

<h1 align="center">Aadat</h1>

<p align="center">
  A personal to-do list for <b>today</b> that lives in the macOS menu bar.<br>
  No account, no backend, no sync.
</p>

<p align="center">
  <a href="https://github.com/ananthanarayanan431/Aadat/actions/workflows/ci.yml"><img src="https://github.com/ananthanarayanan431/Aadat/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
</p>

## Features

<table>
  <tr>
    <td width="64" align="center"><img src="docs/images/sun.png" width="40" alt=""></td>
    <td><b>Today</b><br>The list you work from. The menu bar shows today's progress, for example <code>2/5</code>.</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/crescent-moon.png" width="40" alt=""></td>
    <td><b>Tomorrow</b><br>Push an unfinished task to tomorrow, or add straight to it with the Today / Tomorrow switch.</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/midnight.png" width="40" alt=""></td>
    <td><b>Fresh start at midnight</b><br>Done tasks clear, unfinished ones carry over, and Tomorrow's tasks join Today, even if the Mac was asleep.</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/trash.png" width="40" alt=""></td>
    <td><b>Recently Deleted</b><br>Deleted tasks are kept for 24 hours, tagged with the list they came from, and can be restored.</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/lock.png" width="40" alt=""></td>
    <td><b>Private by design</b><br>Everything stays in one file on your Mac: <code>~/Library/Application Support/Aadat/board.json</code>.</td>
  </tr>
</table>

## How it works

- Click the circle to mark a task **done**. Done tasks stay on the list, struck through, until the day ends.
- **Push to tomorrow** (the arrow on hover, or right-click) moves an unfinished task to the **Tomorrow** list.
- At **midnight** (local time) done tasks are cleared and Tomorrow's tasks move to Today.
  Unfinished tasks you didn't push carry over automatically, listed first, so nothing is lost if you forget.
- If the Mac is asleep or off at midnight, the switch happens as soon as it wakes or Aadat starts.
  Unfinished and pushed tasks are never lost, even if several days pass.
- **Delete** (the trash icon on hover, or right-click) moves a task to **Recently Deleted**, as does **Clear done**.
  Hover a deleted task to restore it or delete it now. After 24 hours it is gone for good.
  A task restored after midnight comes back to Today.
- Double-click a task (or right-click, Edit) to rename it.
- Give a task a short **note** with the pencil on hover, or right-click → Add Note.
  The first lines show under the task. Return saves, Esc cancels.

## Install

Requires macOS 13+ and Swift 6 (Xcode or the Command Line Tools).

```sh
git clone https://github.com/ananthanarayanan431/Aadat.git
cd Aadat
make app                              # builds and ad-hoc signs build/Aadat.app
cp -R build/Aadat.app /Applications/
open /Applications/Aadat.app
```

Aadat appears in the menu bar. To start it with your Mac, turn on **Open at login** in its window.

To update, quit Aadat, pull, run `make app` again and replace the copy in `/Applications`. Your tasks are kept.

## Development

```sh
make test      # unit tests for the day logic and storage
make app       # build the app bundle
```

- `Sources/AadatCore` – `DayBoard` (today/tomorrow lists, midnight rollover, recently deleted) and `BoardFileStore` (atomic JSON file). Foundation only, unit tested.
- `Sources/Aadat` – the SwiftUI menu bar app. `BoardController` saves every change and rolls the day over via a midnight timer, the system day-changed and wake notifications, and a check whenever the window opens.

## Credits

Icons by [Icons8](https://icons8.com) (Fluency style).
