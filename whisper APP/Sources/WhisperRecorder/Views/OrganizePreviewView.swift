import SwiftUI

struct OrganizePreviewView: View {
    let result: OrganizationResult
    let theme: AppTheme
    let folderManager: FolderTreeManager
    @Binding var isPresented: Bool
    @EnvironmentObject var manager: TranscriptionManager
    @State private var isApplying = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(theme.accentColor)
                
                VStack(alignment: .leading) {
                    Text("Organisation proposée")
                        .font(.headline)
                        .foregroundColor(theme.textColor)
                    
                    Text(result.summary)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(theme.secondaryBackgroundColor)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Dossiers suggérés
                    ForEach(result.folders, id: \.name) { folder in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(theme.accentColor)
                                
                                Text(folder.name)
                                    .font(.headline)
                                    .foregroundColor(theme.textColor)
                                
                                Text("(\(folder.transcriptions.count))")
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryTextColor)
                            }
                            
                            Text(folder.description)
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor)
                            
                            // Aperçu des transcriptions
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(folder.transcriptions.prefix(3), id: \.transcription.id) { classification in
                                    HStack {
                                        Circle()
                                            .fill(confidenceColor(classification.confidence))
                                            .frame(width: 8, height: 8)
                                        
                                        Text(String(classification.transcription.text.prefix(50)) + "...")
                                            .font(.caption)
                                            .foregroundColor(theme.textColor)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(classification.confidence * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(theme.secondaryTextColor)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(theme.secondaryBackgroundColor.opacity(0.3))
                                    .cornerRadius(4)
                                }
                                
                                if folder.transcriptions.count > 3 {
                                    Text("+ \(folder.transcriptions.count - 3) autre(s)")
                                        .font(.caption2)
                                        .foregroundColor(theme.secondaryTextColor)
                                        .padding(.leading, 20)
                                }
                            }
                        }
                        .padding()
                        .background(theme.secondaryBackgroundColor.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    // Non classées
                    if !result.unclassified.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "questionmark.folder")
                                    .foregroundColor(theme.secondaryTextColor)
                                
                                Text("Non classé")
                                    .font(.headline)
                                    .foregroundColor(theme.textColor)
                                
                                Text("(\(result.unclassified.count))")
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryTextColor)
                            }
                            
                            Text("Transcriptions avec confiance insuffisante")
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(result.unclassified.prefix(3)) { transcription in
                                    Text("• " + String(transcription.text.prefix(50)) + "...")
                                        .font(.caption)
                                        .foregroundColor(theme.secondaryTextColor)
                                        .lineLimit(1)
                                        .padding(.leading, 8)
                                }
                                
                                if result.unclassified.count > 3 {
                                    Text("+ \(result.unclassified.count - 3) autre(s)")
                                        .font(.caption2)
                                        .foregroundColor(theme.secondaryTextColor)
                                        .padding(.leading, 20)
                                }
                            }
                        }
                        .padding()
                        .background(theme.secondaryBackgroundColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            // Actions
            HStack {
                Button("Annuler") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    applyOrganization()
                }) {
                    HStack {
                        if isApplying {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Appliquer l'organisation")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isApplying)
            }
            .padding()
            .background(theme.secondaryBackgroundColor)
        }
        .frame(width: 600, height: 500)
        .background(theme.backgroundColor)
        .cornerRadius(12)
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func applyOrganization() {
        isApplying = true
        
        print("📁 Application de l'organisation...")
        print("📁 Nombre de dossiers à créer: \(result.folders.count)")
        
        // Appliquer l'organisation
        let organizer = AIOrganizer()
        organizer.applyOrganization(result, folderManager: folderManager)
        
        print("✅ Organisation appliquée avec succès")
        
        // Fermer après application
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
            isApplying = false
        }
    }
}