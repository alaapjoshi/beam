import SwiftUI

/// Holds the query and turns it into ranked results.
final class Launcher: ObservableObject {
    @Published var query = "" { didSet { update() } }
    @Published var results: [Item] = []
    @Published var selected = 0
    @Published var shown = 0  // bumped on each open so the view refocuses the field

    let apps = AppIndex()
    var hide: () -> Void = {}

    static let maxResults = 9

    func update() {
        selected = 0
        let q = query.trimmingCharacters(in: .whitespaces)
        results = q.isEmpty ? [] : Array(apps.search(q).sorted { $0.score > $1.score }.map(\.item).prefix(Self.maxResults))
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
        // GlassEffectContainer lets the bar and the results panel blend as one piece of glass.
        glassGroup {
            VStack(spacing: 8) {
                TextField("Search", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .light))
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .focused($focused)
                    .glassCard(radius: 22)
                if !model.results.isEmpty {
                    VStack(spacing: 2) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { i, item in
                            row(item, i)
                        }
                    }
                    .padding(6)
                    .glassCard(radius: 18)
                }
            }
        }
        .frame(width: 680)
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: model.shown) { focused = true }
        .onAppear { focused = true }
    }

    @ViewBuilder
    private func glassGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(macOS 26, *) { GlassEffectContainer(spacing: 8) { content() } } else { content() }
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

private extension View {
    /// Liquid Glass on macOS 26; the older blur material with a thin border before that.
    @ViewBuilder
    func glassCard(radius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.1)))
        }
    }
}
