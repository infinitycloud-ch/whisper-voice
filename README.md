# Whisper by Mr D

A native macOS voice-to-text application with global hotkey capture, AI-powered transcription, and smart text optimization. Press **Option+X** anywhere, speak, and your words appear as text — instantly copied to your clipboard.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)
![License](https://img.shields.io/badge/license-MIT-green)

<!--
## Screenshots

<p align="center">
  <img src="docs/screenshots/compact-mode.png" width="200" alt="Compact Mode">
  <img src="docs/screenshots/full-mode.png" width="600" alt="Full Mode">
</p>
-->

## Overview

Whisper by Mr D is a lightweight, always-available transcription tool that lives in your menu bar. It captures audio from your microphone, transcribes it using **Groq** (free) or **OpenAI**, and automatically copies the result to your clipboard. One hotkey, zero friction.

### Why Groq?

**Groq offers a free tier** for their Whisper API — making this app completely free to use for most users. Groq's LPU inference engine delivers transcription results significantly faster than traditional GPU-based solutions, often completing in under a second.

| Provider | Model | Speed | Cost |
|----------|-------|-------|------|
| **Groq** (default) | `whisper-large-v3-turbo` | Ultra-fast | **Free tier available** |
| OpenAI | `whisper-1` | Standard | Pay-per-use |

## Features

### Core
- **Global Hotkey** — `Option+X` (fully customizable) to start/stop recording from anywhere
- **Instant Transcription** — Speech-to-text via Groq or OpenAI Whisper API
- **Auto-Clipboard** — Transcribed text is automatically copied and optionally pasted into the active app
- **Live Preview** — Real-time transcription feedback every 5 seconds while recording
- **Menu Bar Integration** — Persistent status icon with quick actions

### AI-Powered
- **Text Optimization** — One-click grammar and style improvement using Llama 3.3 (via Groq)
- **Smart Organization** — AI-powered folder categorization for your transcriptions
- **PRD Generator** — Turn voice memos into structured Product Requirement Documents
- **Chat Assistant** — Conversational AI with voice input (speech-to-speech via ElevenLabs TTS)

### Interface
- **3 Window Modes** — Compact (mic only), Medium (list), Full (all features)
- **4 Themes** — Cyberpunk, Dark, Light, Slate
- **Folder System** — Organize transcriptions with drag & drop
- **Waveform Display** — Real-time audio visualization while recording

### Productivity
- **Transcription History** — Searchable archive with favorites, tags, and summaries
- **Command Launcher** — Execute shell scripts directly from the app
- **Script Dashboard** — Manage and run custom automation tiles

## Requirements

- macOS 13 (Ventura) or later
- Microphone access
- API key: **Groq** (recommended, free) or **OpenAI**

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/whisper-by-mrd.git
cd whisper-by-mrd

# Build with Swift Package Manager
cd "whisper APP"
swift build -c release

# Run the app
.build/release/WhisperRecorder
```

### Using the Build Script

```bash
cd "whisper APP"
chmod +x BUILD_APP.command
./BUILD_APP.command
```

This will compile the app, package it into `Whisper.app`, and launch it automatically.

## API Key Setup

### Option 1: Groq (Recommended — Free)

1. Go to [console.groq.com/keys](https://console.groq.com/keys)
2. Create a free account
3. Generate an API key
4. In the app: **Settings** > select **Groq** > paste your key > **Save**

### Option 2: OpenAI

1. Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Generate an API key (requires billing setup)
3. In the app: **Settings** > select **OpenAI** > paste your key > **Save**

> API keys are stored securely in macOS UserDefaults (protected by the system keychain). They never leave your machine except to authenticate with the chosen API.

## Architecture

```
whisper APP/
├── Package.swift                    # SPM configuration
├── Sources/WhisperRecorder/
│   ├── WhisperApp.swift             # App entry point & menu bar
│   ├── Models/
│   │   ├── TranscriptionModel.swift # Core data model
│   │   ├── Theme.swift              # 4 theme definitions
│   │   ├── TreeNode.swift           # Folder hierarchy
│   │   └── UIStateModel.swift       # Window mode state
│   ├── Services/
│   │   ├── GroqAPIService.swift     # Groq Whisper transcription
│   │   ├── OpenAIService.swift      # OpenAI Whisper fallback
│   │   ├── TranscriptionManager.swift  # Core orchestrator
│   │   ├── AudioRecorderManager.swift  # AVAudioRecorder wrapper
│   │   ├── TextOptimizationService.swift # AI text enhancement
│   │   ├── GroqChatService.swift    # Conversational AI
│   │   ├── DatabaseManager.swift    # SQLite persistence
│   │   └── AIOrganizer.swift        # Smart categorization
│   └── Views/
│       ├── ContentView.swift        # Mode router (compact/medium/full)
│       ├── MicrophoneMinimalView.swift # Compact mode
│       ├── SettingsView.swift       # API keys & hotkey config
│       ├── ChatView.swift           # AI chat interface
│       └── ...                      # 15+ view components
└── Resources/
    └── AppIcon.iconset/             # App icons
```

### Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [HotKey](https://github.com/soffes/HotKey) | 0.2.1 | Global keyboard shortcuts |
| [SQLite.swift](https://github.com/stephencelis/SQLite.swift) | 0.15.4 | Chat history persistence |

## Usage

1. **Launch** the app — it appears in your menu bar as a waveform icon
2. **Press `Option+X`** (or your custom hotkey) to start recording
3. **Speak** — you'll see a live waveform and partial transcription
4. **Press `Option+X` again** to stop — the transcription is copied to your clipboard
5. **Paste** anywhere with `Cmd+V`

### Window Modes

| Mode | Size | Use Case |
|------|------|----------|
| Compact | 200x220 | Just the mic button — minimal footprint |
| Medium | 400x700 | Transcription list with search |
| Full | 1100x800 | All features: sidebar, chat, dashboard |

### Customizing the Hotkey

Open **Settings** (`Cmd+,`) > **Hotkey** section > Click the key field and press your desired combination > **Save**.

## Privacy

- Audio is recorded locally and sent only to the API you choose (Groq or OpenAI)
- Transcriptions are stored locally on your Mac
- API keys are stored in macOS UserDefaults (system-protected)
- No analytics, no telemetry, no cloud sync

## Tech Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI
- **Audio:** AVFoundation
- **AI:** Groq API (Whisper, Llama 3.3), OpenAI API
- **Database:** SQLite (via SQLite.swift)
- **Build:** Swift Package Manager

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

Built by **Mr D** — part of the [Infinity Cloud](https://infinitycloud.ch) ecosystem.
