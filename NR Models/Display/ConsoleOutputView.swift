import SwiftUI

struct ConsoleOutputView: View {
    let lines: [String]

    var body: some View {
        Group {
            if lines.isEmpty {
                Text("No output.").foregroundStyle(.secondary)
            } else {
                Text(verbatim: lines.joined(separator: "\n"))
                    .textSelection(.enabled)
            }
        }
        .font(.system(.body, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("lua-console-output")
    }
}
