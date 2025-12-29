import Foundation
import SwiftData

/// Represents a subtitle cue with timing information
struct SubtitleCue: Codable, Identifiable, Equatable {
  let id: UUID
  let startTime: Double
  let endTime: Double
  let text: String

  init(id: UUID = UUID(), startTime: Double, endTime: Double, text: String) {
    self.id = id
    self.startTime = startTime
    self.endTime = endTime
    self.text = text
  }
}

@Model
final class SubtitleFile {
  var id: UUID
  var displayName: String

  @Attribute(.externalStorage)
  var bookmarkData: Data

  var createdAt: Date
  var audioFile: AudioFile?

  /// Cached parsed cues (stored as JSON)
  @Attribute(.externalStorage)
  private var cachedCuesData: Data?

  init(
    id: UUID = UUID(),
    displayName: String,
    bookmarkData: Data,
    createdAt: Date = Date(),
    audioFile: AudioFile? = nil
  ) {
    self.id = id
    self.displayName = displayName
    self.bookmarkData = bookmarkData
    self.createdAt = createdAt
    self.audioFile = audioFile
  }

  /// Parsed subtitle cues
  var cues: [SubtitleCue] {
    get {
      guard let data = cachedCuesData else {
        return []
      }
      return (try? JSONDecoder().decode([SubtitleCue].self, from: data)) ?? []
    }
    set {
      cachedCuesData = try? JSONEncoder().encode(newValue)
    }
  }
}

// MARK: - Subtitle Parser

enum SubtitleFormat {
  case srt
  case vtt
  case unknown
}

struct SubtitleParser {
  static func detectFormat(from url: URL) -> SubtitleFormat {
    switch url.pathExtension.lowercased() {
    case "srt":
      return .srt
    case "vtt":
      return .vtt
    default:
      return .unknown
    }
  }

  static func parse(from url: URL) throws -> [SubtitleCue] {
    let content = try String(contentsOf: url, encoding: .utf8)
    let format = detectFormat(from: url)

    switch format {
    case .srt:
      return parseSRT(content)
    case .vtt:
      return parseVTT(content)
    case .unknown:
      return []
    }
  }

  // MARK: - SRT Writer

  static func writeSRT(cues: [SubtitleCue], to url: URL) throws {
    var content = ""
    for (index, cue) in cues.enumerated() {
      content += "\(index + 1)\n"
      content += "\(formatSRTTime(cue.startTime)) --> \(formatSRTTime(cue.endTime))\n"
      content += "\(cue.text)\n\n"
    }
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  private static func formatSRTTime(_ seconds: Double) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60
    let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
    return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
  }

  // MARK: - SRT Parser

  private static func parseSRT(_ content: String) -> [SubtitleCue] {
    var cues: [SubtitleCue] = []
    let blocks = content.components(separatedBy: "\n\n")

    for block in blocks {
      let lines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
      guard lines.count >= 3 else { continue }

      // Line 0: index number (ignored)
      // Line 1: timestamp "00:00:00,000 --> 00:00:00,000"
      // Line 2+: text

      let timeLine = lines[1]
      guard let (start, end) = parseTimestampLine(timeLine, separator: ",") else {
        continue
      }

      let text = lines.dropFirst(2).joined(separator: "\n")
      cues.append(SubtitleCue(startTime: start, endTime: end, text: text))
    }

    return cues
  }

  // MARK: - VTT Parser

  private static func parseVTT(_ content: String) -> [SubtitleCue] {
    var cues: [SubtitleCue] = []
    var lines = content.components(separatedBy: "\n")

    // Skip WEBVTT header
    if let firstNonEmpty = lines.first(where: { !$0.isEmpty }),
      firstNonEmpty.hasPrefix("WEBVTT")
    {
      lines.removeFirst()
    }

    // Join back and split by double newlines
    let blocks = lines.joined(separator: "\n").components(separatedBy: "\n\n")

    for block in blocks {
      let blockLines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
      guard !blockLines.isEmpty else { continue }

      // Find timestamp line
      var timestampIndex = 0
      for (index, line) in blockLines.enumerated() {
        if line.contains("-->") {
          timestampIndex = index
          break
        }
      }

      guard timestampIndex < blockLines.count else { continue }

      let timeLine = blockLines[timestampIndex]
      guard let (start, end) = parseTimestampLine(timeLine, separator: ".") else {
        continue
      }

      let text = blockLines.dropFirst(timestampIndex + 1).joined(separator: "\n")
      guard !text.isEmpty else { continue }

      cues.append(SubtitleCue(startTime: start, endTime: end, text: text))
    }

    return cues
  }

  // MARK: - Timestamp Parsing

  private static func parseTimestampLine(_ line: String, separator: String) -> (Double, Double)? {
    let parts = line.components(separatedBy: " --> ")
    guard parts.count == 2 else { return nil }

    let startStr = parts[0].trimmingCharacters(in: .whitespaces)
    let endStr = parts[1].components(separatedBy: " ").first ?? parts[1]

    guard let start = parseTimestamp(startStr, separator: separator),
      let end = parseTimestamp(endStr.trimmingCharacters(in: .whitespaces), separator: separator)
    else {
      return nil
    }

    return (start, end)
  }

  private static func parseTimestamp(_ timestamp: String, separator: String) -> Double? {
    // Format: HH:MM:SS,mmm or HH:MM:SS.mmm or MM:SS,mmm
    let normalized = timestamp.replacingOccurrences(of: separator, with: ".")
    let components = normalized.components(separatedBy: ":")

    guard components.count >= 2 else { return nil }

    var hours: Double = 0
    var minutes: Double = 0
    var seconds: Double = 0

    if components.count == 3 {
      hours = Double(components[0]) ?? 0
      minutes = Double(components[1]) ?? 0
      seconds = Double(components[2]) ?? 0
    } else if components.count == 2 {
      minutes = Double(components[0]) ?? 0
      seconds = Double(components[1]) ?? 0
    }

    return hours * 3600 + minutes * 60 + seconds
  }
}
