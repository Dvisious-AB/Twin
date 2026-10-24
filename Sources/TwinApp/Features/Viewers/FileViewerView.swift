import AVKit
import PDFKit
import SwiftUI
import TwinCore

/// Built-in viewer (F3, Total Commander style): shows known file
/// types inside Twin instead of bouncing to another app.
/// Text/code read-only with line numbers, Markdown rendered with
/// a Raw toggle, images zoomable, PDF via PDFKit, media via
/// AVPlayer, anything else as info + hex preview. Editing is one
/// click away for text-like files.
struct FileViewerView: View {
    let url: URL
    /// Jump from viewing to the built-in editor (text-like files).
    var onEdit: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var text: String?
    @State private var loadError: String?
    @State private var showRawMarkdown = false
    @State private var imageScale: CGFloat = 1

    private var kind: FileKind { FileTypeRegistry.kind(for: url) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 680, minHeight: 480)
        .onAppear(perform: loadTextIfNeeded)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye")
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent).font(.headline).lineLimit(1)
                Text("\(kind.label) · \(url.path)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if kind == .markdown {
                Picker("Markdown", selection: $showRawMarkdown) {
                    Text("Rendered").tag(false)
                    Text("Raw").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            if kind.isTextEditable {
                Button("Edit") { onEdit() }
                    .help("Open in Twin Editor (F4)")
            }
            Button("Open in macOS App") { NSWorkspace.shared.open(url) }
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .text, .code:
            textContent(numbered: true)
        case .markdown:
            if showRawMarkdown { textContent(numbered: true) } else { markdownContent }
        case .image:
            imageContent
        case .pdf:
            PDFKitView(url: url)
        case .audio, .video:
            VideoPlayer(player: AVPlayer(url: url))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .archive:
            ContentUnavailableView(
                "Archive", systemImage: "archivebox",
                description: Text("Use Unpack in the function bar to extract this archive."))
        case .data:
            dataContent
        }
    }

    // MARK: - Text / code

    private func loadTextIfNeeded() {
        guard kind.isTextEditable, text == nil, loadError == nil else { return }
        do {
            text = try TextFileService.loadText(at: url)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func textContent(numbered: Bool) -> some View {
        Group {
            if let loadError {
                ContentUnavailableView("Can't View as Text", systemImage: "doc.badge.gearshape",
                                       description: Text(loadError))
            } else if let text {
                ScrollView([.vertical, .horizontal]) {
                    HStack(alignment: .top, spacing: 12) {
                        if numbered {
                            Text(lineNumbers(for: text))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.trailing)
                        }
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func lineNumbers(for text: String) -> String {
        let count = max(text.components(separatedBy: "\n").count, 1)
        return (1...count).map(String.init).joined(separator: "\n")
    }

    // MARK: - Markdown (rendered per block; inline styles via AttributedString)

    private var markdownContent: some View {
        Group {
            if let loadError {
                ContentUnavailableView("Can't View Markdown", systemImage: "doc.badge.gearshape",
                                       description: Text(loadError))
            } else if let text {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(markdownBlocks(text).enumerated()), id: \.offset) { _, block in
                            markdownBlock(block)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private enum MarkdownBlock {
        case heading(String, Int)
        case paragraph(String)
        case code(String)
        case listItem(String)
    }

    private func markdownBlocks(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var codeBuffer: [String]?
        for line in source.components(separatedBy: "\n") {
            if line.hasPrefix("```") {
                if let buffer = codeBuffer {
                    blocks.append(.code(buffer.joined(separator: "\n")))
                    codeBuffer = nil
                } else { codeBuffer = [] }
                continue
            }
            if codeBuffer != nil { codeBuffer?.append(line); continue }
            let hashes = line.prefix(while: { $0 == "#" }).count
            if hashes > 0, hashes <= 6, line.dropFirst(hashes).hasPrefix(" ") {
                blocks.append(.heading(String(line.dropFirst(hashes + 1)), hashes))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(.listItem(String(line.dropFirst(2))))
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(.paragraph(line))
            }
        }
        if let buffer = codeBuffer { blocks.append(.code(buffer.joined(separator: "\n"))) }
        return blocks
    }

    @ViewBuilder
    private func markdownBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let title, let level):
            Text(inlineMarkdown(title))
                .font(level == 1 ? .title2.bold() : .headline)
                .padding(.top, level == 1 ? 6 : 3)
        case .paragraph(let line):
            Text(inlineMarkdown(line)).textSelection(.enabled)
        case .code(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .listItem(let item):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                Text(inlineMarkdown(item))
            }
        }
    }

    private func inlineMarkdown(_ source: String) -> AttributedString {
        (try? AttributedString(markdown: source)) ?? AttributedString(source)
    }

    // MARK: - Image

    private var imageContent: some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                VStack(spacing: 0) {
                    ScrollView([.vertical, .horizontal]) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: max(image.size.width * imageScale, 80),
                                   height: max(image.size.height * imageScale, 80))
                            .padding(12)
                    }
                    HStack(spacing: 10) {
                        Text("\(Int(image.size.width)) × \(Int(image.size.height)) px")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("−") { imageScale = max(imageScale / 1.25, 0.1) }
                        Text("\(Int(imageScale * 100))%").font(.caption).monospacedDigit()
                        Button("+") { imageScale = min(imageScale * 1.25, 8) }
                        Button("Reset") { imageScale = 1 }
                    }
                    .padding(8)
                }
            } else {
                ContentUnavailableView("Can't Load Image", systemImage: "photo.badge.exclamationmark",
                                       description: Text("The format may need an external app — use Open With."))
            }
        }
    }

    // MARK: - Binary / data

    private var dataContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            let info = fileInfo
            Text(info).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Divider()
            Text("First bytes (hex)")
                .font(.caption.bold()).foregroundStyle(.secondary)
            ScrollView {
                Text(hexDump)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
    }

    private var fileInfo: String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .typeIdentifierKey])
        let size = SizeFormatting.string(forBytes: Int64(values?.fileSize ?? 0))
        let type = values?.typeIdentifier ?? "unknown"
        let modified = values?.contentModificationDate
            .map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—"
        return "Size: \(size)\nType (UTI): \(type)\nModified: \(modified)"
    }

    private var hexDump: String {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return "Could not read the file."
        }
        let bytes = [UInt8](data.prefix(512))
        var lines: [String] = []
        for offset in stride(from: 0, to: bytes.count, by: 16) {
            let chunk = bytes[offset..<min(offset + 16, bytes.count)]
            let hex = chunk.map { String(format: "%02x", $0) }.joined(separator: " ")
            let ascii = chunk.map { (32...126).contains($0) ? String(UnicodeScalar($0)) : "·" }.joined()
            lines.append(String(format: "%08x  %-47@  %@", offset, hex as NSString, ascii))
        }
        return lines.joined(separator: "\n")
    }
}

/// PDFKit in SwiftUI.
private struct PDFKitView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
