import ExpoModulesCore

public class PipCaptionModule: Module {
  public func definition() -> ModuleDefinition {
    Name("PipCaption")

    Function("isSupported") { () -> Bool in
      PipCaptionRenderer.shared.isSupported
    }

    Function("isActive") { () -> Bool in
      PipCaptionRenderer.shared.isActive
    }

    Function("updateCaption") { (original: String, translated: String) in
      PipCaptionRenderer.shared.updateText(original: original, translated: translated)
    }

    AsyncFunction("start") {
      try PipCaptionRenderer.shared.start()
    }

    AsyncFunction("stop") {
      PipCaptionRenderer.shared.stop()
    }
  }
}