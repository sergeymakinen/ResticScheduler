import Foundation
import os

extension String {
  init(contentsOfPipe pipe: Pipe) {
    self = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

protocol ReadableFileHandle {
  var fileHandleForReading: FileHandle { get }
}

protocol WritableFileHandle {
  var fileHandleForWriting: FileHandle { get }
}

extension Pipe: ReadableFileHandle, WritableFileHandle {}

extension FileHandle: ReadableFileHandle, WritableFileHandle {
  var fileHandleForReading: FileHandle { self }

  var fileHandleForWriting: FileHandle { self }
}

extension ReadableFileHandle {
  func duplicate(into handles: WritableFileHandle...) {
    let group = DispatchGroup()
    fileHandleForReading.readabilityHandler = { readHandle in
      let data = readHandle.availableData
      guard !data.isEmpty else {
        readHandle.readabilityHandler = nil
        return
      }

      for handle in handles {
        group.enter()
        handle.fileHandleForWriting.writeabilityHandler = { writeHandle in
          try! writeHandle.write(contentsOf: data)
          writeHandle.writeabilityHandler = nil
          group.leave()
        }
      }
      group.wait()
    }
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
