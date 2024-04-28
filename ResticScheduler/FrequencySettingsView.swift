import Combine
import SwiftUI

struct FrequencySettingsView: View {
  @StateObject private var frequencySettings = FrequencySettings()
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack {
      Form {
        Picker("Frequency:", selection: $frequencySettings.frequencyType) {
          Text("Hourly")
            .tag(FrequencySettings.FrequencyType.hourly)
          Text("Daily")
            .tag(FrequencySettings.FrequencyType.daily)
          Text("Weekly")
            .tag(FrequencySettings.FrequencyType.weekly)
          Text("Monthly")
            .tag(FrequencySettings.FrequencyType.monthly)
        }
        HStack {
          TextField("Every:", text: $frequencySettings.amount)
            .onReceive(Just(frequencySettings.amount)) { value in
              if let number = Int(value.filter { "0123456789".contains($0) }), number > 0 {
                let newValue = String(number)
                if newValue != value {
                  frequencySettings.amount = newValue
                }
              } else {
                frequencySettings.amount = "1"
              }
            }
          Text(frequencySettings.unit)
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
            frequencySettings.apply()
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
  }
}

#Preview {
  FrequencySettingsView()
}
