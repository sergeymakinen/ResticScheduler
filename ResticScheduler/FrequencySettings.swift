import Foundation

class FrequencySettings: ObservableObject {
  enum FrequencyType: Int {
    case everySecond = 1
    case everyMinute = 60
    case hourly = 3600
    case daily = 86400
    case weekly = 604_800
    case monthly = 2_592_000
  }

  struct Frequency {
    let type: FrequencyType
    let unit: String
  }

  static let frequencies = [
    Frequency(type: .monthly, unit: "month"),
    Frequency(type: .weekly, unit: "week"),
    Frequency(type: .daily, unit: "day"),
    Frequency(type: .hourly, unit: "hour"),
    Frequency(type: .everyMinute, unit: "minute"),
    Frequency(type: .everySecond, unit: "second"),
  ]

  @Published var frequencyType = FrequencyType.daily
  @Published var amount = "1"

  var unit: String { Self.frequencies.first(where: { $0.type == frequencyType })!.unit + (amount == "1" ? "" : "s") }

  func current() -> Self {
    let backupFrequency = AppEnvironment.shared.backupFrequency
    for frequency in Self.frequencies {
      if backupFrequency % frequency.type.rawValue == 0 {
        frequencyType = frequency.type
        amount = String(backupFrequency / frequency.type.rawValue)
        break
      }
    }
    return self
  }

  func apply() {
    AppEnvironment.shared.backupFrequency = Int(amount)! * FrequencySettings.frequencies.first(where: { $0.type == frequencyType })!.type.rawValue
  }
}
