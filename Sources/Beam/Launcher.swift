import SwiftUI

/// Holds the query and turns it into ranked results.
final class Launcher: ObservableObject {
    @Published var query = "" { didSet { update() } }
    @Published var results: [Item] = []
    @Published var selected = 0
    @Published var shown = 0  // bumped on each open so the view refocuses the field

    let apps = AppIndex()
    var hide: () -> Void = {}
    private var fileSearchID = 0

    static let maxResults = 9

    /// Apps show instantly; Spotlight file matches are appended when they arrive (~60 ms).
    func update() {
        selected = 0
        let q = query.trimmingCharacters(in: .whitespaces)
        fileSearchID += 1
        let appItems = Array(apps.search(q).sorted { $0.score > $1.score }.map(\.item).prefix(Self.maxResults))
        results = q.isEmpty ? [] : appItems
        guard q.count >= 2, appItems.count < Self.maxResults else { return }

        let id = fileSearchID
        searchFiles(q, limit: Self.maxResults - appItems.count) { urls in
            DispatchQueue.main.async {
                guard id == self.fileSearchID else { return }  // a newer keystroke won
                self.results = appItems + urls.map(fileItem)
            }
        }
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selected = (selected + delta + results.count) % results.count
    }

    func run(_ index: Int? = nil, alt: Bool = false) {
        let i = index ?? selected
        guard results.indices.contains(i) else { return }
        let item = results[i]
        hide()
        (alt ? item.alt ?? item.run : item.run)()
    }
}

struct LauncherView: View {
    @ObservedObject var model: Launcher
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .light))
                .padding(.horizontal, 18).padding(.vertical, 14)
                .focused($focused)
            if !model.results.isEmpty {
                Divider()
                VStack(spacing: 2) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { i, item in
                        row(item, i)
                    }
                }
                .padding(6)
            }
        }
        .frame(width: 680)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)))
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: model.shown) { focused = true }
        .onAppear { focused = true }
    }

    private func row(_ item: Item, _ i: Int) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: item.icon).resizable().frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 15)).lineLimit(1)
                Text(item.subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text("⌘\(i + 1)").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(i == model.selected ? Color.accentColor.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { model.run(i) }
    }
}
