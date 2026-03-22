import Foundation
import AVFoundation

class AudioRecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 20)
    @Published var currentInputDevice: String = "Microphone par défaut"
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var levelTimer: Timer?
    private var recordingStartTime: Date?
    
    override init() {
        super.init()
    }
    
    func startRecording() -> URL? {
        // Update device name asynchronously to avoid blocking main thread
        Task.detached(priority: .background) {
            await self.updateCurrentInputDevice()
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let outputURL = documentsPath.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            if audioRecorder?.record() == true {
                isRecording = true
                recordingStartTime = Date()
                
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    if let startTime = self.recordingStartTime {
                        self.recordingTime = Date().timeIntervalSince(startTime)
                    }
                }
                
                levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    self.updateAudioLevels()
                }
                
                print("✅ Recording started successfully")
                return outputURL
            } else {
                print("❌ audioRecorder.record() returned false")
                return nil
            }
        } catch {
            print("❌ Failed to start recording: \(error)")
            return nil
        }
    }
    
    func stopRecording() -> (URL?, TimeInterval)? {
        guard let recorder = audioRecorder else {
            print("❌ stopRecording: no recorder")
            return nil
        }

        // Arrêter même si isRecording est false (au cas où)
        let url = recorder.url
        recorder.stop()

        // Nettoyer complètement
        isRecording = false
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevels = Array(repeating: 0.0, count: 20)

        let duration = recordingTime
        recordingTime = 0
        recordingStartTime = nil

        // Important: libérer le recorder pour éviter les fuites
        audioRecorder = nil

        print("✅ stopRecording: stopped and cleaned up, duration: \(duration)")
        return (url, duration)
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let decibels = recorder.averagePower(forChannel: 0)
        
        // Convert dB to 0-1 range (-160 dB = silence, 0 dB = max)
        let minDb: Float = -60.0
        let normalizedValue = (decibels - minDb) / (0 - minDb)
        let clampedValue = max(0, min(1, normalizedValue))
        
        // Shift array left and add new value
        audioLevels.removeFirst()
        audioLevels.append(clampedValue)
    }
    
    func toggleRecording(completion: @escaping (URL?, TimeInterval) -> Void) {
        if isRecording {
            if let result = stopRecording() {
                completion(result.0, result.1)
            }
        } else {
            _ = startRecording()
        }
    }

    /// Returns the current recording URL (for live transcription)
    var currentRecordingURL: URL? {
        return audioRecorder?.url
    }

    /// Copy the current recording to a temporary file for incremental transcription
    func copyCurrentRecordingForPreview() -> URL? {
        guard let sourceURL = audioRecorder?.url,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("preview_\(Date().timeIntervalSince1970).m4a")

        do {
            // Copy the file (AVAudioRecorder continues writing to original)
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)
            return tempURL
        } catch {
            print("❌ Failed to copy recording for preview: \(error)")
            return nil
        }
    }
    
    private func updateCurrentInputDevice() async {
        // Sur macOS, on utilise une approche différente pour obtenir le nom du micro
        // Cette opération peut être lente, d'où l'async
        if let defaultDevice = AVCaptureDevice.default(for: .audio) {
            let name = defaultDevice.localizedName
            await MainActor.run {
                self.currentInputDevice = name
            }
        } else {
            await MainActor.run {
                self.currentInputDevice = "Microphone par défaut"
            }
        }
    }
}

extension AudioRecorderManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}
