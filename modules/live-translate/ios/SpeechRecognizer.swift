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
    stop()

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

  func stop() {
    audioEngine.stop()
    // removeTap is safe to call even when no tap is installed (documented no-op) —
    // don't guard it with `numberOfInputs > 0`: the mic input node always reports
    // 0 *input* buses (it's a source node, its tap lives on its *output* bus), so
    // that check was always false and the previous tap was never actually removed.
    // That left a stale tap installed every time start() was called again, and the
    // next installTap(onBus: 0, ...) call would crash trying to add a second tap
    // to the same bus.
    audioEngine.inputNode.removeTap(onBus: 0)
    request?.endAudio()
    task?.cancel()
    request = nil
    task = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}