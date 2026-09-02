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

    AsyncFunction("checkLanguageAvailability") { (sourceLocale: String, targetLocale: String) -> String in
      guard #available(iOS 18.0, *) else { return "unsupported" }
      return await self.host().checkAvailability(sourceLocale: sourceLocale, targetLocale: targetLocale).rawValue
    }

    AsyncFunction("prepareLanguageDownload") { (sourceLocale: String, targetLocale: String) in
      guard #available(iOS 18.0, *) else {
        throw Exception(name: "Unsupported", description: "Translation requires iOS 18.0+")
      }
      try await self.host().prepareDownload(sourceLocale: sourceLocale, targetLocale: targetLocale)
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

  @available(iOS 18.0, *)
  @MainActor
  private func host() -> TranslationHost {
    if let existing = translationHost as? TranslationHost {
      return existing
    }
    let host = TranslationHost()
    translationHost = host
    return host
  }

  private func translate(_ text: String, from sourceLocale: String, to targetLocale: String) {
    guard #available(iOS 18.0, *) else {
      sendEvent("onError", ["message": "Translation requires iOS 18.0+"])
      return
    }

    Task {
      do {
        let translated = try await self.host().translate(text, sourceLocale: sourceLocale, targetLocale: targetLocale)
        self.sendEvent("onTranslated", ["original": text, "translated": translated])
      } catch {
        self.sendEvent("onError", ["message": error.localizedDescription])
      }
    }
  }
}