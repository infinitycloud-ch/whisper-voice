import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: TranscriptionManager
    @EnvironmentObject var uiState: UIStateModel
    @ObservedObject private var folderManager = FolderTreeManager.shared
    @State private var selectedTranscription: Transcription?
    @State private var selectedTranscriptions: Set<UUID> = []
    @State private var isMultiSelecting = false
    @State private var searchText = ""
    @State private var showChat = false
    @State private var showWorkspaceDashboard = false
    @State private var showSettingsMenu = false
    @State private var rightPanelTab: RightPanelTab = .commands

    enum RightPanelTab: String, CaseIterable {
        case commands = "Commands"
        case workspace = "Workspace"
        case chat = "Chat"

        var icon: String {
            switch self {
            case .commands: return "terminal"
            case .workspace: return "rectangle.stack.fill"
            case .chat: return "message"
            }
        }
    }
    @State private var isOrganizing = false
    @State private var showOrganizePreview = false
    @State private var organizationResult: OrganizationResult?
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.cyberpunk.rawValue
    
    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }
    
    var body: some View {
        ZStack {
            switch uiState.windowMode {
            case .compact:
                MicrophoneMinimalView()
            case .medium:
                mediumView
            case .full:
                normalView
            }
        }
        .overlay {
            // FloatingAIView seulement en mode full
            if uiState.windowMode == .full {
                FloatingAIView()
            }
        }
        .sheet(isPresented: $showWorkspaceDashboard) {
            WorkspaceDashboard(isPresented: $showWorkspaceDashboard)
                .environmentObject(manager)
        }
    }

    var normalView: some View {
        VStack(spacing: 0) {
            // Barre unique compacte : Onglets + Titre + Actions + Paramètres
            HStack(spacing: 12) {
                // 1. Logo/Titre
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11))
                        .foregroundColor(theme.accentColor)
                    Text("Transcriptions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.accentColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accentColor.opacity(0.15))
                .cornerRadius(6)

                // 2. Titre (intégré)
                Text("Whisper by Mr D")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.0))
                    .padding(.leading, 4)

                Spacer()

                // 3. Actions Contextuelles
                HStack(spacing: 6) {
                        // Selection/PRD Group
                        Button(action: {
                            if isMultiSelecting {
                                if !selectedTranscriptions.isEmpty {
                                    generatePRD()
                                } else {
                                    // Désactiver le mode sélection si aucune sélection
                                    isMultiSelecting = false
                                }
                            } else {
                                isMultiSelecting = true
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: isMultiSelecting ? "checkmark.circle.fill" : "doc.text")
                                    .font(.system(size: 11))
                                if !selectedTranscriptions.isEmpty {
                                    Text("\(selectedTranscriptions.count)")
                                        .font(.system(size: 10))
                                }
                            }
                            .foregroundColor(isMultiSelecting ? theme.recordColor : theme.secondaryTextColor)
                            .padding(4)
                            .background(isMultiSelecting ? theme.recordColor.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help(isMultiSelecting ? (selectedTranscriptions.isEmpty ? "Désactiver sélection" : "Générer PRD (\(selectedTranscriptions.count))") : "Mode Sélection")

                        Divider()
                            .frame(height: 12)

                        // Clear button
                        Button(action: {
                            manager.clearHistory()
                            selectedTranscription = nil
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(theme.recordColor.opacity(0.7))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(manager.transcriptions.isEmpty)
                }

                // 4. Boutons modes fenêtre
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        uiState.windowMode = .medium
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Mode liste seule (⌘⇧L)")
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        uiState.windowMode = .compact
                    }
                }) {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Mode micro (⌘⇧M)")
                .keyboardShortcut("m", modifiers: [.command, .shift])

                // 5. Menu Paramètres
                Menu {
                    // API Section
                    Section("API Transcription") {
                        Picker("Service", selection: $manager.selectedAPI) {
                            Text("Groq").tag("groq")
                            Text("OpenAI").tag("openai")
                        }
                    }

                    // Window Behavior
                    Section("Fenêtre") {
                        Toggle("Rester au premier plan", isOn: $manager.stayOnTop)
                        Toggle("Minimiser après enregistrement", isOn: $manager.minimizeAfterRecording)
                    }
                    
                    // Theme
                    Section("Apparence") {
                        Picker("Thème", selection: $currentTheme) {
                            Text("Cyberpunk").tag(AppTheme.cyberpunk.rawValue)
                            Text("Sombre").tag(AppTheme.dark.rawValue)
                            Text("Ardoise").tag(AppTheme.slate.rawValue)
                            Text("Clair").tag(AppTheme.light.rawValue)
                        }
                    }
                    
                    Divider()
                    
                    Button("Réglages avancés...") {
                        showSettingsMenu = true
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(6)
                        .background(theme.secondaryBackgroundColor)
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .popover(isPresented: $showSettingsMenu) {
                    SettingsView()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.secondaryBackgroundColor.opacity(0.5))
            .overlay(Rectangle().frame(height: 1).foregroundColor(theme.secondaryBackgroundColor), alignment: .bottom)

            // Contenu principal
            transcriptionsTabContent
        }
    }

    // MARK: - Mode Medium (liste seule, compact)
    var mediumView: some View {
        VStack(spacing: 0) {
            // Barre compacte
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.accentColor)
                Text("Whisper")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.0))

                Spacer()

                // Bouton mode full
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        uiState.windowMode = .full
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(3)
                }
                .buttonStyle(.plain)
                .help("Mode complet")

                // Bouton mode compact
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        uiState.windowMode = .compact
                    }
                }) {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(3)
                }
                .buttonStyle(.plain)
                .help("Mode micro")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.secondaryBackgroundColor.opacity(0.5))
            .overlay(Rectangle().frame(height: 1).foregroundColor(theme.secondaryBackgroundColor), alignment: .bottom)

            // Enregistreur compact
            RecorderHeaderView(theme: theme)
                .environmentObject(manager)

            // Liste des transcriptions (texte plus petit)
            TreeSidebarView(
                folderManager: folderManager,
                selectedTranscription: $selectedTranscription,
                selectedTranscriptions: $selectedTranscriptions,
                isMultiSelecting: $isMultiSelecting,
                theme: theme,
                compactMode: true
            )
            .environmentObject(manager)
        }
        .background(theme.backgroundColor)
        .overlay(alignment: .top) {
            if manager.copySuccessMessage != nil {
                Text(manager.copySuccessMessage!)
                    .font(.caption2)
                    .padding(6)
                    .background(Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 10)
            }
        }
        .sheet(item: $selectedTranscription) { transcription in
            TranscriptionModal(transcription: transcription)
                .environmentObject(manager)
        }
    }

    var transcriptionsTabContent: some View {
        // Interface avec volet redimensionnable (Header supprimé)
        NavigationSplitView {
            // Colonne GAUCHE : Enregistreur + Liste
            VStack(spacing: 0) {
                // En-tête d'enregistrement compact
                RecorderHeaderView(theme: theme)
                    .environmentObject(manager)
                
                // Liste des transcriptions
                transcriptionsList
            }
            .frame(minWidth: 320, idealWidth: 350)
            .navigationSplitViewColumnWidth(min: 320, ideal: 350)
        } detail: {
            // Colonne DROITE : Onglets
            VStack(spacing: 0) {
                // Tab bar
                HStack(spacing: 0) {
                    ForEach(RightPanelTab.allCases, id: \.self) { tab in
                        Button(action: { rightPanelTab = tab }) {
                            HStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(rightPanelTab == tab ? theme.accentColor : theme.secondaryTextColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(rightPanelTab == tab ? theme.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.secondaryBackgroundColor.opacity(0.3))

                // Content based on selected tab
                switch rightPanelTab {
                case .commands:
                    CommandLauncherView()
                        .background(theme.backgroundColor)
                case .workspace:
                    WorkspaceInlineView()
                        .environmentObject(manager)
                        .background(theme.backgroundColor)
                case .chat:
                    ChatView()
                        .environmentObject(manager)
                }
            }
            .frame(minWidth: 300, maxWidth: .infinity)
        }
        .background(theme.backgroundColor)
    }

    var transcriptionsTab: some View {
        VStack(spacing: 0) {
            // Custom title bar
            HStack {
                Text("Whisper by Mr D")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.0))
                    .padding(.leading)
                
                // Checkboxes organisées verticalement
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(isOn: $manager.stayOnTop) {
                        Text("Rester au premier plan")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .help("Garder la fenêtre au-dessus des autres")
                    .onChange(of: manager.stayOnTop) { newValue in
                        // Appliquer immédiatement le changement
                        if let window = NSApp.windows.first {
                            window.level = newValue ? .floating : .normal
                        }
                    }
                    
                    Toggle(isOn: $manager.minimizeAfterRecording) {
                        Text("Minimiser après")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .help("Minimiser la fenêtre après l'enregistrement")
                }
                
                Spacer()
                
                // Menu button for settings
                Button(action: {
                    showSettingsMenu.toggle()
                }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
                .help("Paramètres")
                .popover(isPresented: $showSettingsMenu) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Paramètres")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        // API selector
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API")
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor)
                            Picker("", selection: $manager.selectedAPI) {
                                Text("Groq").tag("groq")
                                Text("OpenAI").tag("openai")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                        
                        // Theme selector
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Thème")
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor)
                            Picker("", selection: $currentTheme) {
                                Text("🌆").tag(AppTheme.cyberpunk.rawValue)
                                Text("🌙").tag(AppTheme.dark.rawValue)
                                Text("☀️").tag(AppTheme.light.rawValue)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                                                        }
                                                        Divider()
                                                        Text("Autres paramètres à venir...").font(.caption).foregroundColor(theme.secondaryTextColor)
                                                    }
                    .padding()
                    .frame(width: 180)
                    .background(theme.secondaryBackgroundColor)
                }
                
                // Selection mode button
                Button(action: {
                    isMultiSelecting.toggle()
                    if !isMultiSelecting {
                        selectedTranscriptions.removeAll()
                    }
                }) {
                    Image(systemName: isMultiSelecting ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundColor(isMultiSelecting ? theme.recordColor : theme.accentColor)
                }
                .buttonStyle(.plain)
                .help("Mode sélection multiple")
                
                // Generate PRD button - Toujours visible avec état
                Button(action: {
                    if isMultiSelecting && !selectedTranscriptions.isEmpty {
                        generatePRD()
                    } else if !isMultiSelecting {
                        // Activer le mode sélection si pas actif
                        isMultiSelecting = true
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                        if !selectedTranscriptions.isEmpty {
                            Text("PRD (\(selectedTranscriptions.count))")
                                .font(.caption)
                        } else {
                            Text("PRD")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(!selectedTranscriptions.isEmpty ? .white : theme.textColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(!selectedTranscriptions.isEmpty ? theme.recordColor : theme.secondaryBackgroundColor)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(isMultiSelecting ? 
                      "Sélectionnez des transcriptions puis cliquez pour générer un PRD" : 
                      "Cliquez pour activer le mode sélection PRD")
                
                // AI Organize button
                Button(action: {
                    organizeWithAI()
                }) {
                    HStack(spacing: 3) {
                        if isOrganizing {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 12))
                        }
                        Text(isOrganizing ? "Analyse..." : "Organiser")
                            .font(.caption)
                    }
                    .foregroundColor(isOrganizing ? theme.recordColor : theme.accentColor)
                }
                .buttonStyle(.plain)
                .help("Organiser automatiquement avec l'IA")
                .disabled(isOrganizing || manager.transcriptions.isEmpty)
                
                // Chat button
                Button(action: {
                    showChat.toggle()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 12))
                        Text("Chat")
                            .font(.caption)
                    }
                    .foregroundColor(showChat ? theme.recordColor : theme.accentColor)
                }
                .buttonStyle(.plain)
                .help("Mode Chat Speech-to-Speech")
                
                // Clear button
                Button(action: {
                    manager.clearHistory()
                    selectedTranscription = nil
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(theme.recordColor)
                }
                .buttonStyle(.plain)
                .disabled(manager.transcriptions.isEmpty)
                .padding(.trailing)
            }
            .padding(.vertical, 8)
            .background(theme.secondaryBackgroundColor)
            
            // Mode normal avec NavigationSplitView
            NavigationSplitView {
                transcriptionsList
                    .navigationTitle("")
                    .scrollContentBackground(.hidden)
                    .background(theme.backgroundColor)
            } detail: {
                // Afficher ChatView ou split view selon l'état
                Group {
                    if showChat {
                        ChatView()
                            .environmentObject(manager)
                    } else {
                        // Split view vertical avec transcription en haut et détail en bas
                        VSplitView {
                            // Panneau du haut : transcription actuelle/enregistrement
                            mainView
                                .frame(minHeight: 200)
                            
                            // Panneau du bas : détail de la transcription sélectionnée
                            if let transcription = selectedTranscription {
                                VStack(alignment: .leading, spacing: 0) {
                                    // En-tête avec bouton fermer
                                    HStack {
                                        Text("Détail de la transcription")
                                            .font(.headline)
                                            .foregroundColor(theme.textColor)
                                        Spacer()
                                        Button(action: {
                                            selectedTranscription = nil
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(theme.secondaryTextColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(theme.secondaryBackgroundColor.opacity(0.5))
                                    
                                    // Contenu de la transcription
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text(transcription.text)
                                                .font(.title3)
                                                .foregroundColor(theme.textColor)
                                                .textSelection(.enabled)
                                                .padding()
                                            
                                            HStack {
                                                Label(transcription.formattedDate, systemImage: "calendar")
                                                    .font(.caption)
                                                    .foregroundColor(theme.secondaryTextColor)
                                                
                                                Spacer()
                                                
                                                Label(transcription.formattedDuration, systemImage: "clock")
                                                    .font(.caption)
                                                    .foregroundColor(theme.secondaryTextColor)
                                            }
                                            .padding(.horizontal)
                                            .padding(.bottom)
                                            
                                            // Boutons d'action
                                            HStack {
                                                Button(action: {
                                                    manager.copyToClipboard(transcription.text, showSuccess: true)
                                                }) {
                                                    Label("Copier", systemImage: "doc.on.doc")
                                                        .font(.caption)
                                                }
                                                .buttonStyle(.bordered)
                                                
                                                Button(action: {
                                                    manager.deleteTranscription(transcription)
                                                    selectedTranscription = nil
                                                }) {
                                                    Label("Supprimer", systemImage: "trash")
                                                        .font(.caption)
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(.bordered)
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                                .frame(minHeight: 150)
                                .background(theme.backgroundColor)
                            } else {
                                // Message quand aucune transcription n'est sélectionnée
                                VStack {
                                    Text("Sélectionnez une transcription dans la sidebar pour voir les détails")
                                        .font(.caption)
                                        .foregroundColor(theme.secondaryTextColor)
                                }
                                .frame(minHeight: 150)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(theme.secondaryBackgroundColor.opacity(0.2))
                            }
                        }
                    }
                }
            }
            .background(theme.backgroundColor)
            .searchable(text: $searchText, prompt: Text("Rechercher").font(.caption))
        }
        .background(theme.backgroundColor)
        .overlay {
            if isOrganizing {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Analyse en cours...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("L'IA analyse vos \(manager.transcriptions.count) transcriptions")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Cela peut prendre quelques secondes...")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                }
            }
        }
        .sheet(isPresented: $showOrganizePreview) {
            if let result = organizationResult {
                OrganizePreviewView(result: result, theme: theme, folderManager: folderManager, isPresented: $showOrganizePreview)
                    .environmentObject(manager)
            }
        }
        .alert("Erreur", isPresented: .constant(manager.errorMessage != nil)) {
            Button("OK") {
                manager.errorMessage = nil
            }
        } message: {
            Text(manager.errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if manager.copySuccessMessage != nil {
                Text(manager.copySuccessMessage!)
                    .font(.caption)
                    .padding(8)
                    .background(Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 10)
            }
        }
    }

    private var transcriptionsList: some View {
        TreeSidebarView(
            folderManager: folderManager, 
            selectedTranscription: $selectedTranscription,
            selectedTranscriptions: $selectedTranscriptions,
            isMultiSelecting: $isMultiSelecting,
            theme: theme
        )
        .environmentObject(manager)
    }
    
    private var mainView: some View {
        Group {
            if let selectedTranscription = selectedTranscription {
                // Split vertical : enregistrement en haut, détail en bas
                VSplitView {
                    recordingInterface
                        .frame(minHeight: 200, idealHeight: 300)

                    TranscriptionDetailView(transcription: selectedTranscription)
                        .environmentObject(manager)
                        .frame(minHeight: 200)
                }
            } else {
                // Juste l'interface d'enregistrement
                recordingInterface
            }
        }
    }

    private var recordingInterface: some View {
        VStack(spacing: 0) {
            // Large record button bar
            Button(action: {
                selectedTranscription = nil  // Hide detail panel when recording starts
                manager.toggleRecording()
            }) {
                HStack {
                    Spacer()
                    Image(systemName: manager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 18))
                    Text(manager.isRecording ? "Arrêter l'enregistrement" : "Démarrer l'enregistrement")
                        .font(.system(size: 14))
                    if manager.isRecording {
                        Text("• \(formatTime(manager.recordingTime))")
                            .font(.system(size: 14))
                            .monospacedDigit()
                        Text("• \(manager.currentInputDevice)")
                            .font(.system(size: 12))
                            .opacity(0.9)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(manager.isRecording ? theme.recordColor.opacity(0.9) : theme.accentColor.opacity(0.9))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(manager.isProcessing)
            
            ScrollView {
                VStack(spacing: 20) {
                    if manager.isRecording {
                        VStack(spacing: 15) {
                            // Live waveform - full width
                            RealTimeWaveform(audioLevels: manager.audioLevels, theme: theme)
                                .frame(height: 60)
                            
                            Text(formatTime(manager.recordingTime))
                                .font(.system(size: 48, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(theme.recordColor)
                            
                            // Show live transcription indicator and preview
                            if manager.isLiveTranscribing {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Transcription live...")
                                        .font(.caption)
                                        .foregroundColor(theme.accentColor)
                                }
                                .padding(.top, 8)
                            }

                            // Show live preview text during recording
                            if !manager.livePreviewText.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "text.bubble")
                                            .font(.caption)
                                        Text("Aperçu")
                                            .font(.caption)
                                    }
                                    .foregroundColor(theme.secondaryTextColor)

                                    Text(manager.livePreviewText)
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.textColor)
                                        .lineLimit(3)
                                        .padding(10)
                                        .background(theme.secondaryBackgroundColor)
                                        .cornerRadius(8)
                                }
                                .frame(maxWidth: 400)
                                .padding(.top, 12)
                            } else if manager.liveTranscription == "Transcription en cours..." {
                                Text("Transcription en cours...")
                                    .font(.title3)
                                    .foregroundColor(theme.secondaryTextColor)
                                    .padding()
                            }
                        }
                        .transition(.opacity)
                    } else if manager.isProcessing {
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Transcription en cours...")
                                .font(.headline)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .padding()
                    } else if !manager.liveTranscription.isEmpty && manager.liveTranscription != "Transcription en cours..." {
                        // Keep last transcription visible
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Dernière transcription:")
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryTextColor)
                                
                                Spacer()
                                
                                // Boutons d'action
                                HStack(spacing: 8) {
                                    if manager.isEditingTranscription {
                                        Button("Sauvegarder") {
                                            manager.updateLastTranscription(manager.editedTranscription)
                                            manager.isEditingTranscription = false
                                            manager.copyToClipboard(manager.editedTranscription, showSuccess: true)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        
                                        Button("Annuler") {
                                            manager.editedTranscription = manager.liveTranscription
                                            manager.isEditingTranscription = false
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    } else {
                                        // AI Optimize button
                                        if manager.isOptimizing {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .frame(width: 16, height: 16)
                                        } else if manager.originalTextBeforeOptimization != nil {
                                            // Undo button
                                            Button(action: {
                                                manager.undoOptimization()
                                            }) {
                                                Image(systemName: "arrow.uturn.backward")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.orange)
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Annuler l'optimisation")
                                        } else {
                                            Button(action: {
                                                manager.optimizeLiveTranscription()
                                            }) {
                                                Image(systemName: "wand.and.stars")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(theme.accentColor)
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Optimiser avec AI")
                                        }

                                        Button(action: {
                                            manager.isEditingTranscription = true
                                        }) {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 12))
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Modifier le texte")

                                        Button(action: {
                                            // Le prochain enregistrement sera fusionné
                                            manager.shouldAppendNextRecording = true
                                            selectedTranscription = nil  // Hide detail panel when recording starts
                                            manager.toggleRecording()
                                        }) {
                                            Image(systemName: manager.shouldAppendNextRecording ? "plus.circle.fill" : "plus.circle")
                                                .font(.system(size: 12))
                                                .foregroundColor(manager.shouldAppendNextRecording ? theme.accentColor : theme.textColor)
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Ajouter au texte (nouvel enregistrement)")
                                    }
                                }
                                
                                if manager.autoPasteCountdown > 0 {
                                    Text("Collage dans \(manager.autoPasteCountdown)s...")
                                        .font(.caption)
                                        .foregroundColor(theme.accentColor)
                                        .fontWeight(.bold)
                                }
                            }
                            
                            ScrollView {
                                if manager.isEditingTranscription {
                                    TextEditor(text: $manager.editedTranscription)
                                        .font(.title2)
                                        .foregroundColor(theme.textColor)
                                        .scrollContentBackground(.hidden)
                                        .padding(8)
                                        .background(theme.secondaryBackgroundColor.opacity(0.5))
                                        .cornerRadius(8)
                                } else {
                                    Text(manager.liveTranscription)
                                        .font(.title2)
                                        .foregroundColor(theme.textColor)
                                        .textSelection(.enabled)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxHeight: 300)
                            .background(theme.secondaryBackgroundColor.opacity(0.3))
                            .cornerRadius(10)
                        }
                        .padding()
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 60))
                                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                            
                            Text("Prêt à enregistrer")
                                .font(.title2)
                                .foregroundColor(theme.secondaryTextColor)
                            
                            Text("⌥X pour enregistrer")
                                .font(.headline)
                                .foregroundColor(theme.accentColor)
                        }
                        .padding(.top, 50)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(theme.backgroundColor)
        }
    }
    
    private var recordButton: some View {
        Button(action: {
            selectedTranscription = nil  // Hide detail panel when recording starts
            manager.toggleRecording()
        }) {
            HStack {
                Image(systemName: manager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                
                Text(manager.isRecording ? "Arrêter" : "Enregistrer")
                    .fontWeight(.semibold)
                
                if manager.isRecording {
                    Text("• REC")
                        .font(.caption)
                        .foregroundColor(theme.recordColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(manager.isRecording ? theme.recordColor.opacity(0.2) : theme.accentColor.opacity(0.2))
            .foregroundColor(manager.isRecording ? theme.recordColor : theme.accentColor)
            .cornerRadius(25)
        }
        .buttonStyle(.plain)
        .disabled(manager.isProcessing)
        .keyboardShortcut("x", modifiers: [.option])
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func organizeWithAI() {
        isOrganizing = true
        
        Task {
            do {
                print("🤖 Début de l'organisation avec IA...")
                print("📊 Nombre de transcriptions à analyser: \(manager.transcriptions.count)")
                
                let organizer = AIOrganizer()
                let result = try await organizer.organizeTranscriptions(manager.transcriptions)
                
                print("✅ Organisation terminée avec succès")
                
                await MainActor.run {
                    self.organizationResult = result
                    self.showOrganizePreview = true
                    self.isOrganizing = false
                }
            } catch {
                await MainActor.run {
                    self.isOrganizing = false
                    
                    // Afficher l'erreur à l'utilisateur
                    let errorMessage: String
                    switch error {
                    case OrganizerError.missingAPIKey:
                        errorMessage = "Clé API OpenAI manquante. Configurez-la dans les paramètres."
                    case OrganizerError.noTranscriptions:
                        errorMessage = "Aucune transcription à organiser."
                    case OrganizerError.apiError:
                        errorMessage = "Erreur de l'API OpenAI. Vérifiez votre connexion."
                    case OrganizerError.invalidResponse:
                        errorMessage = "Réponse invalide de l'IA. Réessayez."
                    default:
                        errorMessage = "Erreur: \(error.localizedDescription)"
                    }
                    
                    print("❌ Erreur d'organisation: \(errorMessage)")
                    manager.errorMessage = errorMessage
                }
            }
        }
    }
    
    private func generatePRD() {
        Task {
            await PRDGeneratorService.shared.generatePRD(
                from: getSelectedTranscriptions(),
                manager: manager
            )
            // Réinitialiser la sélection après génération
            selectedTranscriptions.removeAll()
            isMultiSelecting = false
        }
    }
    
    private func getSelectedTranscriptions() -> [Transcription] {
        return manager.transcriptions.filter { selectedTranscriptions.contains($0.id) }
    }
}

struct TranscriptionRow: View {
    let transcription: Transcription
    let theme: AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(transcription.text)
                .lineLimit(2)
                .font(.body)
                .foregroundColor(theme.textColor)
            
            HStack {
                Text(transcription.formattedDate)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                
                Spacer()
                
                Text(transcription.formattedDuration)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }
        }
        .padding(.vertical, 4)
    }
}