# MoveClipBoard

A lightweight macOS menu bar app that restores **two-way clipboard sync** between your Mac and iOS Simulators — broken since Xcode 26.4 — plus clipboard history and snippets.

---

## Why?

Since **Xcode 26.4**, copy-paste between macOS and the iOS Simulator is broken. MoveClipBoard fixes this by bridging both clipboards via `xcrun simctl pbcopy/pbpaste` — with clipboard history and saved snippets as a bonus.

---

## Features

- **Two-way Simulator sync** — push Mac clipboard to any booted simulator, or pull back with one click
- **Clipboard history** — last 100 items, persisted across restarts, searchable
- **Snippets** — save and reuse frequently used text
- **Content-aware** — detects URLs, JSON, file paths, and plain text automatically
- **Menu bar only** — no Dock icon, no Cmd+Tab noise

---

## Requirements

- macOS 14 Sonoma or later
- Xcode installed (for `xcrun simctl`)

---

## Installation

### Homebrew (recommended)

```bash
brew tap ekucet/tap
brew install --cask moveclipboard
```

### Direct Download

Download the latest notarized DMG from the [Releases](https://github.com/ekucet/ClipboardSim/releases/latest) page, open it, and drag **MoveClipBoard.app** to `/Applications`.

> Signed and notarized by Apple — no Gatekeeper warning.

### Build from Source

```bash
git clone https://github.com/ekucet/ClipboardSim.git
cd ClipboardSim
xcodebuild -scheme MoveClipBoard -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/MoveClipBoard.app /Applications/
```

> Local builds are not notarized — first launch: right-click → **Open**.

---

## Usage

Click the clipboard icon in the menu bar to open the panel.

| Action | How |
|---|---|
| Send Mac clipboard → Simulator | Click **→ Sim** |
| Pull Simulator clipboard → Mac | Click **← Mac** |
| Refresh simulator list | Click **↺** |
| Reuse a past item | Click any row in Clipboard tab |
| Save a snippet | Snippets tab → **+** |

On first launch the app will ask to start at login — recommended so it's always running in the background.

---

## How It Works

```
Mac NSPasteboard  ──────────────▶  xcrun simctl pbcopy  <UDID>
                  ◀──────────────  xcrun simctl pbpaste <UDID>
```

Polls `NSPasteboard.changeCount` every 400ms. App Sandbox is disabled (required for `Process`/`xcrun`). No network connections.

---

## License

MIT
