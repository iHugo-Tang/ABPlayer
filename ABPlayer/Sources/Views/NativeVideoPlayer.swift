import AVFoundation
import AVKit
import OSLog
import SwiftUI

#if os(macOS)
  /// A simple wrapper around AVPlayerView that hides all native controls.
  struct NativeVideoPlayer: NSViewRepresentable {
    weak var player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerView {
      let view = AVPlayerView()
      view.player = player
      view.controlsStyle = .none  // Hides all native controls (volume, cast, timeline)
      view.videoGravity = .resizeAspect
      return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
      if nsView.player != player {
        nsView.player = player
      }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
      let playerDesc = nsView.player.map { "\(Unmanaged.passUnretained($0).toOpaque())" } ?? "nil"
      Logger.ui.debug("[NativeVideoPlayer] dismantleNSView player: \(playerDesc)")
    }
  }

#endif
