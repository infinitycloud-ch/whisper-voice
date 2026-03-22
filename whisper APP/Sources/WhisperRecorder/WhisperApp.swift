import SwiftUI
import AppKit
import Combine

@main
struct WhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var transcriptionManager = TranscriptionManager.shared
    @StateObject private var uiState = UIStateModel()
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.cyberpunk.rawValue
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transcriptionManager)
                .environmentObject(uiState)
                .frame(
                    minWidth: uiState.windowMode == .compact ? 200 : (uiState.windowMode == .medium ? 360 : 900),
                    idealWidth: uiState.windowMode == .compact ? 200 : (uiState.windowMode == .medium ? 400 : 1100),
                    maxWidth: uiState.windowMode == .compact ? 200 : (uiState.windowMode == .medium ? 500 : .infinity),
                    minHeight: uiState.windowMode == .compact ? 180 : (uiState.windowMode == .medium ? 500 : 780),
                    idealHeight: uiState.windowMode == .compact ? 220 : (uiState.windowMode == .medium ? 700 : 800),
                    maxHeight: uiState.windowMode == .compact ? 250 : .infinity
                )
                .preferredColorScheme(currentTheme == "Clair" ? .light : .dark)
                .onReceive(uiState.$windowMode) { mode in
                    // Redimensionner la fenêtre quand on change de mode
                    DispatchQueue.main.async {
                        if let window = NSApp.windows.first {
                            let currentFrame = window.frame

                            switch mode {
                            case .compact:
                                window.setContentSize(NSSize(width: 200, height: 220))
                            case .medium:
                                window.setContentSize(NSSize(width: 400, height: 700))
                            case .full:
                                window.setContentSize(NSSize(width: 1100, height: 800))
                            }

                            // Repositionner en gardant le coin supérieur gauche au même endroit
                            let newFrame = window.frame
                            window.setFrameOrigin(NSPoint(
                                x: currentFrame.origin.x,
                                y: currentFrame.origin.y + (currentFrame.height - newFrame.height)
                            ))
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
        
        Settings {
            SettingsView()
                .environmentObject(transcriptionManager)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        TranscriptionManager.shared.setupHotkey()

        // Setup Menu Bar
        setupMenuBar()

        // S'assurer que la fenêtre principale est visible au lancement
        if let window = NSApp.windows.first {
            window.setContentSize(NSSize(width: 1100, height: 800))
            window.minSize = NSSize(width: 900, height: 780)
            window.makeKeyAndOrderFront(nil)
            window.center()
        }
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Whisper")
            button.image?.isTemplate = true
        }

        updateMenu()

        // Observer l'état d'enregistrement via Combine (réactif, pas de polling)
        TranscriptionManager.shared.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        let isRecording = TranscriptionManager.shared.isRecording
        let iconName = isRecording ? "record.circle.fill" : "waveform.circle"

        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Whisper")
        button.image?.isTemplate = !isRecording // Rouge si recording

        if isRecording {
            button.contentTintColor = .systemRed
        } else {
            button.contentTintColor = nil
        }
    }

    private func updateMenu() {
        let menu = NSMenu()

        // Afficher/Masquer fenêtre
        let windowItem = NSMenuItem(
            title: isWindowVisible() ? "Masquer la fenêtre" : "Afficher la fenêtre",
            action: #selector(toggleWindow),
            keyEquivalent: ""
        )
        windowItem.target = self
        menu.addItem(windowItem)

        menu.addItem(NSMenuItem.separator())

        // Dernière transcription (preview)
        let lastTranscription = TranscriptionManager.shared.transcriptions.first
        if let transcription = lastTranscription {
            let previewText = String(transcription.text.prefix(50)) + (transcription.text.count > 50 ? "..." : "")
            let previewItem = NSMenuItem(title: "📝 " + previewText, action: #selector(copyLastTranscription), keyEquivalent: "")
            previewItem.target = self
            menu.addItem(previewItem)
        } else {
            let noTranscription = NSMenuItem(title: "Aucune transcription", action: nil, keyEquivalent: "")
            noTranscription.isEnabled = false
            menu.addItem(noTranscription)
        }

        menu.addItem(NSMenuItem.separator())

        // Démarrer/Arrêter enregistrement
        let isRecording = TranscriptionManager.shared.isRecording
        let recordItem = NSMenuItem(
            title: isRecording ? "⏹ Arrêter l'enregistrement" : "🎙 Démarrer l'enregistrement",
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        recordItem.target = self
        menu.addItem(recordItem)

        menu.addItem(NSMenuItem.separator())

        // Préférences
        let prefsItem = NSMenuItem(title: "Préférences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // Quitter
        let quitItem = NSMenuItem(title: "Quitter Whisper", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    private func isWindowVisible() -> Bool {
        if let window = NSApp.windows.first(where: { $0.className.contains("AppKit") == false }) {
            return window.isVisible
        }
        return false
    }

    @objc private func toggleWindow() {
        if let window = NSApp.windows.first(where: { $0.className.contains("AppKit") == false }) {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    @objc private func copyLastTranscription() {
        if let transcription = TranscriptionManager.shared.transcriptions.first {
            TranscriptionManager.shared.copyToClipboard(transcription.text, showSuccess: true)
        }
    }

    @objc private func toggleRecording() {
        TranscriptionManager.shared.toggleRecording()
    }

    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        TranscriptionManager.shared.cleanup()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Si aucune fenêtre visible, montrer la fenêtre principale
            if let window = sender.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}