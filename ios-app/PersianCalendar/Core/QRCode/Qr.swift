import Foundation

// A QR code encoder, ported from the Kotlin `io.github.persiancalendar.qr` library.
// Used by the Converter screen to render a scannable code for the converted date.

/// Error correction levels, trading capacity for tolerance of a dirty or damaged display.
///
/// Tolerance: L 7%, M 15%, Q 25%, H 30%.
enum ErrorCorrectionLevel: Int, CaseIterable, Sendable {
    // The `rawValue` is the declaration index, used to index the block table; `bits` is the
    // value written into the format information, which is deliberately in a different order.
    case L = 0
    case M = 1
    case Q = 2
    case H = 3

    var bits: Int {
        switch self {
        case .L: 1
        case .M: 0
        case .Q: 3
        case .H: 2
        }
    }
}

/// Encode `input` as a QR dot matrix.
///
/// - Parameters:
///   - input: text to encode, as its UTF-8 bytes.
///   - errorCorrectionLevel: defaults to M, falling back to L if the text doesn't fit.
///   - version: 1...40, or nil to pick the smallest that fits.
///     https://www.qrcode.com/en/about/version.html
/// - Returns: a row-major matrix of booleans, or an empty array if the text cannot be encoded.
func qr(
    _ input: String,
    errorCorrectionLevel requestedLevel: ErrorCorrectionLevel? = nil,
    version requestedVersion: Int? = nil
) -> [[Bool]] {
    let data = Array(input.utf8)
    let errorCorrectionLevel = requestedLevel ?? .M

    let resolvedVersion: Int? = requestedVersion ?? (1...40).first { candidate in
        let rsBlocks = QrRsBlock.getRsBlocks(candidate, errorCorrectionLevel)
        let buffer = QrBitBuffer()
        buffer.put(4, 4)
        buffer.put(data.count, QrUtil.getSizeInBits(candidate))
        buffer.putBytes(data)
        let totalDataCount = rsBlocks.reduce(0) { $0 + $1.dataCount }
        return buffer.sizeInBits <= totalDataCount * 8
    }

    guard let version = resolvedVersion else {
        // Too long for this level: retry at L, which holds the most data.
        return requestedLevel == nil ? qr(input, errorCorrectionLevel: .L) : []
    }

    let size = version * 4 + 17
    var modules = [[Bool?]](repeating: [Bool?](repeating: nil, count: size), count: size)

    guard let cache = createData(version, errorCorrectionLevel, data) else { return [] }

    func make(test: Bool, maskPattern: MaskPattern) {
        for row in 0..<size {
            for col in 0..<size { modules[row][col] = nil }
        }
        setupPositionProbePattern(&modules, 0, 0)
        setupPositionProbePattern(&modules, size - 7, 0)
        setupPositionProbePattern(&modules, 0, size - 7)
        setupPositionAdjustPattern(&modules, version)
        setupTimingPattern(&modules)
        setupTypeInfo(&modules, test, maskPattern, errorCorrectionLevel)
        if version >= 7 { setupVersionNumber(&modules, version, test) }
        mapData(&modules, cache, maskPattern)
    }

    var bestPattern = MaskPattern.allCases[0]
    var bestScore = Double.infinity
    for pattern in MaskPattern.allCases {
        make(test: true, maskPattern: pattern)
        let score = getLostPoint(modules.map { row in row.map { $0! } })
        if score < bestScore {
            bestScore = score
            bestPattern = pattern
        }
    }

    make(test: false, maskPattern: bestPattern)
    return modules.map { row in row.map { $0! } }
}

private let pad0 = 0xec
private let pad1 = 0x11

private enum MaskPattern: Int, CaseIterable {
    case pattern000, pattern001, pattern010, pattern011
    case pattern100, pattern101, pattern110, pattern111

    func mask(_ i: Int, _ j: Int) -> Bool {
        switch self {
        case .pattern000: (i + j) % 2 == 0
        case .pattern001: i % 2 == 0
        case .pattern010: j % 3 == 0
        case .pattern011: (i + j) % 3 == 0
        case .pattern100: ((i / 2) + (j / 3)) % 2 == 0
        case .pattern101: ((i * j) % 2) + ((i * j) % 3) == 0
        case .pattern110: (((i * j) % 2) + ((i * j) % 3)) % 2 == 0
        case .pattern111: (((i * j) % 3) + ((i + j) % 2)) % 2 == 0
        }
    }
}

private func setupPositionProbePattern(_ modules: inout [[Bool?]], _ row: Int, _ col: Int) {
    for r in -1...7 where row + r > -1 && modules.count > row + r {
        for c in -1...7 where col + c > -1 && modules.count > col + c {
            modules[row + r][col + c] =
                ((0...6).contains(r) && (c == 0 || c == 6))
                || ((0...6).contains(c) && (r == 0 || r == 6))
                || ((2...4).contains(r) && 2 <= c && c <= 4)
        }
    }
}

private func setupPositionAdjustPattern(_ modules: inout [[Bool?]], _ version: Int) {
    let pos = QrUtil.getPatternPosition(version)
    for row in pos {
        for col in pos where modules[row][col] == nil {
            for r in -2...2 {
                for c in -2...2 {
                    modules[row + r][col + c] =
                        r == -2 || r == 2 || c == -2 || c == 2 || (r == 0 && c == 0)
                }
            }
        }
    }
}

private func setupTimingPattern(_ modules: inout [[Bool?]]) {
    for r in 8..<(modules.count - 8) where modules[r][6] == nil {
        modules[r][6] = r % 2 == 0
    }
    for c in 8..<(modules.count - 8) where modules[6][c] == nil {
        modules[6][c] = c % 2 == 0
    }
}

private func setupTypeInfo(
    _ modules: inout [[Bool?]],
    _ test: Bool,
    _ maskPattern: MaskPattern,
    _ errorCorrectionLevel: ErrorCorrectionLevel
) {
    let data = (errorCorrectionLevel.bits << 3) | maskPattern.rawValue
    let bits = QrUtil.getBchTypeInfo(data)
    let size = modules.count

    // vertical
    for index in 0..<15 {
        let row = index < 6 ? index : (index < 8 ? index + 1 : size - 15 + index)
        modules[row][8] = !test && ((bits >> index) & 1) == 1
    }

    // horizontal
    for index in 0..<15 {
        let col = index < 8 ? size - index - 1 : (index < 9 ? 15 - index - 1 + 1 : 15 - index - 1)
        modules[8][col] = !test && ((bits >> index) & 1) == 1
    }

    // fixed module
    modules[size - 8][8] = !test
}

private func setupVersionNumber(_ modules: inout [[Bool?]], _ version: Int, _ test: Bool) {
    let bits = QrUtil.getBchTypeNumber(version)
    let size = modules.count
    for index in 0..<18 {
        let mod = !test && ((bits >> index) & 1) == 1
        modules[index / 3][(index % 3) + size - 8 - 3] = mod
    }
    for index in 0..<18 {
        let mod = !test && ((bits >> index) & 1) == 1
        modules[(index % 3) + size - 8 - 3][index / 3] = mod
    }
}

private func mapData(_ modules: inout [[Bool?]], _ data: [Int], _ maskPattern: MaskPattern) {
    var inc = -1
    var row = modules.count - 1
    var bitIndex = 7
    var byteIndex = 0

    var col = modules.count - 1
    while col > 0 {
        if col == 6 { col -= 1 }

        while true {
            for c in 0..<2 where modules[row][col - c] == nil {
                let bit = byteIndex < data.count && ((data[byteIndex] >> bitIndex) & 1) == 1
                modules[row][col - c] = maskPattern.mask(row, col - c) != bit
                bitIndex -= 1
                if bitIndex == -1 {
                    byteIndex += 1
                    bitIndex = 7
                }
            }

            row += inc
            if row < 0 || modules.count <= row {
                row -= inc
                inc = -inc
                break
            }
        }
        col -= 2
    }
}

/// Penalty score for a candidate mask; the lowest-scoring mask is chosen.
private func getLostPoint(_ matrix: [[Bool]]) -> Double {
    let size = matrix.count
    var lostPoint = 0.0

    // LEVEL 1 — adjacent modules of the same colour
    for row in 0..<size {
        for col in 0..<size {
            let isDark = matrix[row][col]
            var sameCount = 0
            for r in -1...1 where (0..<size).contains(row + r) {
                for c in -1...1
                where (0..<size).contains(col + c) && !(r == 0 && c == 0)
                    && isDark == matrix[row + r][col + c]
                {
                    sameCount += 1
                }
            }
            if sameCount > 5 { lostPoint += Double(3 + sameCount - 5) }
        }
    }

    // LEVEL 2 — 2x2 blocks of one colour
    for row in 0..<(size - 1) {
        for col in 0..<(size - 1) {
            var count = 0
            for r in 0..<2 {
                for c in 0..<2 where matrix[row + r][col + c] { count += 1 }
            }
            if count == 0 || count == 4 { lostPoint += 3 }
        }
    }

    // LEVEL 3 — finder-like patterns
    var horizontal = 0
    for row in 0..<size {
        for col in 0..<(size - 6)
        where (0..<7).allSatisfy({ matrix[row][col + $0] != ($0 == 1 || $0 == 5) }) {
            horizontal += 1
        }
    }
    lostPoint += Double(horizontal) * 40.0

    var vertical = 0
    for col in 0..<size {
        for row in 0..<(size - 6)
        where (0..<7).allSatisfy({ matrix[row + $0][col] != ($0 == 1 || $0 == 5) }) {
            vertical += 1
        }
    }
    lostPoint += Double(vertical) * 40.0

    // LEVEL 4 — imbalance between dark and light
    var darkCount = 0
    for col in 0..<size {
        for row in 0..<size where matrix[row][col] { darkCount += 1 }
    }
    let ratio = abs((100.0 * Double(darkCount)) / Double(size) / Double(size) - 50) / 5
    lostPoint += ratio * 10

    return lostPoint
}

private struct Rs {
    let dataCount: Int
    let totalCount: Int
}

private func createBytes(_ buffer: QrBitBuffer, _ rsBlocks: [Rs]) -> [Int] {
    var offset = 0
    var maxDcCount = 0
    var maxEcCount = 0

    var dcData = [[Int]](repeating: [], count: rsBlocks.count)
    var ecData = [[Int]](repeating: [], count: rsBlocks.count)

    for r in rsBlocks.indices {
        let dcCount = rsBlocks[r].dataCount
        let ecCount = rsBlocks[r].totalCount - dcCount

        maxDcCount = max(maxDcCount, dcCount)
        maxEcCount = max(maxEcCount, ecCount)

        dcData[r] = (0..<dcCount).map { 0xff & buffer[$0 + offset] }
        offset += dcCount

        let rsPoly = QrUtil.getErrorCorrectPolynomial(ecCount)
        let rawPoly = QrPolynomial(dcData[r], shift: rsPoly.count - 1)

        let modPoly = rawPoly.modulo(rsPoly)
        let ecDataSize = rsPoly.count - 1
        ecData[r] = (0..<ecDataSize).map { index in
            let modIndex = index + modPoly.count - ecDataSize
            return modIndex >= 0 ? modPoly[modIndex] : 0
        }
    }

    let totalCodeCount = rsBlocks.reduce(0) { $0 + $1.totalCount }
    var data = [Int](repeating: 0, count: totalCodeCount)
    var index = 0

    for i in 0..<maxDcCount {
        for r in dcData where i < r.count {
            data[index] = r[i]
            index += 1
        }
    }
    for i in 0..<maxEcCount {
        for r in ecData where i < r.count {
            data[index] = r[i]
            index += 1
        }
    }
    return data
}

/// Returns nil when the data overflows the chosen version, where the Kotlin original throws.
private func createData(
    _ version: Int, _ errorCorrectionLevel: ErrorCorrectionLevel, _ data: [UInt8]
) -> [Int]? {
    let rsBlocks = QrRsBlock.getRsBlocks(version, errorCorrectionLevel)
    let buffer = QrBitBuffer()

    buffer.put(4, 4)
    buffer.put(data.count, QrUtil.getSizeInBits(version))
    buffer.putBytes(data)

    let totalDataCount = rsBlocks.reduce(0) { $0 + $1.dataCount }
    if buffer.sizeInBits > totalDataCount * 8 { return nil }

    // End code
    if buffer.sizeInBits + 4 <= totalDataCount * 8 { buffer.put(0, 4) }

    // Pad to a byte boundary
    while buffer.sizeInBits % 8 != 0 { buffer.putBit(false) }

    // Pad with the alternating fill bytes
    while true {
        if buffer.sizeInBits >= totalDataCount * 8 { break }
        buffer.put(pad0, 8)
        if buffer.sizeInBits >= totalDataCount * 8 { break }
        buffer.put(pad1, 8)
    }

    return createBytes(buffer, rsBlocks)
}

private enum QrUtil {
    static let patternPositionTable: [[Int]] = [
        [],
        [6, 18],
        [6, 22],
        [6, 26],
        [6, 30],
        [6, 34],
        [6, 22, 38],
        [6, 24, 42],
        [6, 26, 46],
        [6, 28, 50],
        [6, 30, 54],
        [6, 32, 58],
        [6, 34, 62],
        [6, 26, 46, 66],
        [6, 26, 48, 70],
        [6, 26, 50, 74],
        [6, 30, 54, 78],
        [6, 30, 56, 82],
        [6, 30, 58, 86],
        [6, 34, 62, 90],
        [6, 28, 50, 72, 94],
        [6, 26, 50, 74, 98],
        [6, 30, 54, 78, 102],
        [6, 28, 54, 80, 106],
        [6, 32, 58, 84, 110],
        [6, 30, 58, 86, 114],
        [6, 34, 62, 90, 118],
        [6, 26, 50, 74, 98, 122],
        [6, 30, 54, 78, 102, 126],
        [6, 26, 52, 78, 104, 130],
        [6, 30, 56, 82, 108, 134],
        [6, 34, 60, 86, 112, 138],
        [6, 30, 58, 86, 114, 142],
        [6, 34, 62, 90, 118, 146],
        [6, 30, 54, 78, 102, 126, 150],
        [6, 24, 50, 76, 102, 128, 154],
        [6, 28, 54, 80, 106, 132, 158],
        [6, 32, 58, 84, 110, 136, 162],
        [6, 26, 54, 82, 110, 138, 166],
        [6, 30, 58, 86, 114, 142, 17],
    ]

    private static let g15 =
        (1 << 10) | (1 << 8) | (1 << 5) | (1 << 4) | (1 << 2) | (1 << 1) | (1 << 0)
    private static let g18 =
        (1 << 12) | (1 << 11) | (1 << 10) | (1 << 9) | (1 << 8) | (1 << 5) | (1 << 2) | (1 << 0)
    private static let g15Mask = (1 << 14) | (1 << 12) | (1 << 10) | (1 << 4) | (1 << 1)

    private static func getBchDigit(_ data: Int) -> Int {
        var d = data
        var digit = 0
        while d != 0 {
            digit += 1
            d = Int(bitPattern: UInt(bitPattern: d) >> 1)
        }
        return digit
    }

    static func getBchTypeInfo(_ data: Int) -> Int {
        var d = data << 10
        while getBchDigit(d) - getBchDigit(g15) >= 0 {
            d ^= g15 << (getBchDigit(d) - getBchDigit(g15))
        }
        return ((data << 10) | d) ^ g15Mask
    }

    static func getBchTypeNumber(_ data: Int) -> Int {
        var d = data << 12
        while getBchDigit(d) - getBchDigit(g18) >= 0 {
            d ^= g18 << (getBchDigit(d) - getBchDigit(g18))
        }
        return (data << 12) | d
    }

    static func getPatternPosition(_ version: Int) -> [Int] { patternPositionTable[version - 1] }

    static func getErrorCorrectPolynomial(_ errorCorrectLength: Int) -> QrPolynomial {
        var a = QrPolynomial([1])
        for index in 0..<errorCorrectLength {
            a = a.multiplied(by: QrPolynomial([1, QrMath.gExp(index)]))
        }
        return a
    }

    static func getSizeInBits(_ type: Int) -> Int {
        switch type {
        case 1...9: 8
        case 10...40: 16
        default: preconditionFailure("type: \(type)")
        }
    }
}

/// Arithmetic in GF(256), the Galois field QR error correction is defined over.
private enum QrMath {
    private static let expTable: [Int] = {
        var table: [Int] = (0..<8).map { 1 << $0 }
        for index in 8..<256 {
            table.append(table[index - 4] ^ table[index - 5] ^ table[index - 6] ^ table[index - 8])
        }
        return table
    }()

    private static let logTable: [Int] = {
        var table = [Int](repeating: 0, count: 256)
        for index in 0..<255 { table[expTable[index]] = index }
        return table
    }()

    static func gLog(_ n: Int) -> Int {
        precondition(n >= 1, "gLog(\(n))")
        return logTable[n]
    }

    /// Handles negative exponents explicitly rather than relying on modulo sign conventions.
    static func gExp(_ n: Int) -> Int {
        expTable[n == 0 ? 0 : (n < 0 ? 254 - (-n - 1) % 255 : (n - 1) % 255 + 1)]
    }
}

private struct QrPolynomial {
    private let num: [Int]

    init(_ source: [Int], shift: Int = 0) {
        var offset = 0
        while offset < source.count && source[offset] == 0 { offset += 1 }
        var result = [Int](repeating: 0, count: source.count - offset + shift)
        for index in 0..<(source.count - offset) { result[index] = source[index + offset] }
        self.num = result
    }

    subscript(index: Int) -> Int { num[index] }
    var count: Int { num.count }

    func multiplied(by other: QrPolynomial) -> QrPolynomial {
        var result = [Int](repeating: 0, count: count + other.count - 1)
        for i in 0..<count {
            for j in 0..<other.count {
                result[i + j] ^= QrMath.gExp(QrMath.gLog(self[i]) + QrMath.gLog(other[j]))
            }
        }
        return QrPolynomial(result)
    }

    func modulo(_ other: QrPolynomial) -> QrPolynomial {
        if count - other.count < 0 { return self }
        let ratio = QrMath.gLog(self[0]) - QrMath.gLog(other[0])
        var result = num
        for index in 0..<other.count {
            result[index] ^= QrMath.gExp(QrMath.gLog(other[index]) + ratio)
        }
        return QrPolynomial(result).modulo(other)
    }
}

private enum QrRsBlock {
    private static let rsBlockTable: [[Int]] = [
        // L
        // M
        // Q
        // H
        // 1
        [1, 26, 19],
        [1, 26, 16],
        [1, 26, 13],
        [1, 26, 9],
        // 2
        [1, 44, 34],
        [1, 44, 28],
        [1, 44, 22],
        [1, 44, 16],
        // 3
        [1, 70, 55],
        [1, 70, 44],
        [2, 35, 17],
        [2, 35, 13],
        // 4
        [1, 100, 80],
        [2, 50, 32],
        [2, 50, 24],
        [4, 25, 9],
        // 5
        [1, 134, 108],
        [2, 67, 43],
        [2, 33, 15, 2, 34, 16],
        [2, 33, 11, 2, 34, 12],
        // 6
        [2, 86, 68],
        [4, 43, 27],
        [4, 43, 19],
        [4, 43, 15],
        // 7
        [2, 98, 78],
        [4, 49, 31],
        [2, 32, 14, 4, 33, 15],
        [4, 39, 13, 1, 40, 14],
        // 8
        [2, 121, 97],
        [2, 60, 38, 2, 61, 39],
        [4, 40, 18, 2, 41, 19],
        [4, 40, 14, 2, 41, 15],
        // 9
        [2, 146, 116],
        [3, 58, 36, 2, 59, 37],
        [4, 36, 16, 4, 37, 17],
        [4, 36, 12, 4, 37, 13],
        // 10
        [2, 86, 68, 2, 87, 69],
        [4, 69, 43, 1, 70, 44],
        [6, 43, 19, 2, 44, 20],
        [6, 43, 15, 2, 44, 16],
        // 11
        [4, 101, 81],
        [1, 80, 50, 4, 81, 51],
        [4, 50, 22, 4, 51, 23],
        [3, 36, 12, 8, 37, 13],
        // 12
        [2, 116, 92, 2, 117, 93],
        [6, 58, 36, 2, 59, 37],
        [4, 46, 20, 6, 47, 21],
        [7, 42, 14, 4, 43, 15],
        // 13
        [4, 133, 107],
        [8, 59, 37, 1, 60, 38],
        [8, 44, 20, 4, 45, 21],
        [12, 33, 11, 4, 34, 12],
        // 14
        [3, 145, 115, 1, 146, 116],
        [4, 64, 40, 5, 65, 41],
        [11, 36, 16, 5, 37, 17],
        [11, 36, 12, 5, 37, 13],
        // 15
        [5, 109, 87, 1, 110, 88],
        [5, 65, 41, 5, 66, 42],
        [5, 54, 24, 7, 55, 25],
        [11, 36, 12, 7, 37, 13],
        // 16
        [5, 122, 98, 1, 123, 99],
        [7, 73, 45, 3, 74, 46],
        [15, 43, 19, 2, 44, 20],
        [3, 45, 15, 13, 46, 16],
        // 17
        [1, 135, 107, 5, 136, 108],
        [10, 74, 46, 1, 75, 47],
        [1, 50, 22, 15, 51, 23],
        [2, 42, 14, 17, 43, 15],
        // 18
        [5, 150, 120, 1, 151, 121],
        [9, 69, 43, 4, 70, 44],
        [17, 50, 22, 1, 51, 23],
        [2, 42, 14, 19, 43, 15],
        // 19
        [3, 141, 113, 4, 142, 114],
        [3, 70, 44, 11, 71, 45],
        [17, 47, 21, 4, 48, 22],
        [9, 39, 13, 16, 40, 14],
        // 20
        [3, 135, 107, 5, 136, 108],
        [3, 67, 41, 13, 68, 42],
        [15, 54, 24, 5, 55, 25],
        [15, 43, 15, 10, 44, 16],
        // 21
        [4, 144, 116, 4, 145, 117],
        [17, 68, 42],
        [17, 50, 22, 6, 51, 23],
        [19, 46, 16, 6, 47, 17],
        // 22
        [2, 139, 111, 7, 140, 112],
        [17, 74, 46],
        [7, 54, 24, 16, 55, 25],
        [34, 37, 13],
        // 23
        [4, 151, 121, 5, 152, 122],
        [4, 75, 47, 14, 76, 48],
        [11, 54, 24, 14, 55, 25],
        [16, 45, 15, 14, 46, 16],
        // 24
        [6, 147, 117, 4, 148, 118],
        [6, 73, 45, 14, 74, 46],
        [11, 54, 24, 16, 55, 25],
        [30, 46, 16, 2, 47, 17],
        // 25
        [8, 132, 106, 4, 133, 107],
        [8, 75, 47, 13, 76, 48],
        [7, 54, 24, 22, 55, 25],
        [22, 45, 15, 13, 46, 16],
        // 26
        [10, 142, 114, 2, 143, 115],
        [19, 74, 46, 4, 75, 47],
        [28, 50, 22, 6, 51, 23],
        [33, 46, 16, 4, 47, 17],
        // 27
        [8, 152, 122, 4, 153, 123],
        [22, 73, 45, 3, 74, 46],
        [8, 53, 23, 26, 54, 24],
        [12, 45, 15, 28, 46, 16],
        // 28
        [3, 147, 117, 10, 148, 118],
        [3, 73, 45, 23, 74, 46],
        [4, 54, 24, 31, 55, 25],
        [11, 45, 15, 31, 46, 16],
        // 29
        [7, 146, 116, 7, 147, 117],
        [21, 73, 45, 7, 74, 46],
        [1, 53, 23, 37, 54, 24],
        [19, 45, 15, 26, 46, 16],
        // 30
        [5, 145, 115, 10, 146, 116],
        [19, 75, 47, 10, 76, 48],
        [15, 54, 24, 25, 55, 25],
        [23, 45, 15, 25, 46, 16],
        // 31
        [13, 145, 115, 3, 146, 116],
        [2, 74, 46, 29, 75, 47],
        [42, 54, 24, 1, 55, 25],
        [23, 45, 15, 28, 46, 16],
        // 32
        [17, 145, 115],
        [10, 74, 46, 23, 75, 47],
        [10, 54, 24, 35, 55, 25],
        [19, 45, 15, 35, 46, 16],
        // 33
        [17, 145, 115, 1, 146, 116],
        [14, 74, 46, 21, 75, 47],
        [29, 54, 24, 19, 55, 25],
        [11, 45, 15, 46, 46, 16],
        // 34
        [13, 145, 115, 6, 146, 116],
        [14, 74, 46, 23, 75, 47],
        [44, 54, 24, 7, 55, 25],
        [59, 46, 16, 1, 47, 17],
        // 35
        [12, 151, 121, 7, 152, 122],
        [12, 75, 47, 26, 76, 48],
        [39, 54, 24, 14, 55, 25],
        [22, 45, 15, 41, 46, 16],
        // 36
        [6, 151, 121, 14, 152, 122],
        [6, 75, 47, 34, 76, 48],
        [46, 54, 24, 10, 55, 25],
        [2, 45, 15, 64, 46, 16],
        // 37
        [17, 152, 122, 4, 153, 123],
        [29, 74, 46, 14, 75, 47],
        [49, 54, 24, 10, 55, 25],
        [24, 45, 15, 46, 46, 16],
        // 38
        [4, 152, 122, 18, 153, 123],
        [13, 74, 46, 32, 75, 47],
        [48, 54, 24, 14, 55, 25],
        [42, 45, 15, 32, 46, 16],
        // 39
        [20, 147, 117, 4, 148, 118],
        [40, 75, 47, 7, 76, 48],
        [43, 54, 24, 22, 55, 25],
        [10, 45, 15, 67, 46, 16],
        // 40
        [19, 148, 118, 6, 149, 119],
        [18, 75, 47, 31, 76, 48],
        [34, 54, 24, 34, 55, 25],
        [20, 45, 15, 61, 46, 16],
    ]

    private static func getRsBlockTable(
        _ version: Int, _ errorCorrectionLevel: ErrorCorrectionLevel
    ) -> [Int] {
        rsBlockTable[(version - 1) * 4 + errorCorrectionLevel.rawValue]
    }

    static func getRsBlocks(
        _ version: Int, _ errorCorrectionLevel: ErrorCorrectionLevel
    ) -> [Rs] {
        let rsBlock = getRsBlockTable(version, errorCorrectionLevel)
        return (0..<(rsBlock.count / 3)).flatMap { index -> [Rs] in
            let count = rsBlock[index * 3 + 0]
            let totalCount = rsBlock[index * 3 + 1]
            let dataCount = rsBlock[index * 3 + 2]
            return (0..<count).map { _ in Rs(dataCount: dataCount, totalCount: totalCount) }
        }
    }
}

/// A growable bit-level buffer, packed most-significant-bit first.
private final class QrBitBuffer {
    private var buffer: [Int] = []
    private var size = 0

    subscript(index: Int) -> Int { buffer[index] }

    var sizeInBits: Int { size }

    func put(_ num: Int, _ length: Int) {
        for index in 0..<length { putBit(((num >> (length - index - 1)) & 1) == 1) }
    }

    func putBit(_ bit: Bool) {
        let bufIndex = size / 8
        if buffer.count <= bufIndex { buffer.append(0) }
        if bit { buffer[bufIndex] |= 0x80 >> (size % 8) }
        size += 1
    }

    func putBytes(_ bytes: [UInt8]) {
        for byte in bytes { put(Int(byte), 8) }
    }
}
