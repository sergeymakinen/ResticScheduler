import Foundation
import os

extension String {
  init(contentsOfPipe pipe: Pipe) {
    self = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

struct RFC3164FormatStyle: FormatStyle {
  typealias FormatInput = Date
  typealias FormatOutput = String

  private static var dateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM dd HH:mm:ss"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    return dateFormatter
  }()

  func format(_ value: Date) -> String {
    var parts = Self.dateFormatter.string(from: value).components(separatedBy: " ")
    if parts[1].hasPrefix("0") {
      parts[1] = " " + parts[1].dropFirst(1)
    }
    return parts.joined(separator: " ")
  }
}

extension FormatStyle where Self == RFC3164FormatStyle {
  static var rfc3164: RFC3164FormatStyle { RFC3164FormatStyle() }
}

extension String {
  func append(to url: URL, encoding enc: String.Encoding) throws {
    if let exists = try? url.checkResourceIsReachable(), exists {
      let fileHandle = try FileHandle(forWritingTo: url)
      defer { fileHandle.closeFile() }
      fileHandle.seekToEndOfFile()
      fileHandle.write(data(using: enc)!)
    } else {
      try write(to: url, atomically: false, encoding: enc)
    }
  }
}

extension Process: @unchecked Sendable {}
