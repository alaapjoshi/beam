import AppKit
import BeamCore

/// One row in the result list. `run` is Enter, `alt` is ⌘Enter (e.g. reveal in Finder).
struct Item: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: NSImage
    let run: () -> Void
    var alt: (() -> Void)? = nil
}

private let workspace = NSWorkspace.shared

// MARK: Apps

/// Installed apps, scanned once at launch and refreshed in the background each time the bar opens.
final class AppIndex {
    private(set) var apps: [(name: String, url: URL)] = []
    private var icons: [URL: NSImage] = [:]
    private var usage: [String: Int] = UserDefaults.standard.dictionary(forKey: "usage") as? [String: Int] ?? [:]

    func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            let roots = ["/Applications", "/Applications/Utilities", "/System/Applications",
                         "/System/Applications/Utilities", NSHomeDirectory() + "/Applications"]
            var found = roots.flatMap { root in
                ((try? fm.contentsOfDirectory(atPath: root)) ?? [])
                    .filter { $0.hasSuffix(".app") }
                    .map { (name: String($0.dropLast(4)), url: URL(fileURLWithPath: root + "/" + $0)) }
            }
            found.append((name: "Finder", url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")))
            DispatchQueue.main.async { self.apps = found }
        }
    }

    func icon(_ url: URL) -> NSImage {
        if let i = icons[url] { return i }
        let i = workspace.icon(forFile: url.path)
        icons[url] = i
        return i
    }

    /// Fuzzy score plus a bonus for apps you open often, like Alfred's learning.
    func search(_ q: String) -> [(score: Int, item: Item)] {
        apps.compactMap { app in
            guard let s = fuzzyScore(q, app.name) else { return nil }
            let uses = usage[app.url.path, default: 0]
            let item = Item(title: app.name, subtitle: app.url.path, icon: icon(app.url),
                            run: { [weak self] in self?.open(app.url) },
                            alt: { workspace.activateFileViewerSelecting([app.url]) })
            return (s + min(uses, 30) * 2, item)
        }
    }

    private func open(_ url: URL) {
        usage[url.path, default: 0] += 1
        UserDefaults.standard.set(usage, forKey: "usage")
        workspace.openApplication(at: url, configuration: .init())
    }
}

// MARK: Files

/// Spotlight file search (same index Alfred uses), limited to your home folder.
/// Runs off the main thread; `done` gets up to `limit` file URLs.
func searchFiles(_ term: String, limit: Int = 9, done: @escaping ([URL]) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let p = Process(), pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        p.arguments = ["-onlyin", NSHomeDirectory(), "-name", term]
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return done([]) }
        // Read only until we have enough matches, then stop mdfind (broad terms can match thousands).
        var buffer = "", urls: [URL] = []
        while urls.count < limit {
            let chunk = pipe.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            buffer += String(decoding: chunk, as: UTF8.self)
            var lines = buffer.components(separatedBy: "\n")
            buffer = lines.removeLast()
            urls += lines
                .filter { !$0.contains("/Library/") && !$0.contains("/.") && !$0.hasSuffix(".app") }
                .map { URL(fileURLWithPath: $0) }
        }
        if p.isRunning { p.terminate() }
        urls = Array(urls.prefix(limit))
        done(urls)
    }
}

func fileItem(_ url: URL) -> Item {
    Item(title: url.lastPathComponent, subtitle: url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
         icon: workspace.icon(forFile: url.path),
         run: { workspace.open(url) },
         alt: { workspace.activateFileViewerSelecting([url]) })
}
