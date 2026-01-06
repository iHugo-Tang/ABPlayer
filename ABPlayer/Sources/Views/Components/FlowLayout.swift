import SwiftUI

/// A layout that arranges subviews horizontally and wraps to the next line when needed.
struct FlowLayout: Layout {
  var alignment: HorizontalAlignment = .leading
  var spacing: CGFloat = 4

  struct Cache {
    var size: CGSize = .zero
    var positions: [CGPoint] = []
    var proposal: ProposedViewSize = .zero
  }

  func makeCache(subviews: Subviews) -> Cache {
    Cache()
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    if cache.proposal == proposal {
      return cache.size
    }
    let result = arrange(proposal: proposal, subviews: subviews)
    cache.size = result.size
    cache.positions = result.positions
    cache.proposal = proposal
    return result.size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
  ) {
    if cache.proposal != proposal {
      let result = arrange(proposal: proposal, subviews: subviews)
      cache.size = result.size
      cache.positions = result.positions
      cache.proposal = proposal
    }

    for (index, position) in cache.positions.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: .unspecified
      )
    }
  }

  private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (
    size: CGSize, positions: [CGPoint]
  ) {
    let maxWidth = proposal.width ?? .infinity
    var positions: [CGPoint] = []
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var lineHeight: CGFloat = 0
    var totalHeight: CGFloat = 0
    var totalWidth: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)

      if currentX + size.width > maxWidth, currentX > 0 {
        currentX = 0
        currentY += lineHeight + spacing
        lineHeight = 0
      }

      positions.append(CGPoint(x: currentX, y: currentY))
      currentX += size.width + spacing
      lineHeight = max(lineHeight, size.height)
      totalWidth = max(totalWidth, currentX - spacing)
      totalHeight = currentY + lineHeight
    }

    return (CGSize(width: totalWidth, height: totalHeight), positions)
  }
}
