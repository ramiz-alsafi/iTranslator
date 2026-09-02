import AVFoundation
import UIKit

/// Puts live captions into a real system-wide floating window using
/// AVPictureInPictureController + AVSampleBufferDisplayLayer — the "custom content in PiP"
/// technique (not a video player). We draw a caption card into an offscreen UIView, rasterize
/// it to a CVPixelBuffer, wrap that as a CMSampleBuffer, and enqueue it as a single "frame"
/// every time the caption text changes. The PiP window then behaves like a real system overlay:
/// draggable, resizable, persists over the home screen and other apps.
///
/// This has been written and reasoned through carefully but not compiled/run on a device yet —
/// there's no macOS/Xcode toolchain available where this was written. AVSampleBufferDisplayLayer
/// + PiP has known device/OS-version quirks (see Apple developer forum threads on this exact
/// API), so budget real device-testing time before you trust this.
final class PipCaptionRenderer: NSObject {
  static let shared = PipCaptionRenderer()

  private let displayLayer = AVSampleBufferDisplayLayer()
  private var pipController: AVPictureInPictureController?
  private let renderSize = CGSize(width: 360, height: 160)

  private let hostView: UIView
  private let originalLabel = UILabel()
  private let translatedLabel = UILabel()
  private var pixelBufferPool: CVPixelBufferPool?

  override init() {
    hostView = UIView(frame: CGRect(origin: .zero, size: renderSize))
    super.init()
    setupCard()
    setupPixelBufferPool()
  }

  var isSupported: Bool {
    AVPictureInPictureController.isPictureInPictureSupported()
  }

  var isActive: Bool {
    pipController?.isPictureInPictureActive ?? false
  }

  // MARK: - Card layout

  private func setupCard() {
    hostView.backgroundColor = UIColor.black.withAlphaComponent(0.88)
    hostView.layer.cornerRadius = 20
    hostView.layer.masksToBounds = true

    originalLabel.font = .systemFont(ofSize: 15, weight: .medium)
    originalLabel.textColor = UIColor.white.withAlphaComponent(0.6)
    originalLabel.numberOfLines = 2
    originalLabel.frame = CGRect(x: 16, y: 16, width: renderSize.width - 32, height: 44)

    translatedLabel.font = .systemFont(ofSize: 20, weight: .semibold)
    translatedLabel.textColor = .white
    translatedLabel.numberOfLines = 3
    translatedLabel.frame = CGRect(x: 16, y: 64, width: renderSize.width - 32, height: 80)

    hostView.addSubview(originalLabel)
    hostView.addSubview(translatedLabel)
  }

  private func setupPixelBufferPool() {
    let attrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: Int(renderSize.width),
      kCVPixelBufferHeightKey as String: Int(renderSize.height),
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary,
    ]
    CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pixelBufferPool)
  }

  // MARK: - Public API

  func updateText(original: String, translated: String) {
    DispatchQueue.main.async {
      self.originalLabel.text = original
      self.translatedLabel.text = translated
      self.enqueueFrame()
    }
  }

  func start() throws {
    guard isSupported else {
      throw NSError(
        domain: "PipCaption", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Picture in Picture isn't supported on this device."])
    }

    if pipController == nil {
      let contentSource = AVPictureInPictureController.ContentSource(
        sampleBufferDisplayLayer: displayLayer,
        playbackDelegate: self
      )
      let controller = AVPictureInPictureController(contentSource: contentSource)
      controller.delegate = self
      pipController = controller
    }

    enqueueFrame()
    pipController?.startPictureInPicture()
  }

  func stop() {
    pipController?.stopPictureInPicture()
  }

  // MARK: - Frame rendering

  private func enqueueFrame() {
    guard let pool = pixelBufferPool else { return }
    var pixelBufferOut: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferOut)
    guard let pixelBuffer = pixelBufferOut else { return }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    let context = CGContext(
      data: CVPixelBufferGetBaseAddress(pixelBuffer),
      width: Int(renderSize.width),
      height: Int(renderSize.height),
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    )
    if let context {
      UIGraphicsPushContext(context)
      hostView.layer.render(in: context)
      UIGraphicsPopContext()
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

    guard let sampleBuffer = makeSampleBuffer(from: pixelBuffer) else { return }
    displayLayer.enqueue(sampleBuffer)
  }

  private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
    var formatDescription: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
      allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
    guard let formatDescription else { return nil }

    var timingInfo = CMSampleTimingInfo(
      duration: .invalid,
      presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
      decodeTimeStamp: .invalid
    )

    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateForImageBuffer(
      allocator: nil,
      imageBuffer: pixelBuffer,
      dataReady: true,
      makeDataReadyCallback: nil,
      refcon: nil,
      formatDescription: formatDescription,
      sampleTiming: &timingInfo,
      sampleBufferOut: &sampleBuffer
    )
    return sampleBuffer
  }
}

extension PipCaptionRenderer: AVPictureInPictureControllerDelegate {
  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    // TODO: wire this back to JS via an Expo module event if you want the UI to show it.
  }
}

/// Tells PiP this is a "live" feed rather than seekable video — no scrubber, no play/pause UI.
extension PipCaptionRenderer: AVPictureInPictureSampleBufferPlaybackDelegate {
  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool
  ) {}

  func pictureInPictureControllerTimeRangeForPlayback(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> CMTimeRange {
    CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
  }

  func pictureInPictureControllerIsPlaybackPaused(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> Bool {
    false
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    didTransitionToRenderSize newRenderSize: CMVideoDimensions
  ) {}

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    skipByInterval skipInterval: CMTime,
    completion completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }

  func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> Bool {
    // We want OUR background audio (the mic capture) to keep running, not be prohibited.
    true
  }
}