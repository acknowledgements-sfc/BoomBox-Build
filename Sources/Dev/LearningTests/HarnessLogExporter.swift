#if DEBUG
import UIKit

enum HarnessLogExporter {
    static func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    static func markdownTable(rows: [String], headers: [String]) -> String {
        var lines: [String] = []
        lines.append("| " + headers.joined(separator: " | ") + " |")
        lines.append("| " + headers.map { _ in "---" }.joined(separator: " | ") + " |")
        for row in rows {
            lines.append("| " + row + " |")
        }
        return lines.joined(separator: "\n")
    }
}
#endif
