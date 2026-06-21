import Foundation

enum DataExportService {

    // MARK: - Public API

    static func exportAllData(checkIns: [CheckIn], journals: [DailyJournal]) throws -> URL {
        let ts = Int(Date().timeIntervalSince1970)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("cathier_export_\(ts)", isDirectory: true)
        try? FileManager.default.removeItem(at: tmp)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let sorted = checkIns.sorted { $0.date < $1.date }
        let sortedJ = journals.sorted { $0.date < $1.date }

        let files: [(name: String, data: Data)] = [
            ("checkins.json",  try jsonCheckIns(sorted)),
            ("journals.json",  try jsonJournals(sortedJ)),
            ("checkins.html",  Data(htmlCheckIns(sorted).utf8)),
            ("journals.html",  Data(htmlJournals(sortedJ).utf8)),
        ]

        let zipURL = tmp.appendingPathComponent("cathier_data.zip")
        try writeZip(files: files, to: zipURL)
        return zipURL
    }

    // MARK: - JSON

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func jsonCheckIns(_ checkIns: [CheckIn]) throws -> Data {
        let arr: [[String: Any]] = checkIns.map { c in
            var d: [String: Any] = [
                "id":          c.id.uuidString,
                "date":        iso8601.string(from: c.date),
                "bodyParts":   c.bodyParts,
                "sensations":  c.sensations,
                "intensity":   c.intensity,
                "emotions":    c.emotions,
                "note":        c.note,
                "triggerEvent": c.triggerEvent,
            ]
            if !c.aiFeedback.isEmpty { d["aiFeedback"] = c.aiFeedback }
            return d
        }
        return try JSONSerialization.data(withJSONObject: arr,
                                          options: [.prettyPrinted, .sortedKeys])
    }

    private static func jsonJournals(_ journals: [DailyJournal]) throws -> Data {
        let arr: [[String: Any]] = journals.map { j in [
            "id":       j.id.uuidString,
            "date":     iso8601.string(from: j.date),
            "mood":     j.mood,
            "gains":    j.gains,
            "isShared": j.isShared,
        ]}
        return try JSONSerialization.data(withJSONObject: arr,
                                          options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - HTML helpers

    private static let displayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let exportTS: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .medium
        return f
    }()

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Check-ins HTML

    private static func htmlCheckIns(_ checkIns: [CheckIn]) -> String {
        var rows = ""
        for c in checkIns.reversed() {
            let emotions = c.emotions.isEmpty ? "—" : c.emotions.map { "<span class=\"tag\">\(escape($0))</span>" }.joined(separator: " ")
            let bodyParts = c.bodyParts.isEmpty ? "—" : c.bodyParts.map { "<span class=\"tag bp\">\(escape($0))</span>" }.joined(separator: " ")
            let note = c.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let trigger = c.triggerEvent.trimmingCharacters(in: .whitespacesAndNewlines)
            let ai = c.aiFeedback.trimmingCharacters(in: .whitespacesAndNewlines)

            var extra = ""
            if !trigger.isEmpty { extra += "<p class=\"field\"><span class=\"label\">触发事件</span>\(escape(trigger))</p>" }
            if !note.isEmpty    { extra += "<p class=\"field\"><span class=\"label\">备注</span>\(escape(note))</p>" }
            if !ai.isEmpty {
                if let sf = StructuredFeedback.parse(ai) {
                    extra += """
                    <div class=\"ai\">
                      <p><strong>摘要</strong> \(escape(sf.summary))</p>
                      <p><strong>洞察</strong> \(escape(sf.insight))</p>
                      <p><strong>身心联系</strong> \(escape(sf.connection))</p>
                      <p><strong>建议</strong> \(escape(sf.suggestion))</p>
                    </div>
                    """
                } else {
                    extra += "<div class=\"ai\">\(escape(ai).replacingOccurrences(of: "\n", with: "<br>"))</div>"
                }
            }

            rows += """
            <article class="entry">
              <div class="entry-date">\(displayDate.string(from: c.date))</div>
              <div class="entry-row">
                <span class="intensity-badge">强度 \(c.intensity)/10</span>
                <span>\(emotions)</span>
              </div>
              <div class="entry-row">\(bodyParts)</div>
              \(extra)
            </article>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="zh">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Cathier — 情绪觉察打卡记录</title>
        \(sharedCSS())
        </head>
        <body>
        <header>
          <h1>Cathier</h1>
          <p class="subtitle">情绪觉察打卡记录 · 共 \(checkIns.count) 条</p>
          <p class="export-time">导出时间：\(exportTS.string(from: Date()))</p>
        </header>
        <main>
        \(rows)
        </main>
        </body>
        </html>
        """
    }

    // MARK: - Journals HTML

    private static func htmlJournals(_ journals: [DailyJournal]) -> String {
        var rows = ""
        for j in journals.reversed() {
            let mood = j.dailyMood
            let moodEmoji = mood?.emoji ?? ""
            let moodLabel = mood?.label(for: .zh) ?? j.mood
            let gains = j.gains.trimmingCharacters(in: .whitespacesAndNewlines)
            let sharedBadge = j.isShared ? "<span class=\"tag shared\">已分享</span>" : ""

            rows += """
            <article class="entry">
              <div class="entry-date">\(displayDate.string(from: j.date))</div>
              <div class="entry-row">
                <span class="mood-badge" style="background:\(mood?.colorHex ?? "#888")22;color:\(mood?.colorHex ?? "#888")">\(moodEmoji) \(escape(moodLabel))</span>
                \(sharedBadge)
              </div>
              \(gains.isEmpty ? "" : "<div class=\"gains\">\(escape(gains).replacingOccurrences(of: "\n", with: "<br>"))</div>")
            </article>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="zh">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Cathier — 日记</title>
        \(sharedCSS())
        </head>
        <body>
        <header>
          <h1>Cathier</h1>
          <p class="subtitle">日记 · 共 \(journals.count) 篇</p>
          <p class="export-time">导出时间：\(exportTS.string(from: Date()))</p>
        </header>
        <main>
        \(rows)
        </main>
        </body>
        </html>
        """
    }

    // MARK: - Shared CSS

    private static func sharedCSS() -> String {
        """
        <style>
        *, *::before, *::after { box-sizing: border-box; }
        body {
          font-family: -apple-system, "PingFang SC", "Helvetica Neue", sans-serif;
          font-size: 15px;
          line-height: 1.6;
          color: #1a1a1a;
          background: #f9f6f2;
          margin: 0;
          padding: 0 16px 40px;
        }
        header {
          max-width: 720px;
          margin: 0 auto;
          padding: 32px 0 16px;
          border-bottom: 2px solid #e07800;
          margin-bottom: 24px;
        }
        h1 {
          margin: 0 0 4px;
          font-size: 28px;
          color: #e07800;
          letter-spacing: -0.5px;
        }
        .subtitle { margin: 0; color: #555; font-size: 15px; }
        .export-time { margin: 4px 0 0; color: #aaa; font-size: 12px; }
        main { max-width: 720px; margin: 0 auto; }
        .entry {
          background: #fff;
          border-radius: 14px;
          padding: 16px 20px;
          margin-bottom: 14px;
          box-shadow: 0 1px 4px rgba(0,0,0,.06);
        }
        .entry-date { font-size: 12px; color: #999; margin-bottom: 8px; }
        .entry-row { margin-bottom: 6px; }
        .tag {
          display: inline-block;
          background: #fff3e0;
          color: #e07800;
          border-radius: 20px;
          padding: 2px 10px;
          font-size: 12px;
          margin: 2px 2px 2px 0;
        }
        .tag.bp { background: #e8f4fd; color: #1a7dc4; }
        .tag.shared { background: #e8f5e9; color: #388e3c; }
        .intensity-badge {
          display: inline-block;
          background: #e07800;
          color: #fff;
          border-radius: 20px;
          padding: 2px 10px;
          font-size: 12px;
          font-weight: 600;
          margin-right: 8px;
        }
        .mood-badge {
          display: inline-block;
          border-radius: 20px;
          padding: 3px 12px;
          font-size: 13px;
          font-weight: 600;
        }
        .field { margin: 6px 0 0; font-size: 14px; color: #444; }
        .label {
          display: inline-block;
          font-size: 11px;
          font-weight: 600;
          color: #aaa;
          text-transform: uppercase;
          letter-spacing: .5px;
          margin-right: 6px;
        }
        .ai {
          margin-top: 10px;
          background: #fff8f0;
          border-left: 3px solid #e07800;
          border-radius: 0 8px 8px 0;
          padding: 10px 14px;
          font-size: 14px;
          color: #555;
        }
        .ai p { margin: 4px 0; }
        .gains {
          margin-top: 10px;
          font-size: 14px;
          color: #444;
          white-space: pre-wrap;
        }
        </style>
        """
    }

    // MARK: - ZIP writer (pure Swift, STORED method)

    private static func writeZip(files: [(name: String, data: Data)], to url: URL) throws {
        var archive = Data()
        var cd = Data()            // central directory

        let (dosTime, dosDate) = currentDosDateTime()

        for file in files {
            let nameBytes = Data(file.name.utf8)
            let crc      = crc32(file.data)
            let size     = UInt32(file.data.count)
            let offset   = UInt32(archive.count)

            // Local file header
            var lh = Data()
            lh.appendLE(UInt32(0x04034b50))   // signature
            lh.appendLE(UInt16(20))            // version needed
            lh.appendLE(UInt16(0))             // flags
            lh.appendLE(UInt16(0))             // compression: stored
            lh.appendLE(dosTime)
            lh.appendLE(dosDate)
            lh.appendLE(crc)
            lh.appendLE(size)                  // compressed size
            lh.appendLE(size)                  // uncompressed size
            lh.appendLE(UInt16(nameBytes.count))
            lh.appendLE(UInt16(0))             // extra field length
            lh.append(nameBytes)
            archive.append(lh)
            archive.append(file.data)

            // Central directory entry
            var ce = Data()
            ce.appendLE(UInt32(0x02014b50))
            ce.appendLE(UInt16(20))            // version made by
            ce.appendLE(UInt16(20))            // version needed
            ce.appendLE(UInt16(0))             // flags
            ce.appendLE(UInt16(0))             // compression: stored
            ce.appendLE(dosTime)
            ce.appendLE(dosDate)
            ce.appendLE(crc)
            ce.appendLE(size)
            ce.appendLE(size)
            ce.appendLE(UInt16(nameBytes.count))
            ce.appendLE(UInt16(0))             // extra field length
            ce.appendLE(UInt16(0))             // file comment length
            ce.appendLE(UInt16(0))             // disk number start
            ce.appendLE(UInt16(0))             // internal attrs
            ce.appendLE(UInt32(0))             // external attrs
            ce.appendLE(offset)                // local header offset
            ce.append(nameBytes)
            cd.append(ce)
        }

        let cdOffset = UInt32(archive.count)
        let cdSize   = UInt32(cd.count)
        archive.append(cd)

        // End of central directory
        var eocd = Data()
        eocd.appendLE(UInt32(0x06054b50))
        eocd.appendLE(UInt16(0))               // disk number
        eocd.appendLE(UInt16(0))               // disk with CD start
        eocd.appendLE(UInt16(files.count))     // entries on this disk
        eocd.appendLE(UInt16(files.count))     // total entries
        eocd.appendLE(cdSize)
        eocd.appendLE(cdOffset)
        eocd.appendLE(UInt16(0))               // comment length
        archive.append(eocd)

        try archive.write(to: url)
    }

    // MARK: - CRC-32 (pure Swift, no external dependencies)

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var crc = UInt32(i)
        for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1 }
        return crc
    }

    private static func crc32(_ data: Data) -> UInt32 {
        ~data.reduce(~UInt32(0)) { crc, byte in
            (crc >> 8) ^ crcTable[Int((crc ^ UInt32(byte)) & 0xff)]
        }
    }

    // MARK: - DOS date/time

    private static func currentDosDateTime() -> (time: UInt16, date: UInt16) {
        let cal = Calendar.current
        let now = Date()
        let h  = UInt16(cal.component(.hour,   from: now))
        let m  = UInt16(cal.component(.minute, from: now))
        let s  = UInt16(cal.component(.second, from: now))
        let y  = UInt16(cal.component(.year,   from: now))
        let mo = UInt16(cal.component(.month,  from: now))
        let d  = UInt16(cal.component(.day,    from: now))
        return (
            time: (h << 11) | (m << 5) | (s >> 1),
            date: ((y - 1980) << 9) | (mo << 5) | d
        )
    }
}

// MARK: - Data LE helper

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }
}
