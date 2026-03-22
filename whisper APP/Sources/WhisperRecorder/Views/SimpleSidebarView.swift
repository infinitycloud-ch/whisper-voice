import SwiftUI

struct SimpleSidebarView: View {
    @EnvironmentObject var manager: TranscriptionManager
    @Binding var selectedTranscription: Transcription?
    @State private var searchText = ""
    let theme: AppTheme
    
    var filteredTranscriptions: [Transcription] {
        if searchText.isEmpty {
            return manager.transcriptions
        } else {
            return manager.transcriptions.filter {
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barre de recherche
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondaryTextColor)
                TextField("Rechercher", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(theme.secondaryBackgroundColor.opacity(0.3))
            
            // Liste des transcriptions
            List(filteredTranscriptions, selection: $selectedTranscription) { transcription in
                VStack(alignment: .leading, spacing: 2) {
                    Text(transcription.text)
                        .lineLimit(2)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textColor)
                    
                    HStack {
                        Text(transcription.formattedDate)
                            .font(.caption2)
                            .foregroundColor(theme.secondaryTextColor)
                        
                        Spacer()
                        
                        Text(transcription.formattedDuration)
                            .font(.caption2)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTranscription = transcription
                }
            }
            .listStyle(.sidebar)
        }
    }
}