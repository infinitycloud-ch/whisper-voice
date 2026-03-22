import SwiftUI

struct PRDDetailView: View {
    let transcription: Transcription
    @EnvironmentObject var manager: TranscriptionManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isExporting = false
    
    var theme: AppTheme {
        colorScheme == .dark ? .dark : .light
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    if let title = transcription.prdTitle {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textColor)
                    }
                    
                    HStack {
                        Label("PRD généré", systemImage: "doc.text.fill")
                            .font(.caption)
                            .foregroundColor(theme.accentColor)
                        
                        Spacer()
                        
                        Text(transcription.formattedDate)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                }
                .padding()
                .background(theme.secondaryBackgroundColor.opacity(0.3))
                .cornerRadius(10)
                
                // Content
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(formatPRDContent(transcription.text), id: \.self) { section in
                        PRDSectionView(section: section, theme: theme)
                    }
                }
                .padding()
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: {
                        copyToClipboard()
                    }) {
                        Label("Copier", systemImage: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.accentColor)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        isExporting = true
                    }) {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.recordColor)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .background(theme.backgroundColor)
        #if os(macOS)
        .fileExporter(
            isPresented: $isExporting,
            document: PRDDocument(content: transcription.text, title: transcription.prdTitle ?? "PRD"),
            contentType: .plainText,
            defaultFilename: "\(transcription.prdTitle ?? "PRD").md"
        ) { result in
            switch result {
            case .success(let url):
                print("PRD exporté: \(url)")
            case .failure(let error):
                print("Erreur export: \(error)")
            }
        }
        #endif
    }
    
    private func formatPRDContent(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .filter { !$0.isEmpty }
    }
    
    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcription.text, forType: .string)
        #else
        UIPasteboard.general.string = transcription.text
        #endif
        
        manager.copySuccessMessage = "PRD copié!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            manager.copySuccessMessage = nil
        }
    }
}

struct PRDSectionView: View {
    let section: String
    let theme: AppTheme
    
    var isTitle: Bool {
        section.hasPrefix("#")
    }
    
    var isBulletPoint: Bool {
        section.trimmingCharacters(in: .whitespaces).hasPrefix("-")
    }
    
    var body: some View {
        if isTitle {
            Text(section.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces))
                .font(section.hasPrefix("##") ? .title2 : .title)
                .fontWeight(.semibold)
                .foregroundColor(theme.textColor)
                .padding(.top, section.hasPrefix("##") ? 8 : 16)
        } else if isBulletPoint {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.components(separatedBy: "\n").filter { !$0.isEmpty }, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(theme.accentColor)
                        Text(line.replacingOccurrences(of: "- ", with: "").trimmingCharacters(in: .whitespaces))
                            .foregroundColor(theme.textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 16)
        } else {
            Text(section)
                .foregroundColor(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if os(macOS)
import UniformTypeIdentifiers

struct PRDDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    var content: String
    var title: String
    
    init(content: String, title: String) {
        self.content = content
        self.title = title
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = string
        self.title = "PRD"
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
#endif