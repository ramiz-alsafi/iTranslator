import SwiftUI
import Translation
import UIKit

enum LanguagePackStatus: String {
  case installed
  case supported
  case unsupported
}

/// The Translation framework only vends a `TranslationSession` through the SwiftUI
/// `.translationTask` modifier — there's no way to construct one directly. This hosts a
/// hidden, zero-size SwiftUI view in the app's key window purely to obtain a session and
/// bridge it back into plain async/await for the rest of the (UIKit-based) module.
@available(iOS 18.0, *)
@MainActor
final class TranslationHost {
  private var hostingController: UIHostingController<TranslationHostView>?
  private let viewModel = TranslationHostViewModel()

  /// Checks whether a language pair is installed / downloadable / unsupported, without
  /// mounting the SwiftUI host or triggering any UI.
  func checkAvailability(sourceLocale: String, targetLocale: String) async -> LanguagePackStatus {
    let availability = LanguageAvailability()
    let status = await availability.status(
      from: Locale.Language(identifier: sourceLocale),
      to: Locale.Language(identifier: targetLocale)
    )
    switch status {
    case .installed: return .installed
    case .supported: return .supported
    case .unsupported: return .unsupported
    @unknown default: return .unsupported
    }
  }

  /// Presents Apple's system sheet asking the user's permission to download the on-device
  /// language pack for this pair. Resolves once the user has responded to that sheet (the
  /// actual download continues in the background — re-check `checkAvailability` afterward).
  func prepareDownload(sourceLocale: String, targetLocale: String) async throws {
    mount()
    try await viewModel.prepareDownload(
      source: Locale.Language(identifier: sourceLocale),
      target: Locale.Language(identifier: targetLocale)
    )
  }

  /// Translates `text` from `sourceLocale` to `targetLocale` (BCP-47, e.g. "en-US").
  /// Throws if the language pack isn't installed yet — call `checkAvailability` /
  /// `prepareDownload` first.
  func translate(_ text: String, sourceLocale: String, targetLocale: String) async throws -> String {
    mount()
    return try await viewModel.translate(
      text,
      source: Locale.Language(identifier: sourceLocale),
      target: Locale.Language(identifier: targetLocale)
    )
  }

  private func mount() {
    guard hostingController == nil else { return }
    let controller = UIHostingController(rootView: TranslationHostView(viewModel: viewModel))
    controller.view.frame = .zero
    controller.view.isHidden = true
    controller.view.backgroundColor = .clear

    guard
      let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
      let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
      let rootVC = window.rootViewController
    else {
      return
    }

    rootVC.addChild(controller)
    window.addSubview(controller.view)
    controller.didMove(toParent: rootVC)
    hostingController = controller
  }
}

@available(iOS 18.0, *)
@MainActor
private final class TranslationHostViewModel: ObservableObject {
  @Published fileprivate var configuration: TranslationSession.Configuration?

  private enum PendingWork {
    case translate(text: String, continuation: CheckedContinuation<String, Error>)
    case download(continuation: CheckedContinuation<Void, Error>)
  }
  private var pending: PendingWork?

  func translate(_ text: String, source: Locale.Language, target: Locale.Language) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      self.pending = .translate(text: text, continuation: continuation)
      // Constructing a fresh Configuration re-triggers .translationTask below, even if the
      // source/target pair hasn't changed.
      self.configuration = TranslationSession.Configuration(source: source, target: target)
    }
  }

  func prepareDownload(source: Locale.Language, target: Locale.Language) async throws {
    try await withCheckedThrowingContinuation { continuation in
      self.pending = .download(continuation: continuation)
      self.configuration = TranslationSession.Configuration(source: source, target: target)
    }
  }

  func handle(session: TranslationSession) async {
    guard let work = pending else { return }
    pending = nil
    switch work {
    case .translate(let text, let continuation):
      do {
        let response = try await session.translate(text)
        continuation.resume(returning: response.targetText)
      } catch {
        continuation.resume(throwing: error)
      }
    case .download(let continuation):
      do {
        try await session.prepareTranslation()
        continuation.resume(returning: ())
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

@available(iOS 18.0, *)
struct TranslationHostView: View {
  @ObservedObject fileprivate var viewModel: TranslationHostViewModel

  var body: some View {
    Color.clear
      .translationTask(viewModel.configuration) { session in
        await viewModel.handle(session: session)
      }
  }
}