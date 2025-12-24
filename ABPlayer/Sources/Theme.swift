import SwiftUI

// MARK: - Color Theme

extension Color {
  /// Accent gradient for highlighted elements
  static let accentGradient = LinearGradient(
    colors: [
      Color(hue: 0.58, saturation: 0.7, brightness: 0.9),  // Cyan
      Color(hue: 0.75, saturation: 0.6, brightness: 0.85),  // Purple
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// Subtle background gradient
  static let subtleBackground = LinearGradient(
    colors: [
      Color(.windowBackgroundColor).opacity(0.95),
      Color(.windowBackgroundColor),
    ],
    startPoint: .top,
    endPoint: .bottom
  )
}

// MARK: - Button Styles

struct PillButtonStyle: ButtonStyle {
  var isActive: Bool = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.caption.weight(.medium))
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(
        Capsule()
          .fill(isActive ? Color.accentColor : Color(.controlBackgroundColor))
      )
      .foregroundStyle(isActive ? .white : .primary)
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

struct GlassButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(.ultraThinMaterial)
          .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

// MARK: - Card Style

struct CardStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(.regularMaterial)
          .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
      )
  }
}

extension View {
  func cardStyle() -> some View {
    modifier(CardStyle())
  }
}

// MARK: - Progress Bar Style

struct StyledSlider: View {
  @Binding var value: Double
  let range: ClosedRange<Double>
  let onEditingChanged: ((Bool) -> Void)?

  init(
    value: Binding<Double>, in range: ClosedRange<Double>, onEditingChanged: ((Bool) -> Void)? = nil
  ) {
    self._value = value
    self.range = range
    self.onEditingChanged = onEditingChanged
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        // Track
        Capsule()
          .fill(Color(.separatorColor))
          .frame(height: 4)

        // Filled portion
        Capsule()
          .fill(Color.accentColor)
          .frame(width: progressWidth(for: geometry.size.width), height: 4)

        // Thumb
        Circle()
          .fill(Color.white)
          .frame(width: 14, height: 14)
          .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
          .offset(x: thumbOffset(for: geometry.size.width))
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            let newValue = valueForPosition(gesture.location.x, width: geometry.size.width)
            value = newValue
          }
          .onEnded { _ in
            onEditingChanged?(false)
          }
      )
    }
    .frame(height: 20)
  }

  private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
    let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    return max(0, min(totalWidth, CGFloat(progress) * totalWidth))
  }

  private func thumbOffset(for totalWidth: CGFloat) -> CGFloat {
    progressWidth(for: totalWidth) - 7
  }

  private func valueForPosition(_ position: CGFloat, width: CGFloat) -> Double {
    let progress = max(0, min(1, position / width))
    return range.lowerBound + (range.upperBound - range.lowerBound) * Double(progress)
  }
}

// MARK: - Animations

extension Animation {
  static let smoothSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
  static let quickFade = Animation.easeOut(duration: 0.15)
}

// MARK: - Typography

extension Font {
  static let monospacedTime = Font.system(.caption, design: .monospaced).weight(.medium)
}
