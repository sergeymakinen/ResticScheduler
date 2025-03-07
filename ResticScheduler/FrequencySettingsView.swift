import Combine
import SwiftUI

class Frequency: ObservableObject {
    enum FrequencyType: Int {
        case everySecond = 1
        case everyMinute = 60
        case hourly = 3600
        case daily = 86400
        case weekly = 604_800
        case monthly = 2_592_000
    }

    private struct FrequencyUnit {
        let type: FrequencyType
        let unit: String
    }

    private static let units = [
        FrequencyUnit(type: .monthly, unit: "month"),
        FrequencyUnit(type: .weekly, unit: "week"),
        FrequencyUnit(type: .daily, unit: "day"),
        FrequencyUnit(type: .hourly, unit: "hour"),
        FrequencyUnit(type: .everyMinute, unit: "minute"),
        FrequencyUnit(type: .everySecond, unit: "second"),
    ]

    @Published var frequencyType = FrequencyType.daily
    @Published var amount = "1"

    var unit: String {
        Self.units.first(where: { $0.type == frequencyType })!.unit + (amount == "1" ? "" : "s")
    }

    var seconds: Int {
        get {
            Int(amount)! * Self.units.first(where: { $0.type == frequencyType })!.type.rawValue
        }
        set {
            for unit in Self.units {
                if newValue % unit.type.rawValue == 0 {
                    frequencyType = unit.type
                    amount = String(newValue / unit.type.rawValue)
                    return
                }
            }
        }
    }

    init() {}

    init(seconds: Int) {
        self.seconds = seconds
    }
}

struct FrequencySettingsView: View {
    @StateObject private var frequency = Frequency()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var resticScheduler: ResticScheduler
    @UserDefault(\.backupFrequency) private var backupFrequency

    var body: some View {
        VStack {
            Form {
                Picker("Frequency:", selection: $frequency.frequencyType) {
                    Text("Hourly")
                        .tag(Frequency.FrequencyType.hourly)
                    Text("Daily")
                        .tag(Frequency.FrequencyType.daily)
                    Text("Weekly")
                        .tag(Frequency.FrequencyType.weekly)
                    Text("Monthly")
                        .tag(Frequency.FrequencyType.monthly)
                }
                HStack {
                    TextField("Every:", text: $frequency.amount)
                        .onReceive(Just(frequency.amount)) { value in
                            if let number = Int(value.filter { "0123456789".contains($0) }), number > 0 {
                                let newValue = String(number)
                                if newValue != value {
                                    frequency.amount = newValue
                                }
                            } else {
                                frequency.amount = "1"
                            }
                        }
                    Text(frequency.unit)
                }
            }
            HStack {
                HStack {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut(.cancelAction)
                    Button {
                        backupFrequency = frequency.seconds
                        dismiss()
                    } label: {
                        Text("OK")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(maxWidth: 150)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 5)
        }
        .frame(width: 250, alignment: .center)
        .padding()
        .onAppear { frequency.seconds = backupFrequency }
        .onChange(of: backupFrequency) { _ in
            resticScheduler.rescheduleBackup()
            resticScheduler.rescheduleStaleBackupCheck()
        }
    }
}

#Preview {
    FrequencySettingsView()
}
