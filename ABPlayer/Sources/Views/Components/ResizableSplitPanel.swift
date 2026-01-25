import SwiftUI

// MARK: - Split Axis

enum SplitAxis {
  case horizontal  // left/right
  case vertical    // top/bottom
}

// MARK: - Resizable Split Panel

struct ResizableSplitPanel<Primary: View, Secondary: View>: View {
  let axis: SplitAxis
  
  // "secondary exists" toggle (maps to showContentPanel)
  @Binding var isSecondaryVisible: Bool
  
  // persisted size of primary (width for horizontal, height for vertical)
  @Binding var primarySize: Double
  
  // transient drag size (maps to draggingWidth today; generalized name)
  @Binding var draggingPrimarySize: Double?
  
  // sizing rules
  let minPrimary: CGFloat
  let minSecondary: CGFloat
  let dividerThickness: CGFloat
  
  // consumer-supplied clamp (keeps existing VM rules + persistence keys)
  let clampPrimarySize: (_ proposed: Double, _ availablePrimaryAxis: CGFloat) -> Double
  
  // visual behavior
  let animation: Animation
  let secondaryTransition: AnyTransition
  
  // content
  @ViewBuilder let primary: () -> Primary
  @ViewBuilder let secondary: () -> Secondary
  
  // MARK: - Initializer
  
  init(
    axis: SplitAxis,
    isSecondaryVisible: Binding<Bool>,
    primarySize: Binding<Double>,
    draggingPrimarySize: Binding<Double?>,
    minPrimary: CGFloat,
    minSecondary: CGFloat,
    dividerThickness: CGFloat = 8,
    clampPrimarySize: @escaping (_ proposed: Double, _ availablePrimaryAxis: CGFloat) -> Double,
    animation: Animation = .easeInOut(duration: 0.25),
    secondaryTransition: AnyTransition? = nil,
    @ViewBuilder primary: @escaping () -> Primary,
    @ViewBuilder secondary: @escaping () -> Secondary
  ) {
    self.axis = axis
    self._isSecondaryVisible = isSecondaryVisible
    self._primarySize = primarySize
    self._draggingPrimarySize = draggingPrimarySize
    self.minPrimary = minPrimary
    self.minSecondary = minSecondary
    self.dividerThickness = dividerThickness
    self.clampPrimarySize = clampPrimarySize
    self.animation = animation
    
    // Default transition based on axis
    if let transition = secondaryTransition {
      self.secondaryTransition = transition
    } else {
      self.secondaryTransition = axis == .horizontal
        ? .move(edge: .trailing).combined(with: .opacity)
        : .move(edge: .bottom).combined(with: .opacity)
    }
    
    self.primary = primary
    self.secondary = secondary
  }
  
  // MARK: - Body
  
  var body: some View {
    GeometryReader { geometry in
      let availablePrimaryAxis = axis == .horizontal ? geometry.size.width : geometry.size.height
      let effectiveSize = effectivePrimarySize(available: availablePrimaryAxis)
      
      Group {
        switch axis {
        case .horizontal:
          HStack(spacing: 0) {
            primary()
              .frame(minWidth: minPrimary)
              .frame(width: isSecondaryVisible ? effectiveSize : nil)
            
            if isSecondaryVisible {
              divider(availablePrimaryAxis: availablePrimaryAxis)
              
              secondary()
                .frame(minWidth: minSecondary, maxWidth: .infinity)
                .transition(secondaryTransition)
            }
          }
          
        case .vertical:
          VStack(spacing: 0) {
            primary()
              .frame(minHeight: minPrimary)
              .frame(height: isSecondaryVisible ? effectiveSize : nil)
            
            if isSecondaryVisible {
              divider(availablePrimaryAxis: availablePrimaryAxis)
              
              secondary()
                .frame(minHeight: minSecondary, maxHeight: .infinity)
                .transition(secondaryTransition)
            }
          }
        }
      }
      .animation(animation, value: isSecondaryVisible)
      .onChange(of: isSecondaryVisible) { _, isShowing in
        if isShowing {
          primarySize = clampPrimarySize(primarySize, availablePrimaryAxis)
        }
      }
    }
  }
  
  // MARK: - Private Methods
  
  private func effectivePrimarySize(available: CGFloat) -> Double {
    clampPrimarySize(draggingPrimarySize ?? primarySize, available)
  }
  
  private func translationDelta(_ value: DragGesture.Value) -> Double {
    axis == .horizontal ? value.translation.width : value.translation.height
  }
  
  private func divider(availablePrimaryAxis: CGFloat) -> some View {
    Rectangle()
      .fill(Color.gray.opacity(0.01))
      .frame(
        width: axis == .horizontal ? dividerThickness : nil,
        height: axis == .vertical ? dividerThickness : nil
      )
      .contentShape(Rectangle())
      .overlay(
        Rectangle()
          .fill(Color(nsColor: .separatorColor))
          .frame(
            width: axis == .horizontal ? 1 : nil,
            height: axis == .vertical ? 1 : nil
          )
      )
      .onHover { hovering in
        if hovering {
          switch axis {
          case .horizontal:
            NSCursor.resizeLeftRight.push()
          case .vertical:
            NSCursor.resizeUpDown.push()
          }
        } else {
          NSCursor.pop()
        }
      }
      .gesture(
        DragGesture(minimumDistance: 1)
          .onChanged { value in
            let delta = translationDelta(value)
            let newSize = (draggingPrimarySize ?? primarySize) + delta
            draggingPrimarySize = clampPrimarySize(newSize, availablePrimaryAxis)
          }
          .onEnded { _ in
            if let finalSize = draggingPrimarySize {
              primarySize = finalSize
            }
            draggingPrimarySize = nil
          }
      )
  }
}
