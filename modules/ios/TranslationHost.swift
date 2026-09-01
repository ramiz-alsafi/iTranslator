import SwiftUI
import Translation
import UIKit

/// The Translation framework only vends a `TranslationSession` through the SwiftUI
/// `.translationTask` modifier — there's no way to construct one directly. This hosts a
/// hidden, zero-size SwiftUI view in the app's key window purely to obtain a session and
/// bridge it back into plain async/await for the rest of the (UIKit-based) module.
@available(iOS 17.4, *)
final class TranslationHost {
  private var hostingController: UIHostingController<TranslationHostView>?
  private let viewModel = TranslationHostViewModel()

  /// Translates `text` from `sourceLocale` to `targetLocale` (BCP-47, e.g. "en-US").
  /// NOTE: the on-device language pack for this pair must already be downloaded, or this
  /// will throw. Use `LanguageAvailability` to check/prompt for downloads ahead of time —
  /// left as a TODO here since it needs its own UI flow.
  func translate(_ text: String, sourceLocale: String, targetLocale: String) async throws -> String {
    await mount()
    return try await viewModel.translate(
      text,
      source: Locale.Language(identifier: sourceLocale),
      target: Locale.Language(identifier: targetLocale)
    )
  }

  @MainActor
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

@available(iOS 17.4, *)
@MainActor
private final class TranslationHostViewModel: ObservableObject {
  @Published fileprivate var configuration: TranslationSession.Configuration?

  private var pendingText: String?
  private var pendingContinuation: CheckedContinuation<String, Error>?

  func translate(_ text: String, source: Locale.Language, target: Locale.Language) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      self.pendingText = text
      self.pendingContinuation = continuation
      // Constructing a fresh Configuration re-triggers .translationTask below, even if the
      // source/target pair hasn't changed.
      self.configuration = TranslationSession.Configuration(source: source, target: target)
    }
  }

  func handle(session: TranslationSession) async {
    guard let text = pendingText, let continuation = pendingContinuation else { return }
    pendingText = nil
    pendingContinuation = nil
    do {
      let response = try await session.translate(text)
      continuation.resume(returning: response.targetText)
    } catch {
      continuation.resume(throwing: error)
    }
  }
}

@available(iOS 17.4, *)
struct TranslationHostView: View {
  @ObservedObject fileprivate var viewModel: TranslationHostViewModel

  var body: some View {
    Color.clear
      .translationTask(viewModel.configuration) { session in
        await viewModel.handle(session: session)
      }
  }
}
