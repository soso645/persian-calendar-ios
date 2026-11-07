import Foundation

/// One entry of a repeating shift-work pattern: a shift type and how many days it lasts.
struct ShiftWorkRecord: Hashable, Sendable {
    let type: String
    let length: Int
}

/// A shift-work rota, resolving which shift falls on a given day.
struct ShiftWorkSettings: Hashable, Sendable {
    let recurs: Bool
    let startingJdn: Jdn?
    let records: [ShiftWorkRecord]

    init(recurs: Bool = true, startingJdn: Jdn? = nil, records: [ShiftWorkRecord] = []) {
        self.recurs = recurs
        self.startingJdn = startingJdn
        self.records = records
    }

    private var totalDays: Int { records.reduce(0) { $0 + $1.length } }

    /// The shift type on `jdn`, or nil if the rota doesn't cover that day.
    ///
    /// - Parameters:
    ///   - titles: user-supplied display names per shift type.
    ///   - abbreviated: shorten to initials, and hide rest days in a recurring rota.
    func workTitle(
        for jdn: Jdn, titles: [String: String] = [:], abbreviated: Bool = false
    ) -> String? {
        guard let startingJdn, jdn >= startingJdn, totalDays != 0 else { return nil }

        let passedDays = jdn - startingJdn
        if !recurs && passedDays >= totalDays { return nil }

        let dayInPeriod = passedDays % totalDays

        var accumulation = 0
        var type: String?
        for record in records {
            accumulation += record.length
            if accumulation > dayInPeriod {
                type = record.type
                break
            }
        }
        guard let type else { return nil }

        // Skip rests in abbreviated mode
        if recurs && abbreviated && (type == "r" || type == titles["r"]) { return nil }

        let title = titles[type] ?? type
        if abbreviated && !title.isEmpty && title.count > 2 {
            return title.split(separator: "/")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .compactMap { $0.first.map(String.init) }
                .joined(separator: "/")
        }
        return title
    }

    /// Serialize to the Android `"type=length,type=length"` format.
    var serialized: String {
        records.map { "\($0.type)=\($0.length)" }.joined(separator: ",")
    }

    static func parse(_ text: String) -> [ShiftWorkRecord] {
        text.split(separator: ",").compactMap { entry in
            let parts = entry.split(separator: "=")
            guard parts.count == 2 else { return nil }
            return ShiftWorkRecord(type: String(parts[0]), length: Int(parts[1]) ?? 1)
        }
    }
}
