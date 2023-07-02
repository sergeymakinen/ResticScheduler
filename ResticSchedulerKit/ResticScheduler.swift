import Foundation

@objc public protocol ResticSchedulerProtocol {
  func progressDidUpdate(percentDone: Float64, bytesDone: UInt64)
}
