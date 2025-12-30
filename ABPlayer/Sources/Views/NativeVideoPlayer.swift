import AVKit
import SwiftUI

#if os(macOS)
  /// A simple wrapper around AVPlayerView that hides all native controls.
  struct NativeVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
      let view = AVPlayerView()
      view.player = player
      view.controlsStyle = .none  // Hides all native controls (volume, cast, timeline)
      view.videoGravity = .resizeAspect
      return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
      if nsView.player !== player {
        nsView.player = player
      }
    }
  }
#endif
