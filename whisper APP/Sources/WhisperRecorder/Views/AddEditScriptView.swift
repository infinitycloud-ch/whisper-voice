import SwiftUI

struct AddEditScriptView: View {
    @ObservedObject var scriptManager: ScriptManager
    let theme: AppTheme
    let editingScript: ScriptTile?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedType: ScriptType = .shellScript
    @State private var iconName: String = ""
    @State private var selectedColor: Color = .blue
    @State private var projectPath: String = ""
    @State private var commandToRun: String = ""
    @State private var workingDirectory: String = ""
    @State private var isEnabled: Bool = true
    @State private var isFavorite: Bool = false

    @Environment(\.dismiss) private var dismiss

    var isEditing: Bool {
        editingScript != nil
    }

    init(scriptManager: ScriptManager, theme: AppTheme, editingScript: ScriptTile? = nil) {
        self.scriptManager = scriptManager
        self.theme = theme
        self.editingScript = editingScript

        if let script = editingScript {
            _name = State(initialValue: script.name)
            _description = State(initialValue: script.description)
            _selectedType = State(initialValue: script.type)
            _iconName = State(initialValue: script.iconName)
            _selectedColor = State(initialValue: script.colorValue)
            _projectPath = State(initialValue: script.projectPath)
            _commandToRun = State(initialValue: script.commandToRun)
            _workingDirectory = State(initialValue: script.workingDirectory ?? "")
            _isEnabled = State(initialValue: script.isEnabled)
            _isFavorite = State(initialValue: script.isFavorite)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header personnalisé
            HStack {
                Button("Annuler") {
                    dismiss()
                }

                Spacer()

                Text(isEditing ? "Modifier le script" : "Nouveau script")
                    .font(.headline)
                    .foregroundColor(theme.textColor)

                Spacer()

                Button(isEditing ? "Modifier" : "Ajouter") {
                    saveScript()
                }
                .disabled(name.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(theme.secondaryBackgroundColor)

            // Formulaire
            Form {
                Section("Informations générales") {
                    TextField("Nom du script", text: $name)
                    TextField("Description", text: $description)

                    Picker("Type", selection: $selectedType) {
                        ForEach(ScriptType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: selectedType) { newType in
                        if iconName == selectedType.defaultIcon || iconName.isEmpty {
                            iconName = newType.defaultIcon
                        }
                        if selectedColor == selectedType.defaultColor {
                            selectedColor = newType.defaultColor
                        }
                    }
                }

                Section("Apparence") {
                    HStack {
                        Text("Icône")
                        Spacer()
                        TextField("Nom de l'icône SF Symbols", text: $iconName)
                            .textFieldStyle(.roundedBorder)

                        Image(systemName: iconName.isEmpty ? selectedType.defaultIcon : iconName)
                            .font(.title2)
                            .foregroundColor(selectedColor)
                            .frame(width: 30)
                    }

                    ColorPicker("Couleur", selection: $selectedColor)
                }

                Section("Configuration") {
                    TextField("Chemin du projet", text: $projectPath)
                        .help("Chemin vers le dossier ou fichier du projet")

                    TextField("Commande à exécuter", text: $commandToRun)
                        .help("Commande ou arguments à passer")

                    TextField("Répertoire de travail (optionnel)", text: $workingDirectory)
                        .help("Répertoire dans lequel exécuter le script")
                }

                Section("Options") {
                    Toggle("Script activé", isOn: $isEnabled)
                    Toggle("Favori", isOn: $isFavorite)
                }

                Section("Exemples par type") {
                    exampleText
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }
            }
            .formStyle(.grouped)
        }
        .onAppear {
            if !isEditing {
                // Valeurs par défaut pour un nouveau script
                iconName = selectedType.defaultIcon
                selectedColor = selectedType.defaultColor
            }
        }
    }

    private var exampleText: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch selectedType {
            case .xcodeProject:
                Text("• Chemin: /Users/nom/MonProjet.xcodeproj")
                Text("• Commande: 'open' pour ouvrir, 'test' pour tester")
            case .swiftPackage:
                Text("• Chemin: /Users/nom/MonPackage")
                Text("• Commande: 'run' ou 'test'")
            case .shellScript:
                Text("• Chemin: /Users/nom/script.sh")
                Text("• Commande: './script.sh' ou 'bash script.sh'")
            case .pythonScript:
                Text("• Chemin: /Users/nom/script.py")
                Text("• Commande: 'script.py' ou 'main.py'")
            case .streamlitApp:
                Text("• Chemin: /Users/nom/app.py")
                Text("• Commande: 'app.py --port 8501'")
            case .nodeProject:
                Text("• Chemin: /Users/nom/MonApp")
                Text("• Commande: 'start' ou 'dev'")
            case .dockerCompose:
                Text("• Chemin: /Users/nom/docker-compose.yml")
                Text("• Commande: 'up -d' ou 'down'")
            case .webUrl:
                Text("• Chemin: (vide pour les URLs)")
                Text("• Commande: https://example.com")
            case .folderBookmark:
                Text("• Chemin: /Users/nom/Documents")
                Text("• Commande: (inutilisé)")
            case .custom:
                Text("• Chemin: /Users/nom/")
                Text("• Commande: commande personnalisée")
            }
        }
    }

    private func saveScript() {
        let newScript = ScriptTile(
            name: name,
            description: description,
            type: selectedType,
            iconName: iconName.isEmpty ? selectedType.defaultIcon : iconName,
            color: selectedColor,
            projectPath: projectPath,
            commandToRun: commandToRun,
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            environment: [:],
            isEnabled: isEnabled,
            isFavorite: isFavorite,
            id: editingScript?.id ?? UUID()
        )

        if isEditing {
            scriptManager.updateScriptTile(newScript)
        } else {
            scriptManager.addScriptTile(newScript)
        }

        dismiss()
    }
}

struct ScriptOutputView: View {
    let output: String
    let scriptName: String
    let theme: AppTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Sortie de: \(scriptName)")
                            .font(.headline)
                            .foregroundColor(theme.textColor)

                        Text("Dernière exécution")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }

                    Spacer()

                    Button("Copier") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(output, forType: .string)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(theme.secondaryBackgroundColor)

                // Output text
                ScrollView {
                    Text(output.isEmpty ? "Aucune sortie" : output)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(theme.textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .background(theme.backgroundColor)
            }
            .navigationTitle("Sortie du script")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}