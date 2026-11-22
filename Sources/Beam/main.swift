import AppKit
import Carbon
import ServiceManagement
import SwiftUI

/// Borderless panel that can take keyboard focus without activating Beam,
/// so the app you were in stays frontmost.
final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Launcher()
    var panel: Panel!
    var hotKey: EventHotKeyRef?

    func applicationDidFinishLaunching(_ note: Notification) {
        // Built once and kept alive: opening is just orderFront, which is what makes it instant.
        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: LauncherView(model: model))
        model.hide = { [weak self] in self?.hide() }
        model.apps.refresh()

        installKeyMonitor()
        registerHotKey()
        try? SMAppService.mainApp.register()  // start at login; fails harmlessly outside a .app bundle
    }

    /// Double-clicking Beam.app while it's running opens the bar.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        show()
        return false
    }

    func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        model.query = ""
        model.apps.refresh()
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let f = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: f.midX - 340, y: f.maxY - f.height * 0.22 - 560))
        panel.makeKeyAndOrderFront(nil)
        model.shown += 1
    }

    func hide() { panel.orderOut(nil) }

    func windowDidResignKey(_ note: Notification) { hide() }  // click elsewhere = dismiss

    /// Arrows / Enter / Esc / ⌘1-9 are caught before the text field sees them.
    func installKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, self.panel.isKeyWindow else { return e }
            let cmd = e.modifierFlags.contains(.command)
            switch e.keyCode {
            case 125: self.model.move(1)                       // ↓
            case 126: self.model.move(-1)                      // ↑
            case 36, 76: self.model.run(alt: cmd)              // Enter / ⌘Enter
            case 53: self.hide()                               // Esc
            default:
                if cmd, let n = Int(e.charactersIgnoringModifiers ?? ""), (1...9).contains(n) {
                    self.model.run(n - 1)
                } else { return e }
            }
            return nil
        }
    }

    func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { (NSApp.delegate as? AppDelegate)?.toggle() }
            return noErr
        }, 1, &spec, nil, nil)
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(cmdKey), EventHotKeyID(signature: 0x4245_414D, id: 1),
                                         GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr {
            let alert = NSAlert()
            alert.messageText = "Beam couldn't grab ⌘Space"
            alert.informativeText = "Another app (Alfred or Spotlight) is using it. Quit Alfred, or turn off Spotlight's shortcut in System Settings → Keyboard → Keyboard Shortcuts → Spotlight, then reopen Beam."
            alert.runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
