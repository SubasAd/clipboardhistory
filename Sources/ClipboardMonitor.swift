import AppKit

final class ClipboardMonitor: @unchecked Sendable {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkClipboard()
        }
        print("Clipboard Monitor started...")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        print("Clipboard Monitor stopped.")
    }

    private func checkClipboard() {
        let currentChangeCount = pasteboard.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount

            guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return }
            
            var previewText = ""
            var detectedFileNames: [String] = []
            
            // Try reading native NSURLs (Finder standard)
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                detectedFileNames.append(contentsOf: urls.filter { $0.isFileURL }.map { $0.lastPathComponent })
            }
            
            // Fallback for non-native apps (VSCode, IntelliJ, etc) that write public.file-url text directly
            if detectedFileNames.isEmpty {
                for item in items {
                    if let fileURLString = item.string(forType: .fileURL)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       let url = URL(string: fileURLString) {
                        detectedFileNames.append(url.lastPathComponent)
                    } else if let fileURLData = item.data(forType: .fileURL),
                              let urlString = String(data: fileURLData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                              let url = URL(string: urlString) {
                        detectedFileNames.append(url.lastPathComponent)
                    }
                }
            }
            
            // Deduplicate
            var uniqueNames: [String] = []
            for name in detectedFileNames {
                if !uniqueNames.contains(name) { uniqueNames.append(name) }
            }
            
            if !uniqueNames.isEmpty {
                let fileNames = uniqueNames.joined(separator: ", ")
                previewText = uniqueNames.count == 1 ? "[File: \(fileNames)]" : "[Files: \(fileNames)]"
            } else if let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
                previewText = string
            } else if items.contains(where: { $0.types.contains(where: { t in t.rawValue.contains("image") }) }) {
                previewText = "[Image]"
            } else if items.contains(where: { $0.types.contains(where: { t in t.rawValue.contains("file-url") }) }) {
                previewText = "[File]"
            } else {
                previewText = "[Rich Content]"
            }
            
            var pbItemsData: [PasteboardItemData] = []
            for item in items {
                var reps: [PasteboardRepresentation] = []
                for type in item.types {
                    if let data = item.data(forType: type) {
                        reps.append(PasteboardRepresentation(type: type.rawValue, data: data))
                    }
                }
                pbItemsData.append(PasteboardItemData(representations: reps))
            }
            
            guard !pbItemsData.isEmpty else { return }
            
            if let encodedData = try? PropertyListEncoder().encode(pbItemsData) {
                DatabaseManager.shared.saveItem(previewText: previewText, data: encodedData)
                NotificationCenter.default.post(name: .clipboardUpdated, object: nil)
            }
        }
    }
}
