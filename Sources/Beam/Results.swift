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
