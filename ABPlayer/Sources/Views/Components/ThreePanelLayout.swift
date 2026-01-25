import SwiftUI

struct ThreePanelLayout<TopLeft: View, BottomLeft: View, Right: View>: View {
  @Binding var isRightVisible: Bool
  @Binding var leftColumnWidth: Double
  @Binding var draggingLeftColumnWidth: Double?
  let minLeftColumnWidth: CGFloat
  let minRightWidth: CGFloat
  let clampLeftColumnWidth: (_ proposed: Double, _ availableWidth: CGFloat) -> Double
  
  @Binding var isBottomLeftVisible: Bool
  @Binding var topLeftHeight: Double
  @Binding var draggingTopLeftHeight: Double?
  let minTopLeftHeight: CGFloat
  let minBottomLeftHeight: CGFloat
  let clampTopLeftHeight: (_ proposed: Double, _ availableHeight: CGFloat) -> Double
  
  let dividerThickness: CGFloat
  let animation: Animation
  
  @ViewBuilder let topLeft: () -> TopLeft
  @ViewBuilder let bottomLeft: () -> BottomLeft
  @ViewBuilder let right: () -> Right
  
  init(
    isRightVisible: Binding<Bool>,
    leftColumnWidth: Binding<Double>,
    draggingLeftColumnWidth: Binding<Double?>,
    minLeftColumnWidth: CGFloat,
    minRightWidth: CGFloat,
    clampLeftColumnWidth: @escaping (_ proposed: Double, _ availableWidth: CGFloat) -> Double,
    isBottomLeftVisible: Binding<Bool>,
    topLeftHeight: Binding<Double>,
    draggingTopLeftHeight: Binding<Double?>,
    minTopLeftHeight: CGFloat,
    minBottomLeftHeight: CGFloat,
    clampTopLeftHeight: @escaping (_ proposed: Double, _ availableHeight: CGFloat) -> Double,
    dividerThickness: CGFloat = 8,
    animation: Animation = .easeInOut(duration: 0.25),
    @ViewBuilder topLeft: @escaping () -> TopLeft,
    @ViewBuilder bottomLeft: @escaping () -> BottomLeft,
    @ViewBuilder right: @escaping () -> Right
  ) {
    self._isRightVisible = isRightVisible
    self._leftColumnWidth = leftColumnWidth
    self._draggingLeftColumnWidth = draggingLeftColumnWidth
    self.minLeftColumnWidth = minLeftColumnWidth
    self.minRightWidth = minRightWidth
    self.clampLeftColumnWidth = clampLeftColumnWidth
    
    self._isBottomLeftVisible = isBottomLeftVisible
    self._topLeftHeight = topLeftHeight
    self._draggingTopLeftHeight = draggingTopLeftHeight
    self.minTopLeftHeight = minTopLeftHeight
    self.minBottomLeftHeight = minBottomLeftHeight
    self.clampTopLeftHeight = clampTopLeftHeight
    
    self.dividerThickness = dividerThickness
    self.animation = animation
    
    self.topLeft = topLeft
    self.bottomLeft = bottomLeft
    self.right = right
  }
  
  var body: some View {
    ResizableSplitPanel(
      axis: .horizontal,
      isSecondaryVisible: $isRightVisible,
      primarySize: $leftColumnWidth,
      draggingPrimarySize: $draggingLeftColumnWidth,
      minPrimary: minLeftColumnWidth,
      minSecondary: minRightWidth,
      dividerThickness: dividerThickness,
      clampPrimarySize: clampLeftColumnWidth,
      animation: animation
    ) {
      ResizableSplitPanel(
        axis: .vertical,
        isSecondaryVisible: $isBottomLeftVisible,
        primarySize: $topLeftHeight,
        draggingPrimarySize: $draggingTopLeftHeight,
        minPrimary: minTopLeftHeight,
        minSecondary: minBottomLeftHeight,
        dividerThickness: dividerThickness,
        clampPrimarySize: clampTopLeftHeight,
        animation: animation
      ) {
        topLeft()
      } secondary: {
        bottomLeft()
      }
    } secondary: {
      right()
    }
  }
}
