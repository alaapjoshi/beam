/// Fuzzy matching: query letters must appear in order in the target.
/// Higher score = better. Prefix and word-start hits ("vsc" → "Visual Studio Code") score highest.
public func fuzzyScore(_ query: String, _ target: String) -> Int? {
    let q = Array(query.lowercased()), t = Array(target.lowercased())
    if q.isEmpty { return 0 }
    var score = 0, qi = 0, prev = -2
    for (ti, ch) in t.enumerated() where qi < q.count && ch == q[qi] {
        let wordStart = ti == 0 || t[ti - 1] == " " || t[ti - 1] == "-" || t[ti - 1] == "."
        score += wordStart ? 10 : 1
        if ti == prev + 1 { score += 5 }
        prev = ti
        qi += 1
    }
    guard qi == q.count else { return nil }
    if t.starts(with: q) { score += 50 }
    return score - t.count / 4  // prefer shorter names on ties
}
