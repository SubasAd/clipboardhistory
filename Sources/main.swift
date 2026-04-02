import Cocoa
import SwiftUI
import HotKey

// 1. Force early initialization of the database
_ = DatabaseManager.shared

// 2. Start monitoring the clipboard
let monitor = ClipboardMonitor()
monitor.start()

// 3. Create AppDelegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel!
    var hotKey: HotKey!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background app
        NSApp.setActivationPolicy(.accessory)
        
        let contentView = ClipboardListView(onPaste: {
            self.hideWindow()
        })
        
        // We use an NSPanel which is suitable for floating tool palettes
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 450),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        
        // Setup HotKey for Cmd+Shift+V
        hotKey = HotKey(key: .v, modifiers: [.command, .shift])
        hotKey.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleWindow()
            }
        }
    }
    
    func toggleWindow() {
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideWindow() {
        window.orderOut(nil)
        NSApp.hide(nil)
    }
}

// 4. Start NSApplication
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
