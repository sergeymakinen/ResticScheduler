import Combine
import SwiftUI

class EditableList: Model {
  struct ListItem: Identifiable, Equatable {
    let id: Int
    var value: String
  }

  @Published var list: [ListItem] = [] {
    didSet {
      guard !ignoringChanges else { return }
      guard list != oldValue else { return }

      ignoringChanges {
        self.data.wrappedValue = self.list
          .filter { item in !item.value.trimmingCharacters(in: .whitespaces).isEmpty }
          .map { item in item.value }
      }
    }
  }

  @Published var selection: Int?

  @Published var browse = false

  private var id = 0
  private let data: Binding<[String]>
  private var publisher: AnyCancellable?

  init(_ data: Binding<[String]>) {
    self.data = data
    super.init()
    publisher = self.data.publisher.sink { [weak self] _ in
      guard let self else { return }
      guard !self.ignoringChanges else { return }

      self.ignoringChanges {
        self.selection = nil
        self.id = 0
        self.list = self.data.wrappedValue.map { value in self.makeListItem(value) }
      }
    }
  }

  func append(_ value: String) {
    let item = makeListItem(value)
    list.append(item)
    selection = item.id
  }

  func remove() {
    list.removeAll { item in item.id == selection }
  }

  private func makeListItem(_ value: String) -> ListItem {
    id += 1
    return ListItem(id: id, value: value)
  }
}
