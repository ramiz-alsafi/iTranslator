import ExpoModulesCore

public class LiveTranslateModule: Module {
  private let speech = SpeechRecognizer()
  private var translationHost: Any?

  public func definition() -> ModuleDefinition {
    Name("LiveTranslate")

    Events("onPartialTranscript", "onFinalTranscript", "onTranslated", "onError")

    AsyncFunction("requestPermissions") { () -> Bool in
      try await self.speech.requestAuthorization()
    }

    AsyncFunction("startListening") { (sourceLocale: String, targetLocale: String) in
      try self.speech.start(localeIdentifier: sourceLocale) { [weak self] event in
        guard let self else { return }
        switch event {
        case .partial(let text):
          self.sendEvent("onPartialTranscript", ["text": text])

        case .final(let text):
          self.sendEvent("onFinalTranscript", ["text": text])
          self.translate(text, from: sourceLocale, to: targetLocale)

        case .error(let message):
          self.sendEvent("onError", ["message": message])
        }
      }
    }

    AsyncFunction("stopListening") {
      self.speech.stop()
    }

    OnDestroy {
      self.speech.stop()
    }
  }

  private func translate(_ text: String, from sourceLocale: String, to targetLocale: String) {
    guard #available(iOS 17.4, *) else {
      sendEvent("onError", ["message": "Translation requires iOS 17.4+"])
      return
    }

    let host: TranslationHost
    if let existing = translationHost as? TranslationHost {
      host = existing
    } else {
      host = TranslationHost()
      translationHost = host
    }

    Task {
      do {
        let translated = try await host.translate(text, sourceLocale: sourceLocale, targetLocale: targetLocale)
        self.sendEvent("onTranslated", ["original": text, "translated": translated])
      } catch {
        self.sendEvent("onError", ["message": error.localizedDescription])
      }
    }
  }
}
