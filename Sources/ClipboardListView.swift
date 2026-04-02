import SwiftUI
import AppKit
import CoreGraphics

struct ClipboardListView: View {
    @State private var items: [ClipboardItem] = []
    @State private var searchText: String = ""
    
    var onPaste: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Search...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .onChange(of: searchText) { _ in
                    loadItems()
                }
            
            Divider()
            
            List(items, id: \.id) { item in
                Button(action: {
                    pasteItem(item)
                }) {
                    Text(item.preview)
                        .lineLimit(1)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .listStyle(PlainListStyle())
        }
        .frame(width: 350, height: 450)
        .onAppear {
            loadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardUpdated)) { _ in
            loadItems()
        }
    }
    
    private func loadItems() {
        if searchText.isEmpty {
            items = DatabaseManager.shared.fetchLatestItems(limit: 50)
        } else {
            items = DatabaseManager.shared.searchItems(query: searchText, limit: 50)
        }
    }
    
    private func pasteItem(_ item: ClipboardItem) {
        guard let rawData = DatabaseManager.shared.fetchRawData(for: item.id),
              let pbItemsData = try? PropertyListDecoder().decode([PasteboardItemData].self, from: rawData) else {
            return
        }
        
        // 1. Write the selected item to the global Pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var objectsToPaste: [NSPasteboardItem] = []
        for pbData in pbItemsData {
            let pbItem = NSPasteboardItem()
            for rep in pbData.representations {
                pbItem.setData(rep.data, forType: NSPasteboard.PasteboardType(rep.type))
            }
            objectsToPaste.append(pbItem)
        }
        
        pasteboard.writeObjects(objectsToPaste)
        
        // 2. Hide our app window so the previously active app regains keyboard focus
        onPaste()
        
        // 3. Briefly delay to give macOS time to focus the previous app, then simulate Cmd+V
        // Non-native apps like VSCode and IntelliJ often need a slightly longer delay (e.g. 0.3s) to process window focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            simulatePasteCommand()
        }
    }
    
    private func simulatePasteCommand() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        cmdDown?.flags = .maskCommand
        
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        cmdUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}

extension Notification.Name {
    static let clipboardUpdated = Notification.Name("clipboardUpdated")
}
