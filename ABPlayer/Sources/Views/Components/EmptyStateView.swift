import SwiftUI

struct EmptyStateView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "waveform.circle")
        .font(.system(size: 64))
        .foregroundStyle(.tertiary)

      Text("No file selected")
        .font(.title2)

      Text("Import a folder or MP3 file to start creating A-B loops.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}
