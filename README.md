# MoveClipBoard

A lightweight macOS menu bar app that restores two-way clipboard sync between your Mac and iOS Simulators — broken since Xcode 26.4 — while also keeping a full clipboard history.

---

## Why Does This Exist?

Starting with **Xcode 26.4**, copy-pasting between macOS and the iOS Simulator stopped working. You can no longer:

- Copy text on your Mac and paste it inside the Simulator
- Copy text inside the Simulator and paste it on your Mac

This is a significant productivity blocker during development and testing. Apple hasn't fixed it yet.

**MoveClipBoard** works around this by manually bridging the two clipboards using `xcrun simctl pbcopy` and `xcrun simctl pbpaste` — the same underlying tools Xcode uses, just invoked directly.

As a bonus, it also maintains a persistent **clipboard history** so you never lose something you copied earlier.

---

## Features

- **Two-way Simulator sync** — push your Mac clipboard to any booted simulator, or pull the simulator's clipboard back to Mac with one click
- **Clipboard history** — automatically tracks the last 100 items you've copied, persisted across app restarts
- **Snippets** — save frequently used text snippets for quick access
- **Content-aware display** — automatically detects and labels URLs, JSON, file paths, and plain text
- **Search** — instantly filter through your clipboard history
- **Menu bar only** — lives entirely in the menu bar, no Dock icon, no Cmd+Tab noise
- **Lightweight polling** — monitors the clipboard every 400ms with minimal CPU usage

---

## Requirements

- macOS 14 Ventura or later
- Xcode (for `xcrun simctl`) — already installed if you're a developer
- At least one booted iOS Simulator

---

## Installation

### Option A — Build with Xcode (Recommended)

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/MoveClipBoard.git
   cd MoveClipBoard
   ```

2. Open in Xcode:
   ```bash
   open MoveClipBoard.xcodeproj
   ```

3. Select your team in **Signing & Capabilities** (or use Personal Team for local use), then press **⌘R** to run.

### Option B — Build from Terminal

```bash
git clone https://github.com/your-username/MoveClipBoard.git
cd MoveClipBoard

xcodebuild \
  -scheme MoveClipBoard \
  -configuration Release \
  -derivedDataPath build

cp -R build/Build/Products/Release/MoveClipBoard.app /Applications/
```

Then launch it from `/Applications/MoveClipBoard.app`.

> **First launch:** macOS may show a Gatekeeper warning since the app isn't notarized. Right-click the app → **Open** → **Open** to bypass it once.

### Option C — Add to Login Items (Auto-start)

1. Open **System Settings → General → Login Items**
2. Click **+** and select `MoveClipBoard.app`

The app will now start automatically when you log in and sit silently in the menu bar.

---

## Usage

Click the clipboard icon in the menu bar to open the panel.

### Syncing with Simulator

1. Boot a Simulator in Xcode (or via `xcrun simctl boot <UDID>`)
2. Open MoveClipBoard — your booted simulator will appear in the device picker
3. Use the transfer buttons:
   - **→ Sim** — sends your current Mac clipboard to the selected Simulator
   - **← Mac** — pulls the Simulator's clipboard content to your Mac
4. Hit the **↺** button to refresh the device list if you boot a new simulator

### Clipboard History

- The **Clipboard** tab shows your last 10 copied items (scrollable)
- **Click any row** to instantly copy it back to your Mac clipboard
- Use the **→ Sim** button on a row to send that item directly to the Simulator
- Use the **search bar** to filter through your full history
- Right-click any item for more options: Copy, Send to Simulator, Save as Snippet, Delete

### Snippets

- Switch to the **Snippets** tab
- Click **+** to save a new snippet (pre-filled with your current clipboard)
- Click any snippet row to copy it, or right-click for options

---

## How It Works

```
Mac NSPasteboard  ──────────────────────────▶  xcrun simctl pbcopy <UDID>
                  ◀──────────────────────────  xcrun simctl pbpaste <UDID>
```

MoveClipBoard polls `NSPasteboard.changeCount` every 400ms to detect new clipboard content and maintains a local history. When you trigger a sync, it shells out to `xcrun simctl pbcopy/pbpaste` — the same mechanism Xcode uses internally — to read or write the Simulator's clipboard.

Because `Process` requires spawning a subprocess, **App Sandbox is disabled**. This is intentional and necessary. The app does not make any network connections.

---

## Building from Source — Notes

- **Swift 6**, SwiftUI, `@Observable`
- App Sandbox: **disabled** (required for `xcrun simctl`)
- `LSUIElement`: **YES** (menu bar only, no Dock icon)
- Minimum deployment target: **macOS 14**

---

## License

MIT
