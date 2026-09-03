import AVFoundation
import Speech

enum SpeechEvent {
  case partial(String)
  case final(String)
  case error(String)
}

/// Wraps SFSpeechRecognizer + AVAudioEngine for continuous, on-device transcription.
final class SpeechRecognizer {
  private var recognizer: SFSpeechRecognizer?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()

  // All engine start/stop work happens on this serial queue. Without this, two
  // overlapping calls to start() (e.g. a fast double-tap on the mic button, or a
  // JS-side re-render firing the handler twice before state updates) can race:
  // both see "no tap installed yet" from stop(), then both call installTap(onBus: 0),
  // and the second one crashes because the first already claimed that bus. Serializing
  // here means the second call always waits for the first to fully finish first.
  private let engineQueue = DispatchQueue(label: "com.itranslator.speechrecognizer.engine")

  /// Requests both Speech Recognition and Microphone permission.
  func requestAuthorization() async throws -> Bool {
    let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
    guard speechStatus == .authorized else { return false }
    return await AVAudioApplication.requestRecordPermission()
  }

  /// Starts streaming mic audio into the recognizer. Calls `onEvent` for partial/final
  /// transcripts and errors, on an arbitrary background queue.
  func start(localeIdentifier: String, onEvent: @escaping (SpeechEvent) -> Void) throws {
    try engineQueue.sync {
      try startLocked(localeIdentifier: localeIdentifier, onEvent: onEvent)
    }
  }

  func stop() {
    engineQueue.sync {
      stopLocked()
    }
  }

  // MARK: - Must only be called while on engineQueue.

  private func startLocked(localeIdentifier: String, onEvent: @escaping (SpeechEvent) -> Void) throws {
    stopLocked()

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
          recognizer.isAvailable
    else {
      onEvent(.error("Speech recognizer unavailable for locale \(localeIdentifier)"))
      return
    }
    self.recognizer = recognizer

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    // Keep everything on-device: no audio/text ever leaves the phone.
    if recognizer.supportsOnDeviceRecognition {
      request.requiresOnDeviceRecognition = true
    }
    self.request = request

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
      request.append(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()

    task = recognizer.recognitionTask(with: request) { result, error in
      if let error {
        onEvent(.error(error.localizedDescription))
        return
      }
      guard let result else { return }
      let text = result.bestTranscription.formattedString
      onEvent(result.isFinal ? .final(text) : .partial(text))
    }
  }

  private func stopLocked() {
    audioEngine.stop()
    // removeTap is safe to call even when no tap is installed (documented no-op).
    audioEngine.inputNode.removeTap(onBus: 0)
    request?.endAudio()
    task?.cancel()
    request = nil
    task = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}