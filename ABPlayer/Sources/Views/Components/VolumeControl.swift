import SwiftUI
import Observation

// MARK: - Volume Control

struct VolumeControl: View {
  @Environment(PlayerManager.self) private var playerManager

  @Binding var playerVolume: Double
  @State private var showVolumePopover: Bool = false

  var body: some View {
    Button {
      showVolumePopover.toggle()
    } label: {
      Image(systemName: playerVolume == 0 ? "speaker.slash" : "speaker.wave.3")
        .font(.title2)
        .frame(width: 24, height: 24)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showVolumePopover, arrowEdge: .bottom) {
      HStack(spacing: 8) {
        Slider(value: $playerVolume, in: 0...2) {
          Text("Volume")
        }
        .frame(width: 150)

        HStack(spacing: 2) {
          Text("\(Int(playerVolume * 100))%")
          if playerVolume > 1.001 {
            Image(systemName: "bolt.fill")
              .foregroundStyle(.orange)
          }
        }
        .frame(width: 50, alignment: .trailing)
        .font(.caption2)
        .foregroundStyle(.secondary)

        Button {
          playerVolume = 1.0
        } label: {
          Image(systemName: "arrow.counterclockwise")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Reset volume to 100%")
      }
      .padding()
    }
    .onAppear {
      playerManager.setVolume(Float(playerVolume))
    }
    .help("Volume")
  }
}
