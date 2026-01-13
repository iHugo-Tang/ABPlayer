import SwiftUI

// MARK: - Typography System (Apple HIG macOS)

//extension Font {
//  // MARK: - Titles
//  /// 22pt - Main screen titles
//  static let largeTitle = Font.system(size: 22, weight: .bold, design: .default)
//
//  /// 17pt - Section titles
//  static let title = Font.system(size: 17, weight: .semibold, design: .default)
//
//  /// 15pt - Subsection titles
//  static let title3 = Font.system(size: 15, weight: .semibold, design: .default)
//
//  // MARK: - Headings
//  /// 13pt bold - List headers, emphasized text
//  static let appHeadline = Font.system(size: 13, weight: .semibold, design: .default)
//
//  // MARK: - Body
//  /// 13pt - Primary reading text
//  static let appBody = Font.system(size: 13, weight: .regular, design: .default)
//
//  /// 12pt - Secondary content
//  static let callout = Font.system(size: 12, weight: .regular, design: .default)
//
//  /// 11pt - Tertiary, less prominent
//  static let subheadline = Font.system(size: 11, weight: .regular, design: .default)
//
//  // MARK: - Captions
//  /// 10pt - Timestamps, metadata
//  static let appCaption = Font.system(size: 10, weight: .regular, design: .default)
//
//  /// 10pt light - Subtle labels
//  static let caption2 = Font.system(size: 10, weight: .light, design: .default)
//
//  // MARK: - Specialized
//  /// Monospaced for time display
//  static let monospacedTime = Font.system(size: 11, design: .monospaced).weight(.medium)
//}

extension Font {
  static let xs = Font.callout                              //12
  static let sm = Font.system(size: 14, design: .default)
}

// MARK: - Text Styles (Semantic)

extension View {
  func titleStyle() -> some View {
    self.font(.largeTitle)
  }

  func headlineStyle() -> some View {
    self.font(.headline)
  }

  func bodyStyle() -> some View {
    self.font(.sm)
      .foregroundStyle(Color.asset.textPrimary)
  }

  func captionStyle() -> some View {
    self.font(.callout)
      .foregroundStyle(Color.asset.textTertiary)
  }
}
